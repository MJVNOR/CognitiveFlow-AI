// Estado del ciclo de un lab: sesión → intento → evaluar → intervenir → postest.
// MVVM: estado puro (sin red). La red vive en SessionRepository y la
// orquesta LabSessionViewModel. Los tests y widgets la usan directo por campos.
class LabSession {
  String? sessionId;
  String? attemptId;
  Map<String, dynamic>? evalResult;
  String socraticQ = '';
  Map? intervention;
  String status = '';
  bool evaluating = false;
  bool nextBusy = false;
  String? evalError;
  String? nextError;
  bool posttestMode = false;
  bool posttestSent = false;
  bool done = false;
  // P3.3: historial de preguntas del tutor por sesión (GET tutor-history).
  List<Map<String, dynamic>> tutorHistory = [];
  // PR-06: feedback compuesto fortaleza→brecha (texto Gemini o null en mock).
  Map<String, dynamic>? feedback;
  // Sprint 4: nivel diagnosticado + ayuda usada (restauran con la sesión).
  String? level;
  Map<String, int>? assistance;
  // Lección del objetivo (la carga el VM, la muestra la View).
  List<Map<String, dynamic>> objectives = [];

  /// 0 explorar, 1 evaluar, 2 intervenir, 3 postest.
  int get step => (posttestMode || posttestSent || done)
      ? 3
      : intervention != null
          ? 2
          : evalResult != null
              ? 1
              : 0;

  // P4.1: el servidor fija la variante del postest; el cliente la aplica.
  Map<String, dynamic>? posttestVariant;
  Map<String, dynamic>? reflectionSummary;

  int variantSeed(int fallback) => (posttestVariant?['seed'] as num?)?.toInt() ?? fallback;

  /// Snapshot para MVVM: los ViewModels notifican reasignando copias.
  LabSession copy() => LabSession()
    ..sessionId = sessionId
    ..attemptId = attemptId
    ..evalResult = evalResult == null ? null : Map<String, dynamic>.from(evalResult!)
    ..socraticQ = socraticQ
    ..intervention =
        intervention == null ? null : Map<String, dynamic>.from(intervention!)
    ..status = status
    ..evaluating = evaluating
    ..nextBusy = nextBusy
    ..evalError = evalError
    ..nextError = nextError
    ..posttestMode = posttestMode
    ..posttestSent = posttestSent
    ..done = done
    ..tutorHistory = [for (final h in tutorHistory) Map<String, dynamic>.from(h)]
    ..feedback = feedback == null ? null : Map<String, dynamic>.from(feedback!)
    ..level = level
    ..assistance = assistance == null ? null : Map<String, int>.from(assistance!)
    ..objectives = [for (final o in objectives) Map<String, dynamic>.from(o)]
    ..posttestVariant = posttestVariant == null
        ? null
        : Map<String, dynamic>.from(posttestVariant!)
    ..reflectionSummary = reflectionSummary == null
        ? null
        : Map<String, dynamic>.from(reflectionSummary!);
}
