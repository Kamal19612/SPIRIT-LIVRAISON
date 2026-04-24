import 'package:flutter/foundation.dart';

void main() {
  const base = 'wss://spdelivery.socialracine.com/realtime/v1';
  final endPoint = Uri.parse('$base/websocket')
      .replace(queryParameters: {'apikey': 'eyJ', 'vsn': '1.0.0'})
      .toString();
  debugPrint('string: $endPoint');

  final u = Uri.parse(endPoint);
  debugPrint(
    'parsed port=${u.port} hasPort=${u.hasPort} effectivePort=${u.hasPort ? u.port : "(default for scheme)"}',
  );
}
