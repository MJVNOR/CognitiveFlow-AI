import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/models.dart';
import '../../ui/academy/view_models/academy_viewmodel.dart';
import '../../ui/core/widgets/bench_plate.dart';
import '../../ui/core/widgets/dial_gauge.dart';
import '../../ui/core/widgets/strings.dart';
import '../../ui/labs/docker/docker_units.dart';
import '../../ui/labs/widgets/posttest.dart';
import '../../ui/core/themes/cognitive_theme.dart';

// P6.1: nada de ids crudos visibles (jerga de dominio, no de producto).
String labTypeLabel(String? t) => switch (t) {
      'data_detective' => 'Datos tabulares',
      'ml_experiment' => 'Overfitting y generalización',
      'model_monitoring' => 'Deriva y monitoreo',
      'docker' => 'Contenedores y despliegue',
      _ => t ?? '',
    };

class AcademyPage extends ConsumerWidget {
  const AcademyPage({super.key});

  void _goLab(BuildContext context, Lab l) => context.go(
        '/labs/${l.id}',
        extra: {'lab_type': l.labType, 'title': l.title},
      );

  void _retry(WidgetRef ref) =>
      ref.read(academyViewModelProvider.notifier).refresh();

  (IconData, Color, Color, Color) _statusStyle(
      String? st, ColorScheme cs) {
    // icon, iconColor, chipBg, chipFg — redundancia icono+texto (DESIGN.md §4).
    return switch (st) {
      'done' => (
          Icons.check_circle,
          CognitiveColors.success,
          CognitiveColors.successSoft,
          CognitiveColors.success,
        ),
      'active' => (
          Icons.play_arrow,
          cs.primary,
          cs.primaryContainer,
          cs.onPrimaryContainer,
        ),
      'posttest' => (
          Icons.lock_outline,
          cs.tertiary,
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
        ),
      _ => (Icons.circle_outlined, cs.outline, cs.surfaceContainerHighest,
          cs.onSurfaceVariant),
    };
  }

  /// Docker Academy: cada unidad implementada es su propia entrada del temario
  /// (con su secuencia y prerrequisito orientativo), no un modo dentro del lab.
  Widget _dockerSyllabus(BuildContext context, Lab l, String? st, Map unitStatus) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    String? statusOf(String code) =>
        unitStatus[dockerUnits.firstWhere((u) => u.code == code).id] as String?;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _benchRow(context, l, st),
      for (final u in dockerUnits)
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('academy_unit_${u.code}'),
            onTap: dockerLockedBy(u, unitStatus) != null
                ? null
                : () => context.go('/labs/${l.id}?unit=${u.id}',
                    extra: {'lab_type': l.labType, 'title': l.title}),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(38, 8, 12, 8),
              child: Row(children: [
                SizedBox(
                  width: 40,
                  child: Text(u.code,
                      style: tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.title, style: tt.bodyMedium),
                    if (u.requires != null)
                      Text(
                          statusOf(u.requires!) == 'done'
                              ? 'Requisito cumplido: ${u.requires}'
                              : 'Primero completa ${u.requires}',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ]),
                ),
                // Estado escrito, nunca solo color (DESIGN.md §4).
                Text(
                    dockerLockedBy(u, unitStatus) != null
                        ? 'Bloqueada'
                        : labStatusLabel(statusOf(u.code)),
                    key: ValueKey('academy_unit_status_${u.code}'),
                    style: tt.labelSmall?.copyWith(
                        color: statusOf(u.code) == null ? cs.onSurfaceVariant : cs.primary)),
                const SizedBox(width: 4),
                Icon(dockerLockedBy(u, unitStatus) != null ? Icons.lock_outline : Icons.chevron_right,
                    size: 18, color: cs.onSurfaceVariant),
              ]),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(38, 2, 12, 10),
        child: Text('D03, D05, D06 y D08–D12: en preparación.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ),
    ]);
  }

  /// Un puesto del taller: lámpara, nombre y estado escrito (nunca solo color).
  Widget _benchRow(BuildContext context, Lab l, String? st) {
    final cs = Theme.of(context).colorScheme;
    final (icon, iconColor, _, chipFg) = _statusStyle(st, cs);
    final statusText = labStatusLabel(st);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 420;
      return Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _goLab(context, l),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: st == null ? cs.onSurfaceVariant : iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (l.description.isNotEmpty)
                        Text(
                          l.description,
                          maxLines: wide ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant, height: 1.3),
                        ),
                      if (!wide)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(statusText,
                              style: TextStyle(fontSize: 11, color: chipFg)),
                        ),
                    ],
                  ),
                ),
                if (wide) ...[
                  const SizedBox(width: 8),
                  PlateTag(text: statusText, color: chipFg),
                ],
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(academyViewModelProvider);
    return switch (async) {
      AsyncLoading() => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Cargando academia…'),
            ],
          ),
        ),
      AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text('${Strings.noApi}: $error',
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => _retry(ref),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      AsyncData(:final value) => Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final modules = value.modules;
        final labs = value.labs;
        final statusMap = value.statusMap;
        final orphans = [for (final l in labs) if (l.moduleId == '') l];
        if (labs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text('Todavía sin laboratorios asignados',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      'Si tu instructor te asignó un lab y no lo ves, avísale con el nombre del módulo.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          );
        }
        final done = labs.where((l) => statusMap[l.id] == 'done').length;
        // Objetivo actual: lo en curso primero, si no lo siguiente sin iniciar.
        Lab? current;
        for (final l in labs) {
          if (statusMap[l.id] == 'active' || statusMap[l.id] == 'posttest') {
            current = l;
            break;
          }
        }
        current ??= [
          for (final l in labs)
            if ((statusMap[l.id] as String?) == null) l
        ].firstOrNull;
        final cur = current;
        int doneCount(Iterable<Lab> ls) =>
            ls.where((l) => statusMap[l.id] == 'done').length;

        Widget bay(Module? m, List<Lab> mls) {
          final d = doneCount(mls);
          final code = m == null
              ? 'SIN MÓDULO'
              : 'M${m.id.replaceAll(RegExp(r'^m'), '').padLeft(2, '0')}';
          return BenchPlate(
            code: code,
            title: m?.title ?? 'Otros puestos',
            note: '$d/${mls.length}',
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < mls.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: cs.outlineVariant),
                  if (mls[i].labType == 'docker')
                    _dockerSyllabus(
                        context, mls[i], statusMap[mls[i].id] as String?, value.dockerUnits)
                  else
                    _benchRow(context, mls[i], statusMap[mls[i].id] as String?),
                ],
              ],
            ),
          );
        }

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Cabecera de planta: el avance se mide, no se estima.
                Row(
                  children: [
                    DialGauge(
                      value: labs.isEmpty ? 0 : done / labs.length,
                      readout: '$done/${labs.length}',
                      size: 88,
                      semanticLabel:
                          'Avance del taller: $done de ${labs.length} laboratorios terminados.',
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PLANTA DEL TALLER',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            done == 0
                                ? 'Todos los puestos abiertos'
                                : done == labs.length
                                    ? 'Todos los puestos cerrados'
                                    : '$done puestos cerrados',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            'Cada puesto pide una predicción, una manipulación y una justificación.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (cur != null) ...[
                  BenchPlate(
                    code: 'BANCO ACTIVO',
                    title: labStatusLabel(statusMap[cur.id] as String?),
                    tint: cs.primaryContainer.withValues(alpha: 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tu objetivo actual',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            )),
                        const SizedBox(height: 4),
                        Text(cur.title,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (cur.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(cur.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 44)),
                              onPressed: () => _goLab(context, cur),
                              child: const Text('Continuar'),
                            ),
                            TextButton(
                              onPressed: () => context.go('/progress'),
                              child: const Text('Ver progreso'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Planta del taller: en escritorio los puestos van en dos
                // columnas; en móvil, una sola (sin horizontal scroll).
                Builder(builder: (context) {
                  final bays = <Widget>[];
                  for (final m in modules) {
                    final mls = [
                      for (final l in labs)
                        if (l.moduleId == m.id) l
                    ];
                    if (mls.isNotEmpty) bays.add(bay(m, mls));
                  }
                  if (orphans.isNotEmpty) bays.add(bay(null, orphans));
                  return LayoutBuilder(builder: (context, c) {
                    final two = c.maxWidth >= 760 && bays.length > 1;
                    final w = two ? (c.maxWidth - 12) / 2 : c.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final b in bays) SizedBox(width: w, child: b),
                      ],
                    );
                  });
                }),
              ],
            ),
          ),
        );
      }),
    };
  }
}

class LabsPage extends ConsumerWidget {
  const LabsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(labsListViewModelProvider);
    return switch (async) {
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text('${Strings.noApi}: $error',
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref
                      .read(labsListViewModelProvider.notifier)
                      .refresh(),
                  child: const Text(Strings.retry),
                ),
              ],
            ),
          ),
        ),
      AsyncData(:final value) => Builder(builder: (context) {
        final labs = value;
        if (labs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Todavía sin laboratorios asignados',
                  textAlign: TextAlign.center),
            ),
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                for (final l in labs)
                  Card(
                    child: ListTile(
                      title: AutoSizeText(l.title,
                          maxLines: 1, minFontSize: 12),
                      subtitle: Text(labTypeLabel(l.labType)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(
                        '/labs/${l.id}',
                        extra: {'lab_type': l.labType, 'title': l.title},
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    };
  }
}
