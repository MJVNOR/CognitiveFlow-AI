import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../genui/tutor_surface.dart';
import '../models/models.dart';
import '../session/lab_session.dart';

abstract final class Strings {
  static const appTitle = 'CognitiveFlow AI';
  static const loginHint = 'Login demo (s1-s4 estudiante, i1 instructor)';
  static const loginUserId = 'user_id';
  static const loginEnter = 'Entrar';
  static const tabAcademy = 'Academia';
  static const tabLabs = 'Lab';
  static const tabProgress = 'Progreso';
  static const tabInstructor = 'Instructor';
  static const noApi = 'Sin conexión API';
  static const sendAttempt = 'Enviar intento';
  static const deliverPosttest = 'Entregar postest';
  static const retry = 'Reintentar';
  static const goPosttest = 'Ir al postest (tabla nueva, sin ayuda)';
  static const goPosttestNoAI = 'Ir al postest (sin ayuda de IA)';
  static const chartDataTable = 'Ver datos como tabla';
  static const scrollHint = 'Desliza → para ver todas las columnas';
  static const legendTrain = 'Entrenamiento (línea continua)';
  static const legendVal = 'Validación (línea discontinua)';
  static const legendRef = 'Referencia (barra izquierda)';
  static const legendCur = 'Actual (barra derecha)';
  static const simulated = 'Curvas sintéticas (simulación)';
}

// Anuncia errores/estados a lectores de pantalla (WCAG 4.1.3).
class StatusText extends StatelessWidget {
  final String status;
  const StatusText(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(status),
      ),
    );
  }
}

/// Aviso de bloqueo de postest, idéntico en los 3 labs.
class PosttestBanner extends StatelessWidget {
  const PosttestBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Modo postest — sin pistas, sin tutor, sin evaluación hasta entregar.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pasos del lab (misma cabecera en los 3 labs: así se blendean).
class LabSteps extends StatelessWidget {
  final int current;
  const LabSteps({super.key, required this.current});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < labStepLabels.length; i++) ...[
          if (i > 0) SizedBox(width: 16, child: Divider(color: cs.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              selected: i == current,
              label: '${labStepLabels[i]}${i == current ? ', paso actual' : i < current ? ', completado' : ''}',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    i < current
                        ? Icons.check_circle
                        : i == current
                            ? Icons.radio_button_checked
                            : Icons.circle_outlined,
                    size: 16,
                    color: i <= current ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    labStepLabels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == current ? FontWeight.bold : null,
                      color: i <= current ? null : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Miga Ruta > Módulo > Unidad derivada del objetivo (sin hardcodear textos).
String? labCrumb(List<Map<String, dynamic>>? objectives) {
  if (objectives == null || objectives.isEmpty) return null;
  final parts = '${objectives.first['id']}'.split('-');
  if (parts.length >= 2) return 'Módulo ${parts[0]} · Unidad ${parts[1]}';
  return 'Unidad ${objectives.first['id']}';
}

/// Cabecera común: objetivo del lab + pasos. Va arriba del contenido propio.
class LabHeader extends StatelessWidget {
  final String objective;
  final int step;
  final String? crumb;
  const LabHeader({super.key, required this.objective, required this.step, this.crumb});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (crumb != null)
          Text(crumb!, style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
        if (crumb != null) const SizedBox(height: 2),
        Text(objective, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        LabSteps(current: step),
        const Divider(),
      ],
    );
  }
}

/// Segunda fila de la doble barra (diseño como en imagen): título de la
/// vista bajo la AppBar global de marca. No es una AppBar Material más,
/// sino el segundo nivel intencional: misma superficie, solo borde inferior,
/// tipografía un paso menor que la marca y retroceso opcional.
class DoubleTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? backRoute;
  final bool posttest;
  const DoubleTitleBar(
      {super.key, required this.title, this.backRoute, this.posttest = false});

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      padding: EdgeInsets.only(left: backRoute != null ? 4 : 16, right: 16),
      child: Row(
        children: [
          if (backRoute != null)
            IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go(backRoute!),
            ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (posttest)
            Chip(
              avatar: const Icon(Icons.lock_outline, size: 14),
              label: const Text('Postest', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
        ],
      ),
    );
  }
}

/// Sección reutilizable del ciclo predecir→experimentar→justificar.
/// Un título con icono + cuerpo; el color semántico llega por [accent].
class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? accent;
  final Widget? trailing;
  final List<Widget> children;
  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.accent,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = accent ?? cs.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: ac),
                const SizedBox(width: 8),
                Expanded(
                  child: AutoSizeText(title,
                      maxLines: 1,
                      minFontSize: 12,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: ac)),
                ),
                if (trailing case final Widget t) t,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Slider de parámetro de laboratorio con etiqueta, valor y ayuda.
/// Teal por defecto (experimentación, DESIGN.md §3); postest usa neutral.
class ParamSlider extends StatelessWidget {
  final String label;
  final String value;
  final String? help;
  final double current;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  const ParamSlider({
    super.key,
    required this.label,
    required this.value,
    required this.current,
    required this.min,
    required this.max,
    required this.divisions,
    this.help,
    this.onChanged,
    this.onChangeEnd,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Chip(
              label: Text(value, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        Slider(
          value: current,
          min: min,
          max: max,
          divisions: divisions,
          label: value,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
        if (help != null)
          Text(help!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Botón al siguiente lab de la ruta (por order_index). Nada que enlazar → texto.
class NextLabButton extends StatefulWidget {
  final String labId;
  const NextLabButton(this.labId, {super.key});
  @override
  State<NextLabButton> createState() => _NextLabButtonState();
}

class _NextLabButtonState extends State<NextLabButton> {
  late final _future = fetchLabs();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Lab>>(
      future: _future,
      builder: (c, s) {
        if (!s.hasData) return const SizedBox.shrink();
        final labs = s.data!;
        final i = labs.indexWhere((l) => l.id == widget.labId);
        if (i < 0 || i + 1 >= labs.length) {
          return const Text('Último lab de la ruta ✓');
        }
        final n = labs[i + 1];
        return FilledButton.tonal(
          key: const ValueKey('next_lab'),
          onPressed: () => context.go(
            '/labs/${n.id}',
            extra: {'lab_type': n.labType, 'title': n.title},
          ),
          child: AutoSizeText('Siguiente lab: ${n.title}',
              maxLines: 1, minFontSize: 12),
        );
      },
    );
  }
}

/// Reflexión de cierre + done + enlace al siguiente lab (postest unificado).
class PosttestReflection extends StatefulWidget {
  final LabSession lab;
  final String labId;
  final VoidCallback onUpdate;
  const PosttestReflection(
      {super.key, required this.lab, required this.labId, required this.onUpdate});
  @override
  State<PosttestReflection> createState() => _PosttestReflectionState();
}

class _PosttestReflectionState extends State<PosttestReflection> {
  final reflection = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    reflection.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => busy = true);
    try {
      await widget.lab.reflect(reflection.text);
    } catch (e) {
      widget.lab.status = 'Error: $e';
    }
    setState(() => busy = false);
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lab.done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('reflection_text'),
            controller: reflection,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reflexión: ¿qué aprendiste?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('reflection_send'),
            onPressed: busy ? null : _send,
            child: const Text('Enviar reflexión y cerrar'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sesión cerrada. Gracias por tu reflexión.'),
        // P4.5: pico-fin honesto desde deltas reales; sin halago automático.
        if (widget.lab.reflectionSummary != null)
          Builder(builder: (context) {
            final s = widget.lab.reflectionSummary!;
            final mejora = s['mejora'];
            final desafio = s['desafio'];
            if (mejora == null && desafio == null) {
              return const Text(
                  'Todavía sin evidencias para comparar; sigue practicando.',
                  style: TextStyle(fontSize: 13));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mejora != null)
                  Text('Mejora observada: ${criterionLabel('$mejora')} ✓',
                      style: const TextStyle(fontSize: 13)),
                if (desafio != null)
                  Text('Siguiente desafío: ${criterionLabel('$desafio')}',
                      style: const TextStyle(fontSize: 13)),
              ],
            );
          }),
        const SizedBox(height: 8),
        NextLabButton(widget.labId),
      ],
    );
  }
}

//// Panel compartido: evaluación + socrática + siguiente intervención GenUI.
/// Siempre visible tras el primer envío, con estados (nunca vacío silencioso).
class ResultPanel extends StatelessWidget {
  final LabSession lab;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  const ResultPanel({
    super.key,
    required this.lab,
    required this.onNext,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // P1: estado vacío diseñado — reserva el espacio en desktop antes del envío.
    if (!lab.evaluating &&
        lab.evalError == null &&
        lab.evalResult == null &&
        lab.intervention == null &&
        lab.socraticQ.isEmpty &&
        lab.tutorHistory.isEmpty &&
        lab.nextError == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aquí verás tu evidencia y el siguiente paso.',
              style: TextStyle(fontSize: 12)),
          SizedBox(height: 4),
          Text('Envía tu intento para empezar.',
              style: TextStyle(fontSize: 12)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lab.evaluating)
          const Row(
            children: [
              SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Evaluando…'),
            ],
          ),
        if (lab.evalError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(lab.evalError!, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(onPressed: onRetry, child: const Text(Strings.retry)),
        ],
        if (lab.evalResult != null) ...[
          Builder(builder: (context) {
            final r = lab.evalResult!;
            final isJev = r['evaluator'] == 'jev';
            if (r['status'] == 'pending') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(
                      isJev ? 'Evaluación Jev pendiente' : 'Evaluación pendiente',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jev no devolvió diagnóstico'
                    '${r['reason'] != null ? ': ${r['reason']}' : ''}. '
                    'No es una nota; tu intento está guardado.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  TextButton(onPressed: onRetry, child: const Text(Strings.retry)),
                ],
              );
            }
            final crits = (r['criteria'] as List).cast<Map>();
            crits.sort((a, b) =>
                ((b['score'] as num)).compareTo((a['score'] as num)));
            final summary = crits.isEmpty
                ? null
                : 'Fortaleza: ${criterionLabel('${crits.first['id']}')}'
                    '${crits.length > 1 ? ' · A trabajar: ${criterionLabel('${crits.last['id']}')}' : ''}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(
                        isJev ? 'Evaluación Jev' : 'Evaluación simulada',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    for (final c in crits)
                      Chip(
                        avatar: Icon(
                          (c['score'] as num) >= 2
                              ? Icons.check_circle
                              : Icons.error_outline,
                          size: 16,
                        ),
                        label: Text(
                            '${criterionLabel('${c['id']}')} · ${c['score']}',
                            style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (summary != null)
                  Text(summary, style: const TextStyle(fontSize: 12)),
                const Text(
                  'Evidencia orientativa, revisable por tu instructor.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            );
          }),
        ],
        if (lab.socraticQ.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              border: Border.all(color: cs.tertiary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_outline,
                        size: 16, color: cs.onTertiaryContainer),
                    const SizedBox(width: 6),
                    Text('¿Qué evidencia respalda tu hipótesis?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onTertiaryContainer)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Tutor: ${lab.socraticQ}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
        // PR-06: feedback compuesto (solo con texto Gemini; en mock manda el resumen).
        if ((lab.feedback?['texto'] as String?)?.isNotEmpty == true)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.feedback_outlined, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('Tu avance',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: cs.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${lab.feedback!['texto']}',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (lab.tutorHistory.isNotEmpty)
          ExpansionTile(
            key: const ValueKey('tutor_history'),
            title: Text(
                'Preguntas del tutor (${lab.tutorHistory.length})'),
            children: [
              for (final h in lab.tutorHistory)
                ListTile(
                  dense: true,
                  leading: Icon(
                      h['provider'] == 'gemini'
                          ? Icons.smart_toy_outlined
                          : Icons.help_outline,
                      size: 16),
                  title: Text('${h['question']}',
                      style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        if (lab.socraticQ.isNotEmpty || lab.tutorHistory.isNotEmpty) ...[
          Builder(builder: (context) {
            // Título accionable desde la intervención real, nunca «Siguiente actividad» a secas.
            final spec = lab.intervention?['widget_parameters'];
            final ivTitle = spec is Map ? '${spec['title'] ?? ''}' : '';
            return FilledButton.tonal(
              key: const ValueKey('next_activity'),
              onPressed: lab.nextBusy ? null : onNext,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: SizedBox(
                  width: double.infinity,
                  child: Text(
                      ivTitle.isNotEmpty ? 'Continuar: $ivTitle' : 'Ver mi siguiente actividad',
                      textAlign: TextAlign.center)),
            );
          }),
          const Text('La evaluación es evidencia; la actividad sigue con el tutor.',
              style: TextStyle(fontSize: 12)),
        ] else if (lab.evalResult != null &&
            lab.evalResult!['status'] != 'pending' &&
            !lab.evaluating &&
            lab.evalError == null) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Esperando la pregunta del tutor…',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
          TextButton(onPressed: onRetry, child: const Text(Strings.retry)),
        ],
        if (lab.nextBusy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Trayendo actividad…'),
              ],
            ),
          ),
        if (lab.nextError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(lab.nextError!, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(onPressed: onNext, child: const Text(Strings.retry)),
        ],
        if (lab.intervention != null) ...[
          const SizedBox(height: 8),
          TutorSurface(
            intervention: lab.intervention!,
            onEvent: (wt, et, payload) async {
              final sid = lab.sessionId;
              if (sid == null) return;
              try {
                await postJson('/sessions/$sid/events', {
                  'client_event_id': newEventId(),
                  'widget_type': wt,
                  'event_type': et,
                  'payload': payload,
                });
              } catch (_) {}
            },
          ),
        ],
      ],
    );
  }
}

// P1: el postest es irreversible (bloquea eval/tutor, fija variante del
// servidor). Confirmación única compartida por los 3 labs.
Future<void> confirmEnterPosttest(BuildContext context, LabSession lab,
    void Function(void Function()) setState, Future<void> Function() reload,
    [void Function()? onVariant]) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('¿Entrar al postest?'),
      content: const Text(
          'Se bloquea la evaluación y el tutor, y cambia a una variante nueva. '
          'Tu intento actual queda guardado. No podrás volver.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Seguir practicando')),
        FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Ir al postest')),
      ],
    ),
  );
  if (ok == true) await enterPosttest(lab, setState, reload, onVariant);
}

String labStatusLabel(String? status) => switch (status) {
      'active' => 'En curso',
      'posttest' => 'Postest sin ayuda',
      'done' => 'Completado',
      _ => 'No iniciado',
    };

/// Ciclo compartido de un lab: sesión → intento → evaluar → intervenir → postest.
const labStepLabels = ['Aprende el concepto', 'Prueba tu hipótesis', 'Explica lo que observaste', 'Aplica sin ayuda'];

