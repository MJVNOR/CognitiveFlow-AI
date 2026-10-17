import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../session/lab_session.dart';
import '../widgets/cards.dart';
import '../widgets/theme.dart';

class AcademyPage extends StatefulWidget {
  const AcademyPage({super.key});
  @override
  State<AcademyPage> createState() => _AcademyState();
}

// P6.1: nada de ids crudos visibles (jerga de dominio, no de producto).
String labTypeLabel(String? t) => switch (t) {
      'data_detective' => 'Datos tabulares',
      'ml_experiment' => 'Overfitting y generalización',
      'model_monitoring' => 'Deriva y monitoreo',
      'docker' => 'Contenedores y despliegue',
      _ => t ?? '',
    };

class _AcademyState extends State<AcademyPage> {
  // ponytail: un solo Future.wait; tres GET en paralelo, un solo spinner.
  late Future<List<dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future =
        Future.wait([fetchModules(), fetchLabs(), fetchMap('/me/lab-status')]);
  }

  void _retry() => setState(() {
        _future = Future.wait(
            [fetchModules(), fetchLabs(), fetchMap('/me/lab-status')]);
      });

  void _goLab(BuildContext context, Lab l) => context.go(
        '/labs/${l.id}',
        extra: {'lab_type': l.labType, 'title': l.title},
      );

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

  Widget _labCard(BuildContext context, Lab l, Map statusMap) {
    final st = statusMap[l.id] as String?;
    final cs = Theme.of(context).colorScheme;
    final (icon, iconColor, chipBg, chipFg) = _statusStyle(st, cs);
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: st == null ? iconColor : chipFg),
        ),
        title: Text(l.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall),
        subtitle: l.description.isEmpty
            ? null
            : Text(l.description,
                maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              backgroundColor: chipBg,
              label: Text(labStatusLabel(st),
                  style: TextStyle(fontSize: 11, color: chipFg)),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
        onTap: () => _goLab(context, l),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Cargando academia…'),
              ],
            ),
          );
        }
        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text('${Strings.noApi}: ${s.error}',
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _retry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final modules = s.data![0] as List<Module>;
        final labs = s.data![1] as List<Lab>;
        final statusMap = s.data![2] as Map;
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
        // Objetivo actual: lo en curso primero, si no lo siguiente sin iniciar.
        Lab? current;
        for (final l in labs) {
          if (statusMap[l.id] == 'active' || statusMap[l.id] == 'posttest') {
            current = l;
            break;
          }
        }
        current ??= [for (final l in labs) if ((statusMap[l.id] as String?) == null) l]
            .firstOrNull;
        final cur = current;
        int doneCount(Iterable<Lab> ls) =>
            ls.where((l) => statusMap[l.id] == 'done').length;
        Widget moduleHeader(Module m, int total, int done) => Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                        header: true,
                        child: Text(m.title,
                            style: Theme.of(context).textTheme.titleMedium)),
                  ),
                  if (total > 0)
                    Text('$done/$total',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                ],
              ),
            );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (cur != null) ...[
                  SectionCard(
                    icon: Icons.track_changes,
                    title: 'Tu objetivo actual',
                    trailing: Chip(
                      label: Text(
                          labStatusLabel(statusMap[cur.id] as String?),
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                    children: [
                      Text(cur.title,
                          style: Theme.of(context).textTheme.titleSmall),
                      if (cur.description.isNotEmpty)
                        Text(cur.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton(
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
                  const SizedBox(height: 4),
                ],
                for (final m in modules) ...[
                  Builder(builder: (context) {
                    final mls = [
                      for (final l in labs)
                        if (l.moduleId == m.id) l
                    ];
                    if (mls.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        moduleHeader(m, mls.length, doneCount(mls)),
                        for (final l in mls) _labCard(context, l, statusMap),
                      ],
                    );
                  }),
                ],
                if (orphans.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Semantics(
                        header: true,
                        child: Text('Otros',
                            style:
                                Theme.of(context).textTheme.titleMedium)),
                  ),
                  for (final l in orphans) _labCard(context, l, statusMap),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class LabsPage extends StatefulWidget {
  const LabsPage({super.key});
  @override
  State<LabsPage> createState() => _LabsState();
}

class _LabsState extends State<LabsPage> {
  late Future<List<Lab>> _future;
  @override
  void initState() {
    super.initState();
    _future = fetchLabs();
  }

  void _retry() => setState(() => _future = fetchLabs());
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Lab>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text('${Strings.noApi}: ${s.error}',
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _retry,
                    child: const Text(Strings.retry),
                  ),
                ],
              ),
            ),
          );
        }
        final labs = s.data!;
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
      },
    );
  }
}

