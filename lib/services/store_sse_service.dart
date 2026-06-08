import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/backend_server_model.dart';
import 'store_api_bridge.dart';

/// Flux SSE multi-backend (admin ou livraison).
enum StoreSseStream {
  admin('/api/notifications/stream/admin'),
  delivery('/api/notifications/stream/delivery');

  const StoreSseStream(this.path);
  final String path;
}

typedef StoreSseEventCallback = void Function(
  BackendServer backend,
  String event,
  Map<String, dynamic> data,
);

class StoreSseService {
  StoreSseService._();
  static final StoreSseService instance = StoreSseService._();

  static const _reconnectDelay = Duration(seconds: 5);

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<StoreSseStream, StoreSseEventCallback?> _handlers = {};
  final Map<StoreSseStream, bool> _stopped = {
    StoreSseStream.admin: true,
    StoreSseStream.delivery: true,
  };
  final Map<StoreSseStream, Timer?> _reconnectTimers = {};

  String _tokenKey(int backendId, StoreSseStream stream) => '${backendId}_${stream.name}';

  Future<void> start({
    required StoreSseStream stream,
    required StoreSseEventCallback onEvent,
  }) async {
    _handlers[stream] = onEvent;
    _stopped[stream] = false;
    await _connectAll(stream);
  }

  /// Relance les flux SSE actifs (veille / retour réseau).
  Future<void> reconnectIfActive(StoreSseStream stream) async {
    if (_stopped[stream] == true || _handlers[stream] == null) return;
    await _connectAll(stream);
  }

  Future<void> stop({StoreSseStream? stream}) async {
    if (stream == null) {
      for (final s in StoreSseStream.values) {
        await stop(stream: s);
      }
      return;
    }

    _stopped[stream] = true;
    _handlers[stream] = null;
    _reconnectTimers[stream]?.cancel();
    _reconnectTimers[stream] = null;

    final suffix = '_${stream.name}';
    for (final entry in _cancelTokens.entries.toList()) {
      if (entry.key.endsWith(suffix)) {
        entry.value.cancel('sse_stop');
        _cancelTokens.remove(entry.key);
      }
    }
  }

  void _scheduleReconnect(StoreSseStream stream) {
    if (_stopped[stream] == true || _handlers[stream] == null) return;
    _reconnectTimers[stream]?.cancel();
    _reconnectTimers[stream] = Timer(_reconnectDelay, () {
      if (_stopped[stream] != true) unawaited(_connectAll(stream));
    });
  }

  Future<void> _connectAll(StoreSseStream stream) async {
    if (_stopped[stream] == true || _handlers[stream] == null) return;

    final backends = await StoreApiBridge.instance.getAuthenticatedBackends();
    if (backends.isEmpty) {
      _scheduleReconnect(stream);
      return;
    }

    for (final backend in backends) {
      if (backend.id == null) continue;
      unawaited(_connectBackend(backend, stream));
    }
  }

  Future<void> _connectBackend(BackendServer backend, StoreSseStream stream) async {
    if (_stopped[stream] == true || _handlers[stream] == null || backend.id == null) {
      return;
    }

    final token = await StoreApiBridge.instance.getJwt(backend.id!);
    if (token == null || token.isEmpty) return;

    final key = _tokenKey(backend.id!, stream);
    _cancelTokens[key]?.cancel('sse_reconnect');
    final cancelToken = CancelToken();
    _cancelTokens[key] = cancelToken;

    try {
      final response = await StoreApiBridge.instance.dio.get<ResponseBody>(
        '${backend.origin}${stream.path}',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
        ),
        cancelToken: cancelToken,
      );

      final bodyStream = response.data?.stream;
      if (bodyStream == null) {
        _scheduleReconnect(stream);
        return;
      }

      final buffer = StringBuffer();
      await for (final chunk in bodyStream) {
        if (_stopped[stream] == true) break;
        buffer.write(utf8.decode(chunk));
        while (true) {
          final text = buffer.toString();
          final sep = text.indexOf('\n\n');
          if (sep < 0) break;
          final block = text.substring(0, sep);
          buffer
            ..clear()
            ..write(text.substring(sep + 2));
          _dispatchBlock(block, backend, stream);
        }
      }
      if (_stopped[stream] != true) _scheduleReconnect(stream);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      if (kDebugMode) {
        debugPrint('[SSE:${stream.name}:${backend.name}] ${e.message}');
      }
      _scheduleReconnect(stream);
    } catch (e) {
      if (kDebugMode) debugPrint('[SSE:${stream.name}:${backend.name}] $e');
      _scheduleReconnect(stream);
    }
  }

  void _dispatchBlock(String block, BackendServer backend, StoreSseStream stream) {
    final onEvent = _handlers[stream];
    if (onEvent == null) return;

    String? eventName;
    final dataLines = <String>[];
    for (final raw in block.split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith('event:')) {
        eventName = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    if (dataLines.isEmpty) return;

    final name = eventName ?? 'message';
    if (name == 'heartbeat' || name == 'connected') return;

    try {
      final decoded = jsonDecode(dataLines.join('\n'));
      if (decoded is! Map) return;
      onEvent(backend, name, Map<String, dynamic>.from(decoded));
    } catch (_) {}
  }
}
