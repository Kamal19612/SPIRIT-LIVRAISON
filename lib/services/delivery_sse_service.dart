import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'store_api_bridge.dart';

/// Flux SSE livreur (`GET /api/notifications/stream/delivery`), aligné PWA STORE-ALL.
class DeliverySseService {
  DeliverySseService._();
  static final DeliverySseService instance = DeliverySseService._();

  static const _reconnectDelay = Duration(seconds: 5);

  CancelToken? _cancelToken;
  void Function(String event, Map<String, dynamic> data)? _onEvent;
  bool _stopped = true;
  Timer? _reconnectTimer;

  Future<void> start({
    required void Function(String event, Map<String, dynamic> data) onEvent,
  }) async {
    _onEvent = onEvent;
    _stopped = false;
    await _connect();
  }

  Future<void> stop() async {
    _stopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cancelToken?.cancel('sse_stop');
    _cancelToken = null;
  }

  void _scheduleReconnect() {
    if (_stopped || _onEvent == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (!_stopped) unawaited(_connect());
    });
  }

  Future<void> _connect() async {
    if (_stopped || _onEvent == null) return;

    final origin = await StoreApiBridge.instance.apiOrigin;
    final token = await StoreApiBridge.instance.jwt;
    if (origin == null || token == null || token.isEmpty) {
      _scheduleReconnect();
      return;
    }

    _cancelToken?.cancel('sse_reconnect');
    _cancelToken = CancelToken();

    try {
      final response = await StoreApiBridge.instance.dio.get<ResponseBody>(
        '$origin/api/notifications/stream/delivery',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
        ),
        cancelToken: _cancelToken,
      );

      final stream = response.data?.stream;
      if (stream == null) {
        _scheduleReconnect();
        return;
      }

      final buffer = StringBuffer();
      await for (final chunk in stream) {
        if (_stopped) break;
        if (chunk is! List<int>) continue;
        buffer.write(utf8.decode(chunk));
        while (true) {
          final text = buffer.toString();
          final sep = text.indexOf('\n\n');
          if (sep < 0) break;
          final block = text.substring(0, sep);
          buffer
            ..clear()
            ..write(text.substring(sep + 2));
          _dispatchBlock(block, _onEvent!);
        }
      }
      if (!_stopped) _scheduleReconnect();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      if (kDebugMode) {
        debugPrint('[DeliverySSE] ${e.message}');
      }
      _scheduleReconnect();
    } catch (e) {
      if (kDebugMode) debugPrint('[DeliverySSE] $e');
      _scheduleReconnect();
    }
  }

  void _dispatchBlock(
    String block,
    void Function(String event, Map<String, dynamic> data) onEvent,
  ) {
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
    try {
      final decoded = jsonDecode(dataLines.join('\n'));
      if (decoded is! Map) return;
      onEvent(eventName ?? 'message', Map<String, dynamic>.from(decoded));
    } catch (_) {}
  }
}
