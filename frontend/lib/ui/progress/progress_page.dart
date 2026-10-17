import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/models.dart';
import '../../l10n/app_localizations.dart';
import '../../data/repositories/lab_repository.dart' show fetchLabs;
import '../../data/repositories/progress_repository.dart';
import '../../utils/criteria.dart';
import '../../ui/core/widgets/chrome.dart';
import '../../ui/core/widgets/strings.dart';
import '../../ui/labs/widgets/posttest.dart';
import '../../ui/core/themes/cognitive_theme.dart';

final _int = NumberFormat.decimalPattern('es');

String _labTitle(List<Lab> labs, String id) =>
    labs.where((l) => l.id == id).map((l) => l.title).firstOrNull ?? id;

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});
  @override
  State<ProgressPage> createState() => _ProgressState();
}

class _ProgressState extends State<ProgressPage> {
  // ponytail: mismo Future.wait que Academia + GET /me/progress medido.
  late Future<List<dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() => Future.wait([
        fetchLabs(),
        fetchLabStatus(),
        fetchProgress(),
        fetchRecallDue(),
      ]);

  void _retry() => setState(() => _future = _load());

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
                Text('Cargando tu avance y evidencias…'),
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
                    child: Text('No se pudo cargar el progreso. Revisa tu conexión y reintenta.',
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text('${Strings.noApi}: ${s.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12)),
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
        final labs = s.data![0] as List<Lab>;
        final statusMap = s.data![1] as Map;
        final prog = {
          for (final p in (s.data![2] as List)) (p['lab_template_id'] as String): p as Map
        };
        final done =
            [for (final l in labs) if (statusMap[l.id] == 'done') l].length;
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
        final cs = Theme.of(context).colorScheme;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final routeLabel =
            AppLocalizations.of(context)?.routeProgress(done, labs.length) ??
                'Avance: ${_int.format(done)} de ${_int.format(labs.length)} labs terminados';
        Color statusColor(String? st) => switch (st) {
              'done' =>
                dark ? CognitiveColors.successDark : CognitiveColors.success,
              'active' => cs.primary,
              'posttest' => cs.tertiary,
              _ => cs.outline,
            };
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Semantics(
                    header: true,
                    child: Text(routeLabel,
                        style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: done / labs.length,
                  semanticsLabel: routeLabel,
                  semanticsValue: '${((done / labs.length) * 100).round()}%',
                ),
                const SizedBox(height: 16),
                if ((s.data![3] as List).isNotEmpty) ...[
                  SectionCard(
                    icon: Icons.event_repeat,
                    title: 'Repasos vencidos',
                    children: [
                      const Text(
                          'Preguntas nuevas, sin pistas: el dominio se mantiene demostrándolo otra vez.',
                          style: TextStyle(fontSize: 12)),
                      for (final r in (s.data![3] as List).cast<Map>())
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              _labTitle(labs, '${r['lab_template_id']}'),
                              style: const TextStyle(fontSize: 13)),
                          trailing: TextButton(
                            key: ValueKey('recall_done_${r['id']}'),
                            onPressed: () async {
                              try {
                                await markRecallDone('${r['id']}');
                              } catch (_) {}
                              _retry();
                            },
                            child: const Text('Marcar hecho'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                for (final l in labs)
                  Card(
                    child: ExpansionTile(
                      leading: Icon(
                        switch (statusMap[l.id]) {
                          'done' => Icons.check_circle,
                          'posttest' => Icons.lock_outline,
                          'active' => Icons.play_arrow,
                          _ => Icons.circle_outlined,
                        },
                        color: statusColor(statusMap[l.id] as String?),
                        semanticLabel:
                            labStatusLabel(statusMap[l.id] as String?),
                      ),
                      title: AutoSizeText(l.title,
                          maxLines: 1, minFontSize: 12),
                      subtitle: Text([
                        labStatusLabel(statusMap[l.id] as String?),
                        progressLine((prog[l.id]?['baseline']) as Map?,
                                (prog[l.id]?['posttest']) as Map?) ??
                            'Sin evidencias todavía',
                        if (prog[l.id]?['reviewed'] == true)
                          'Revisado por instructor',
                      ].join(' · ')),
                  children: [
                    if ((prog[l.id]?['baseline'] as Map?)?.isNotEmpty == true ||
                        (prog[l.id]?['posttest'] as Map?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final cid in {
                              ...((prog[l.id]?['baseline'] as Map?)?.keys ?? []),
                              ...((prog[l.id]?['posttest'] as Map?)?.keys ?? []),
                            })
                              Chip(
                                label: Text(
                                    '${criterionLabel('$cid')}: '
                                    '${(prog[l.id]?['baseline'] as Map?)?[cid] ?? '—'}'
                                    ' → ${(prog[l.id]?['posttest'] as Map?)?[cid] ?? '—'}',
                                    style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                    if ((prog[l.id]?['baseline'] as Map?)?.isNotEmpty == true ||
                        (prog[l.id]?['posttest'] as Map?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          (prog[l.id]?['mastery_status'] == 'demonstrated')
                              ? 'Dominio demostrado con postest ✓'
                              : 'Sin dominio demostrado todavía (la práctica no cuenta)',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                      ),
                    ListTile(
                      dense: true,
                      trailing: const Icon(Icons.chevron_right),
                      title: Text(
                          statusMap[l.id] == null
                              ? 'Abrir laboratorio'
                              : 'Continuar laboratorio',
                          style: const TextStyle(fontSize: 13)),
                      onTap: () => context.go(
                        '/labs/${l.id}',
                        extra: {'lab_type': l.labType, 'title': l.title},
                      ),
                    ),
                  ],
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

