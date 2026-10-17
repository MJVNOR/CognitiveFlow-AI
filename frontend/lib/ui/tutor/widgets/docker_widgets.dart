import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '_shared.dart';
import 'events.dart';

/// D01: clasificar 3 escenarios contenedor vs VM; emite evidenceSelected.
final containerVsVmExplorer = CatalogItem(
  name: 'ContainerVsVmExplorer',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del reto'),
      'question': S.string(description: 'Consigna'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "ContainerVsVmExplorer", '
        '"title": "Contenedor o VM", "question": "Clasifica cada escenario"}]',
  ],
  widgetBuilder: (ctx) => _ContainerVsVm(ctx),
);

const _containerScenarios = [
  'App que debe correr igual en tu PC y en el servidor',
  'Necesitas otro kernel y drivers específicos',
  'Tu archivo desapareció al recrear el entorno',
];

class _ContainerVsVm extends StatefulWidget {
  final CatalogItemContext ctx;
  const _ContainerVsVm(this.ctx);
  @override
  State<_ContainerVsVm> createState() => _ContainerVsVmState();
}

class _ContainerVsVmState extends State<_ContainerVsVm> {
  final choices = <int?>[null, null, null]; // 0 contenedor, 1 VM
  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final ready = choices.every((c) => c != null);
    return titledCard(context, '${data['title'] ?? 'Contenedor o VM'}',
        '${data['question'] ?? ''}',
        icon: Icons.inventory_2_outlined,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          for (var i = 0; i < _containerScenarios.length; i++) ...[
            Text(_containerScenarios[i],
                style: Theme.of(context).textTheme.bodySmall),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: ValueKey('cve_c_$i'),
                  label: const Text('Contenedor'),
                  selected: choices[i] == 0,
                  onSelected: (_) => setState(() => choices[i] = 0),
                ),
                ChoiceChip(
                  key: ValueKey('cve_v_$i'),
                  label: const Text('VM'),
                  selected: choices[i] == 1,
                  onSelected: (_) => setState(() => choices[i] = 1),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.tonal(
            key: const ValueKey('cve_send'),
            onPressed: ready
                ? () => TutorEvents.send('ContainerVsVmExplorer',
                    'evidenceSelected', {
                    'choices': [for (final c in choices) c]
                  })
                : null,
            child: const Text('Enviar clasificación'),
          ),
        ]);
  }
}

/// D02: simular ciclo pull/run/stop/rm por pasos; emite al completar.
final imageContainerLifecycle = CatalogItem(
  name: 'ImageContainerLifecycle',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del ciclo'),
      'question': S.string(description: 'Consigna'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "ImageContainerLifecycle", '
        '"title": "Ciclo de vida", "question": "Avanza el ciclo y observa"}]',
  ],
  widgetBuilder: (ctx) => _ImageLifecycle(ctx),
);

const _lifecycleStages = ['pull / build', 'run', 'stop', 'rm'];
const _lifecycleNotes = [
  'La imagen aún no existe aquí.',
  'Imagen lista. El contenedor corre.',
  'Contenedor detenido (existe, no corre).',
  'Contenedor eliminado.',
  'Ciclo completo: la imagen sigue disponible.',
];

class _ImageLifecycle extends StatefulWidget {
  final CatalogItemContext ctx;
  const _ImageLifecycle(this.ctx);
  @override
  State<_ImageLifecycle> createState() => _ImageLifecycleState();
}

class _ImageLifecycleState extends State<_ImageLifecycle> {
  int step = 0;
  bool sent = false;
  void _advance() {
    if (step >= _lifecycleStages.length) return;
    setState(() => step++);
    if (step == _lifecycleStages.length && !sent) {
      sent = true;
      TutorEvents.send('ImageContainerLifecycle', 'evidenceSelected',
          {'completed': true, 'stages': _lifecycleStages});
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    return titledCard(context, '${data['title'] ?? 'Ciclo de vida'}',
        '${data['question'] ?? ''}',
        icon: Icons.sync,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          Wrap(
            spacing: 4,
            children: [
              for (var i = 0; i < _lifecycleStages.length; i++)
                Chip(
                  label: Text(_lifecycleStages[i],
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: i < step
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_lifecycleNotes[step],
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonal(
                key: const ValueKey('icl_next'),
                onPressed: step >= _lifecycleStages.length ? null : _advance,
                child: const Text('Avanzar'),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('icl_reset'),
                onPressed: () => setState(() {
                  step = 0;
                  sent = false;
                }),
                child: const Text('Reiniciar'),
              ),
            ],
          ),
        ]);
  }
}

/// D04: reordenar instrucciones Dockerfile; emite el orden propuesto.
final dockerfileWorkbench = CatalogItem(
  name: 'DockerfileWorkbench',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del reto'),
      'question': S.string(description: 'Consigna'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "DockerfileWorkbench", '
        '"title": "Dockerfile", "question": "Ordena y reconstruye"}]',
  ],
  widgetBuilder: (ctx) => _DockerfileWorkbench(ctx),
);

const _dockerLines = [
  'FROM python:3.12-slim',
  'COPY requirements.txt ./',
  'RUN pip install --no-cache-dir -r requirements.txt',
  'COPY ./app ./app',
];

class _DockerfileWorkbench extends StatefulWidget {
  final CatalogItemContext ctx;
  const _DockerfileWorkbench(this.ctx);
  @override
  State<_DockerfileWorkbench> createState() => _DockerfileWorkbenchState();
}

class _DockerfileWorkbenchState extends State<_DockerfileWorkbench> {
  // ponytail: orden inicial deliberadamente malo (app antes que deps).
  var order = [0, 3, 1, 2];
  void _move(int pos, int dir) {
    final next = pos + dir;
    if (next < 0 || next >= order.length) return;
    setState(() {
      final t = order[pos];
      order[pos] = order[next];
      order[next] = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    return titledCard(context, '${data['title'] ?? 'Dockerfile'}',
        '${data['question'] ?? ''}',
        icon: Icons.description_outlined,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          Text(
              'COPY requirements + RUN pip antes que COPY del código conserva la caché.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          for (var pos = 0; pos < order.length; pos++)
            Row(
              children: [
                Expanded(
                  child: Text('${pos + 1}. ${_dockerLines[order[pos]]}',
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace')),
                ),
                IconButton(
                  key: ValueKey('dw_up_$pos'),
                  tooltip: 'Subir',
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed:
                      pos == 0 ? null : () => _move(pos, -1),
                ),
                IconButton(
                  key: ValueKey('dw_down_$pos'),
                  tooltip: 'Bajar',
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: pos == order.length - 1
                      ? null
                      : () => _move(pos, 1),
                ),
              ],
            ),
          const SizedBox(height: 4),
          FilledButton.tonal(
            key: const ValueKey('dw_send'),
            onPressed: () => TutorEvents.send('DockerfileWorkbench',
                'evidenceSelected', {
              'order': [for (final i in order) _dockerLines[i]]
            }),
            child: const Text('Reconstruir'),
          ),
        ]);
  }
}

/// D07: predecir persistencia, escribir, recrear; emite predicción y observación.
final persistenceExperiment = CatalogItem(
  name: 'PersistenceExperiment',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del experimento'),
      'question': S.string(description: 'Consigna'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "PersistenceExperiment", '
        '"title": "Persistencia", "question": "Predice y recrea"}]',
  ],
  widgetBuilder: (ctx) => _PersistenceExperiment(ctx),
);

const _mountLabels = ['sin montaje', 'named volume', 'bind mount'];

class _PersistenceExperiment extends StatefulWidget {
  final CatalogItemContext ctx;
  const _PersistenceExperiment(this.ctx);
  @override
  State<_PersistenceExperiment> createState() => _PersistenceExperimentState();
}

class _PersistenceExperimentState extends State<_PersistenceExperiment> {
  int? mount;
  bool? predicted;
  bool written = false;
  bool? observed;
  void _recreate() {
    final survives = (mount ?? 0) != 0;
    setState(() => observed = survives);
    TutorEvents.send('PersistenceExperiment', 'evidenceSelected', {
      'mount': _mountLabels[mount ?? 0],
      'predicted': predicted,
      'observed': survives,
      'match': predicted == survives,
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    return titledCard(context, '${data['title'] ?? 'Persistencia'}',
        '${data['question'] ?? ''}',
        icon: Icons.save_outlined,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          const Text('1 · Elige montaje', style: TextStyle(fontSize: 12)),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < _mountLabels.length; i++)
                ChoiceChip(
                  key: ValueKey('pe_mount_$i'),
                  label: Text(_mountLabels[i]),
                  selected: mount == i,
                  onSelected: (_) => setState(() {
                    mount = i;
                    written = false;
                    observed = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('2 · Predice: ¿sobrevive al recrear?',
              style: TextStyle(fontSize: 12)),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('pe_pred_survive'),
                label: const Text('Sobrevive'),
                selected: predicted == true,
                onSelected: (_) {
                  setState(() => predicted = true);
                  TutorEvents.send('PersistenceExperiment',
                      'predictionSubmitted', {
                    'predicted': true,
                    'mount': mount == null ? null : _mountLabels[mount!],
                  });
                },
              ),
              ChoiceChip(
                key: const ValueKey('pe_pred_lost'),
                label: const Text('Se pierde'),
                selected: predicted == false,
                onSelected: (_) {
                  setState(() => predicted = false);
                  TutorEvents.send('PersistenceExperiment',
                      'predictionSubmitted', {
                    'predicted': false,
                    'mount': mount == null ? null : _mountLabels[mount!],
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              FilledButton.tonal(
                key: const ValueKey('pe_write'),
                onPressed: mount == null || written ? null : () => setState(() => written = true),
                child: const Text('Escribir archivo'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                key: const ValueKey('pe_recreate'),
                onPressed: !written || observed != null ? null : _recreate,
                child: const Text('Recrear'),
              ),
            ],
          ),
          if (observed != null)
            Text(
                'El archivo ${observed! ? 'sobrevivió' : 'se perdió'}'
                '${predicted == null ? '.' : (predicted == observed ? ' — acertaste.' : ' — fallaste, revisa tu modelo.')}',
                style: Theme.of(context).textTheme.bodySmall),
        ]);
  }
}
