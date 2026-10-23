import 'package:flutter/widgets.dart';

typedef TutorEventSink = void Function(
    String widgetType, String eventType, Map<String, Object?> payload);

/// Cada superficie entrega eventos a su propia actividad, incluso si coexisten.
class TutorEventScope extends InheritedWidget {
  final TutorEventSink emit;
  const TutorEventScope({super.key, required this.emit, required super.child});

  @override
  bool updateShouldNotify(TutorEventScope oldWidget) => emit != oldWidget.emit;
}

abstract final class TutorEvents {
  // Compatibilidad con pruebas de builders aislados; Surface siempre usa scope.
  static TutorEventSink? emit;
  static void send(BuildContext context, String w, String e,
      [Map<String, Object?> p = const {}]) {
    final scope = context.getInheritedWidgetOfExactType<TutorEventScope>();
    (scope?.emit ?? emit)?.call(w, e, p);
  }
}
