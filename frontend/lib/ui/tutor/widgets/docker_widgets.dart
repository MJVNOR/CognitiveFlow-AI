import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '_shared.dart';
import 'events.dart';

// Docker Academy: el escenario de cada widget (sin respuestas) lo genera el
// servidor por unidad y semilla (`labs_docker.activity`); los valores const
// de este archivo solo cubren datos ausentes (catálogo de ejemplo, tests).

List<String> _strings(Object? v, List<String> fallback) =>
    v is List && v.isNotEmpty ? [for (final x in v) '$x'] : fallback;

/// D01: clasificar escenarios contenedor vs VM; emite evidenceSelected.
final containerVsVmExplorer = CatalogItem(
  name: 'ContainerVsVmExplorer',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del reto'),
      'question': S.string(description: 'Consigna'),
      'scenarios': S.list(description: 'Escenarios a clasificar', items: S.string()),
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
  final choices = <int, int>{}; // índice → 0 contenedor, 1 VM
  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final scenarios = _strings(data['scenarios'], _containerScenarios);
    final ready = choices.length == scenarios.length;
    return titledCard(context, '${data['title'] ?? 'Contenedor o VM'}',
        '${data['question'] ?? ''}',
        icon: Icons.inventory_2_outlined,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          for (var i = 0; i < scenarios.length; i++) ...[
            Text('${i + 1}. ${scenarios[i]}', style: Theme.of(context).textTheme.bodySmall),
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
                ? () => TutorEvents.send('ContainerVsVmExplorer', 'evidenceSelected', {
                      'choices': [for (var i = 0; i < scenarios.length; i++) choices[i]]
                    })
                : null,
            child: const Text('Enviar clasificación'),
          ),
        ]);
  }
}

/// D02: predecir qué existe tras un paso y simular el ciclo; emite al completar.
final imageContainerLifecycle = CatalogItem(
  name: 'ImageContainerLifecycle',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del ciclo'),
      'question': S.string(description: 'Consigna'),
      'ask_stage': S.string(description: 'Paso tras el cual se pide la predicción'),
      'options': S.list(description: 'Opciones de predicción', items: S.string()),
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
  String? prediction;

  String? get _askStage {
    final s = (widget.ctx.data as Map)['ask_stage'];
    return _lifecycleStages.contains(s) ? s as String : null;
  }

  void _advance() {
    if (step >= _lifecycleStages.length) return;
    setState(() => step++);
    if (step == _lifecycleStages.length && !sent) {
      sent = true;
      TutorEvents.send('ImageContainerLifecycle', 'evidenceSelected', {
        'completed': true,
        'stages': _lifecycleStages,
        if (_askStage != null) 'ask_stage': _askStage,
        if (prediction != null) 'prediction': prediction,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final ask = _askStage;
    final options = _strings(data['options'], const ['imagen', 'contenedor', 'ambos', 'ninguno']);
    // Primero se predice; la simulación se habilita después (predecir antes de ver).
    final mustPredict = ask != null && prediction == null;
    return titledCard(context, '${data['title'] ?? 'Ciclo de vida'}',
        '${data['question'] ?? ''}',
        icon: Icons.sync,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          if (ask != null) ...[
            Text('Predice: tras «$ask», ¿qué existe?',
                style: Theme.of(context).textTheme.labelLarge),
            Wrap(spacing: 8, children: [
              for (final o in options)
                ChoiceChip(
                  key: ValueKey('icl_pred_$o'),
                  label: Text(o),
                  selected: prediction == o,
                  onSelected: sent ? null : (_) => setState(() => prediction = o),
                ),
            ]),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 4,
            children: [
              for (var i = 0; i < _lifecycleStages.length; i++)
                Chip(
                  label: Text(_lifecycleStages[i], style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor:
                      i < step ? Theme.of(context).colorScheme.primaryContainer : null,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_lifecycleNotes[step], style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonal(
                key: const ValueKey('icl_next'),
                onPressed: step >= _lifecycleStages.length || mustPredict ? null : _advance,
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
          if (mustPredict)
            Text('Elige tu predicción para empezar la simulación.',
                style: Theme.of(context).textTheme.bodySmall),
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
      'app': S.string(description: 'Qué se contenedoriza'),
      'lines': S.list(description: 'Instrucciones en orden inicial', items: S.string()),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "DockerfileWorkbench", '
        '"title": "Dockerfile", "question": "Ordena y reconstruye"}]',
  ],
  widgetBuilder: (ctx) => _DockerfileWorkbench(ctx),
);

// ponytail: orden inicial deliberadamente malo (app antes que deps).
const _dockerLines = [
  'FROM python:3.12-slim',
  'COPY ./app ./app',
  'COPY requirements.txt ./',
  'RUN pip install --no-cache-dir -r requirements.txt',
];

class _DockerfileWorkbench extends StatefulWidget {
  final CatalogItemContext ctx;
  const _DockerfileWorkbench(this.ctx);
  @override
  State<_DockerfileWorkbench> createState() => _DockerfileWorkbenchState();
}

class _DockerfileWorkbenchState extends State<_DockerfileWorkbench> {
  late final List<String> order =
      List.of(_strings((widget.ctx.data as Map)['lines'], _dockerLines));

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
              '${data['app'] == null ? '' : 'Dockerfile de un ${data['app']}. '}'
              'Ordénalo para que reconstruir tras cambiar el código sea rápido.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          for (var pos = 0; pos < order.length; pos++)
            Row(
              children: [
                Expanded(
                  child: Text('${pos + 1}. ${order[pos]}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                ),
                IconButton(
                  key: ValueKey('dw_up_$pos'),
                  tooltip: 'Subir',
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: pos == 0 ? null : () => _move(pos, -1),
                ),
                IconButton(
                  key: ValueKey('dw_down_$pos'),
                  tooltip: 'Bajar',
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: pos == order.length - 1 ? null : () => _move(pos, 1),
                ),
              ],
            ),
          const SizedBox(height: 4),
          FilledButton.tonal(
            key: const ValueKey('dw_send'),
            onPressed: () => TutorEvents.send(
                'DockerfileWorkbench', 'evidenceSelected', {'order': List.of(order)}),
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
      'story': S.string(description: 'Qué dato hay que conservar'),
      'path': S.string(description: 'Ruta del dato en el contenedor'),
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
    // Simulación del comportamiento real de Docker (no ejecuta Docker).
    final survives = (mount ?? 0) != 0;
    setState(() => observed = survives);
    TutorEvents.send('PersistenceExperiment', 'evidenceSelected', {
      'mount': _mountLabels[mount ?? 0],
      'predicted': predicted,
      'observed': survives,
      'match': predicted == survives,
    });
  }

  void _predict(bool v) {
    setState(() => predicted = v);
    TutorEvents.send('PersistenceExperiment', 'predictionSubmitted', {
      'predicted': v,
      'mount': mount == null ? null : _mountLabels[mount!],
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final what = data['story'] == null
        ? 'el archivo'
        : '${data['story']}${data['path'] == null ? '' : ' (${data['path']})'}';
    return titledCard(context, '${data['title'] ?? 'Persistencia'}',
        '${data['question'] ?? ''}',
        icon: Icons.save_outlined,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          if (data['story'] != null)
            Text('Hay que conservar $what al recrear el contenedor.',
                style: Theme.of(context).textTheme.bodySmall),
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
          const Text('2 · Predice: ¿sobrevive al recrear?', style: TextStyle(fontSize: 12)),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('pe_pred_survive'),
                label: const Text('Sobrevive'),
                selected: predicted == true,
                onSelected: (_) => _predict(true),
              ),
              ChoiceChip(
                key: const ValueKey('pe_pred_lost'),
                label: const Text('Se pierde'),
                selected: predicted == false,
                onSelected: (_) => _predict(false),
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
                'Lo escrito ${observed! ? 'sobrevivió' : 'se perdió'}'
                '${predicted == null ? '.' : (predicted == observed ? ' — acertaste.' : ' — fallaste, revisa tu modelo.')}',
                style: Theme.of(context).textTheme.bodySmall),
        ]);
  }
}
