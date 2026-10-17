// Sink de eventos widget → backend (antes en genui/catalog.dart).
abstract final class TutorEvents {
  static void Function(String widgetType, String eventType, Map<String, Object?> payload)? emit;
  static void send(String w, String e, [Map<String, Object?> p = const {}]) =>
      emit?.call(w, e, p);
}
