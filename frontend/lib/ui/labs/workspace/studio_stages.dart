// Piezas compartidas por los labs del Learning Studio: estado de misiones
// derivado del servidor, tarjeta, reto GenUI central y cierre del postest.
// Convención de misiones: [..práctica.., envío, nuevo escenario, dominio];
// la penúltima existe solo si el servidor emitió intervención y la última
// solo si declara `can_enter_posttest`.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../tutor/tutor_surface.dart';
import '../view_models/lab_session_viewmodel.dart';
import '../widgets/reflection.dart';
import 'mission_navigation.dart';

bool inPosttestPhase(LabSession lab) => lab.posttestMode || lab.posttestSent || lab.done;

/// Confirma y reinicia el lab desde cero; vuelve a la academia (la próxima
/// apertura crea una sesión nueva). Irreversible para el estudiante, pero no
/// borra el historial que consulta el instructor.
Future<void> confirmResetLab(BuildContext context, LabSessionViewModel vm) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('¿Reiniciar el laboratorio?'),
      content: const Text(
          'Empezarás desde cero: se borran tus respuestas, marcas y borradores de este '
          'laboratorio y volverás a la primera misión. Tu instructor conserva el '
          'historial de lo que hiciste.'),
      actions: [
        TextButton(
            key: const ValueKey('reset_cancel'),
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
            key: const ValueKey('reset_confirm'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Reiniciar')),
      ],
    ),
  );
  if (ok != true || !await vm.resetLab() || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(const SnackBar(content: Text('Laboratorio reiniciado: empieza desde cero.')));
  context.go('/academy');
}

/// Estado de cada misión. [localMax] = misión más lejana alcanzada antes de
/// enviar (borrador local); [scenarioDone] = el reto GenUI ya recibió respuesta.
List<MissionView> studioMissionViews(
  List<Mission> missions,
  LabSession lab, {
  required int localMax,
  required bool scenarioDone,
  required int selected,
}) {
  final mastery = missions.length - 1, scenario = mastery - 1, submit = scenario - 1;
  final post = inPosttestPhase(lab);
  final submitted = lab.attemptId != null;
  final frontier = submitted ? submit : localMax.clamp(0, submit);
  bool unlocked(int i) => switch (i) {
        _ when post => i == mastery,
        _ when i == scenario => lab.intervention != null,
        _ when i == mastery => lab.canEnterPosttest,
        _ => i <= frontier,
      };
  bool done(int i) => switch (i) {
        _ when post && i < mastery => true,
        _ when i == submit => submitted,
        _ when i == scenario => scenarioDone,
        _ when i == mastery => lab.posttestSent || lab.done,
        _ => submitted || i < frontier,
      };
  return [
    for (var i = 0; i < missions.length; i++)
      MissionView(
        missions[i],
        done(i)
            ? MissionStatus.done
            : i == selected
                ? MissionStatus.current
                : unlocked(i)
                    ? MissionStatus.available
                    : MissionStatus.locked,
        navigable: unlocked(i),
      ),
  ];
}

/// Misión con la que abrir el lab: la frontera real, nunca el postest sin pedirlo.
int studioDefaultMission(List<Mission> missions, LabSession lab, int localMax) {
  final mastery = missions.length - 1, scenario = mastery - 1, submit = scenario - 1;
  if (inPosttestPhase(lab)) return mastery;
  if (lab.intervention != null) return scenario;
  if (lab.attemptId != null) return submit;
  return localMax.clamp(0, submit);
}

class StudioCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? accent;
  const StudioCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent ?? cs.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: accent ?? cs.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Título enfocable + objetivo de la misión (el foco llega aquí al cambiar).
class MissionIntro extends StatelessWidget {
  final Mission mission;
  final FocusNode focusNode;
  const MissionIntro({super.key, required this.mission, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          focusNode: focusNode,
          child: Semantics(
            header: true,
            child: Text(mission.title,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 4),
        Text(mission.goal,
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.45)),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Espera real de la evaluación (sin duración fingida).
class EvaluatingCard extends StatelessWidget {
  final String detail;
  const EvaluatingCard({super.key, required this.detail});

  @override
  Widget build(BuildContext context) => StudioCard(
        title: 'Evaluando tu razonamiento',
        icon: Icons.hourglass_top,
        child: Row(children: [
          const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(child: Text(detail)),
        ]),
      );
}

/// Reto GenUI elegido por el servidor, como escenario central.
class ScenarioStage extends StatelessWidget {
  final LabSession lab;
  final bool scenarioDone;
  final void Function(String widgetType, String eventType, Map<String, Object?> payload)
      onEvent;
  const ScenarioStage({
    super.key,
    required this.lab,
    required this.scenarioDone,
    required this.onEvent,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iv = lab.intervention;
    if (iv == null) {
      return const StudioCard(
          title: 'Sin reto todavía',
          icon: Icons.hourglass_empty,
          child: Text('El tutor elige el reto después de evaluar tu intento.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.secondary, width: 1.5),
          ),
          child: TutorSurface(
            key: ValueKey(iv['activity_id'] ?? 'surface-${iv['widget_type']}-${iv['strategy']}'),
            intervention: iv,
            onEvent: onEvent,
          ),
        ).enterNote(context, ValueKey(iv['activity_id'] ?? 'iv-${iv['widget_type']}-${iv['strategy']}')),
        if (scenarioDone)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              Icon(Icons.check_circle, color: cs.primary)
                  .enterCheck(context, const ValueKey('scenario-done')),
              const SizedBox(width: 8),
              const Expanded(child: Text('Respuesta registrada en tu sesión.')),
            ]),
          ),
        if (lab.scenarioCheck != null) CheckView(check: lab.scenarioCheck!),
      ],
    );
  }
}

/// Corrección del servidor: qué está bien y qué revisar, sin revelar la
/// respuesta ni puntajes (se puede volver a enviar). `item` nombra cada
/// elemento («fila», «escenario»…) y `consejo` orienta la revisión.
class CheckView extends StatelessWidget {
  final Map<String, dynamic> check;
  /// Texto cuando no queda nada por revisar.
  final String doneText;
  final String? successTitle;
  const CheckView({
    super.key,
    required this.check,
    this.doneText = 'Ya puedes demostrar tu dominio en la prueba final.',
    this.successTitle,
  });

  @override
  Widget build(BuildContext context) {
    final item = check['item'] is String ? '${check['item']} ' : '';
    String list(Object? v) =>
        [for (final r in v as List? ?? const []) '$item$r'].join(', ');
    final ok = list(check['correctas']);
    final again = list(check['revisar']);
    final tip = '${check['consejo'] ?? ''}';
    final pending = check['pendientes'] is int ? check['pendientes'] as int : 0;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        key: const ValueKey('scenario_check'),
        liveRegion: true,
        child: StudioCard(
          title: again.isNotEmpty
              ? 'Revisa tu respuesta'
              : (pending > 0 ? 'Vas bien' : successTitle ?? 'Bien resuelto'),
          icon: again.isEmpty ? Icons.verified_outlined : Icons.manage_search,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (ok.isNotEmpty) Text('Bien: $ok.'),
            if (again.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Vuelve a mirar: $again.${tip.isEmpty ? '' : ' $tip'}'),
            ],
            if (again.isEmpty) Text(pending > 0 ? 'Te faltan $pending por decidir.' : doneText),
          ]),
        ).enterNote(context, ValueKey('check-$again-$ok')),
      ),
    );
  }
}

/// Corrección inmediata de la práctica (aún sin reto): qué está bien y qué revisar.
Widget practiceCheck(LabSession l, String doneText, {String? successTitle}) =>
    l.scenarioCheck != null && l.intervention == null
        ? CheckView(check: l.scenarioCheck!, doneText: doneText, successTitle: successTitle)
        : const SizedBox.shrink();

/// Reglas antes de empezar la prueba sin ayuda.
class PosttestRulesCard extends StatelessWidget {
  final String novelty;
  const PosttestRulesCard({super.key, required this.novelty});

  @override
  Widget build(BuildContext context) => StudioCard(
        title: 'Reglas de la prueba',
        icon: Icons.rule,
        child: Text(
          '• $novelty\n'
          '• Sin tutor, sin pistas y sin evaluación hasta entregar.\n'
          '• Al empezar, la práctica queda cerrada: no podrás volver.\n'
          '• Mide lo que ya dominas; tu intento de práctica sigue guardado.',
          style: const TextStyle(height: 1.6),
        ),
      );
}

/// Prueba entregada → reflexión breve (cierra la sesión).
class PosttestClosing extends StatelessWidget {
  final LabSession lab;
  final String labId;
  final VoidCallback onUpdate;
  const PosttestClosing(
      {super.key, required this.lab, required this.labId, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Icon(Icons.check_circle, color: cs.primary)
              .enterCheck(context, const ValueKey('posttest-sent')),
          const SizedBox(width: 8),
          const Expanded(child: Text('Prueba entregada. Cierra con una reflexión breve.')),
        ]),
        const SizedBox(height: 12),
        PosttestReflection(lab: lab, labId: labId, onUpdate: onUpdate),
      ],
    );
  }
}
