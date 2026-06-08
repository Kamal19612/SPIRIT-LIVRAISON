import 'store_sse_service.dart';

/// Raccourci livreur — délègue à [StoreSseService].
class DeliverySseService {
  DeliverySseService._();
  static final DeliverySseService instance = DeliverySseService._();

  Future<void> start({
    required void Function(String event, Map<String, dynamic> data) onEvent,
  }) =>
      StoreSseService.instance.start(
        stream: StoreSseStream.delivery,
        onEvent: (_, event, data) => onEvent(event, data),
      );

  Future<void> stop() => StoreSseService.instance.stop(stream: StoreSseStream.delivery);
}
