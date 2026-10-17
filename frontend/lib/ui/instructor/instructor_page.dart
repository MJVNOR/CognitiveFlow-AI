import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/instructor/view_models/instructor_viewmodel.dart';
import '../../utils/criteria.dart' show progressLine;
import '../../ui/core/widgets/chrome.dart';
import '../../ui/core/widgets/strings.dart';
import '../../ui/labs/widgets/posttest.dart';

class InstructorPage extends ConsumerWidget {
  const InstructorPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(instructorViewModelProvider);
    return switch (async) {
      AsyncLoading() => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Cargando estudiantes…'),
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
                  onPressed: () => ref
                      .read(instructorViewModelProvider.notifier)
                      .refresh(),
                  child: const Text('Reintentar'),
                ),
                ],
              ),
            ),
          ),
      AsyncData(:final value) => Builder(builder: (context) {
        final students = value.students;
        final labTitles = value.labTitles;
        final matrix = value.matrix;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              icon: Icons.groups,
              title: '${students.length} estudiantes',
              children: const [
                Text('Toca un estudiante para ver sus sesiones (solo lectura).'),
              ],
            ),
            const SizedBox(height: 12),
            for (final st in students)
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.person_outline),
                  title: AutoSizeText(st.displayName,
                      maxLines: 1, minFontSize: 12),
                  subtitle: Text(
                    _studentSummary(
                        (matrix[st.id]?['labs'] as Map?)?.cast<String, Map>()),
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    if (matrix[st.id] != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _MatrixCard(
                            labTitles: labTitles,
                            labs: (matrix[st.id]!['labs'] as Map).cast<String, Map>()),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _SessionsDialog(
                          studentId: st.id, labTitles: labTitles),
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    };
  }
}

// P4.4: matriz por alumno — inicial→postest por lab, sin promediar personas.
String _studentSummary(Map<String, Map>? labs) {
  if (labs == null || labs.isEmpty) return 'Sin actividad todavía';
  final withEvidence = [
    for (final e in labs.values)
      if (progressLine(e['baseline'] as Map?, e['posttest'] as Map?) != null) e
  ].length;
  return '$withEvidence de ${labs.length} labs con inicial y postest';
}

class _MatrixCard extends StatelessWidget {
  final Map<String, String> labTitles;
  final Map<String, Map> labs;
  const _MatrixCard({required this.labTitles, required this.labs});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = labs.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const Divider(height: 17, indent: 0, endIndent: 0),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(labTitles[entries[i].key] ?? entries[i].key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                        progressLine(entries[i].value['baseline'] as Map?,
                                entries[i].value['posttest'] as Map?) ??
                            'Sin evidencias todavía',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                )),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ponytail: future hoisted to dialog state so rebuilds don't refetch.
class _SessionsDialog extends ConsumerWidget {
  final String studentId;
  final Map<String, String> labTitles;
  const _SessionsDialog({required this.studentId, required this.labTitles});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studentSessionsViewModelProvider(studentId));
    return switch (async) {
      AsyncLoading() => Semantics(
          liveRegion: true,
          child: const LinearProgressIndicator(),
        ),
      AsyncError(:final error) => Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text('No se pudieron cargar las sesiones: $error',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
            TextButton(
                onPressed: () => ref
                    .read(studentSessionsViewModelProvider(studentId).notifier)
                    .refresh(),
                child: const Text('Reintentar')),
          ],
        ),
      AsyncData(:final value) => Builder(builder: (context) {
        final sessions = value;
        if (sessions.isEmpty) return const Text('Sin sesiones');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final se in sessions)
              Builder(builder: (context) {
                final cs = Theme.of(context).colorScheme;
                final (icon, fg, bg) = switch (se.status) {
                  'done' => (
                      Icons.check_circle,
                      cs.onSecondaryContainer,
                      cs.secondaryContainer
                    ),
                  'posttest' => (
                      Icons.lock_outline,
                      cs.onTertiaryContainer,
                      cs.tertiaryContainer
                    ),
                  'active' => (
                      Icons.play_arrow,
                      cs.onPrimaryContainer,
                      cs.primaryContainer
                    ),
                  _ => (
                      Icons.circle_outlined,
                      cs.onSurfaceVariant,
                      cs.surfaceContainerHighest
                    ),
                };
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 17, color: fg),
                  ),
                  title: Text(
                      labTitles[se.labTemplateId] ?? se.labTemplateId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(labStatusLabel(se.status),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: cs.onSurfaceVariant),
                  onTap: () {
                    context.go('/instructor/session/${se.id}');
                  },
                );
              }),
          ],
        );
      }),
    };
  }
}
