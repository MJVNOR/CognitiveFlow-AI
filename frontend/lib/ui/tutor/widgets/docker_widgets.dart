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

  // Sin botón: cada selección se corrige en el servidor; completa = entrega.
  void _pick(int i, int v, int n) {
    setState(() => choices[i] = v);
    TutorEvents.send(context, 'ContainerVsVmExplorer',
        choices.length == n ? 'evidenceSelected' : 'selectionChanged',
        {'choices': [for (var k = 0; k < n; k++) choices[k]]});
  }

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
                  onSelected: (_) => _pick(i, 0, scenarios.length),
                ),
                ChoiceChip(
                  key: ValueKey('cve_v_$i'),
                  label: const Text('VM'),
                  selected: choices[i] == 1,
                  onSelected: (_) => _pick(i, 1, scenarios.length),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (!ready)
            Text('Clasificados ${choices.length} de ${scenarios.length}: cada elección se comprueba al momento.',
                style: Theme.of(context).textTheme.bodySmall),
        ]);
  }
}

/// D02: predecir qué existe en un paso de una secuencia de comandos y luego
/// simular la secuencia; emite al completar (con la predicción).
final imageContainerLifecycle = CatalogItem(
  name: 'ImageContainerLifecycle',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del ciclo'),
      'question': S.string(description: 'Consigna'),
      'context': S.string(description: 'Estado inicial y supuestos de la simulación'),
      'stages': S.list(description: 'Secuencia de comandos', items: S.string()),
      'ask_index': S.number(description: 'Índice del paso a predecir'),
      'ask_stage': S.string(description: 'Comando del paso a predecir'),
      'states': S.list(description: 'Estado tras cada paso según el servidor '
          '(null en el paso que se predice); sin él se simula el ciclo imagen/contenedor'),
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

const _lifecycleStages = ['docker pull', 'docker run', 'docker stop', 'docker rm'];

/// Simulación del estado (no ejecuta Docker): ¿hay imagen? ¿contenedor y cómo?
String _lifecycleNote(List<String> done) {
  var image = false, autoRm = false;
  String? container; // null = no existe; 'corriendo' / 'detenido'
  for (final s in done) {
    if (s == 'docker pull' || s == 'docker build') image = true;
    if (s.startsWith('docker run')) {
      container = 'corriendo';
      autoRm = s.endsWith('--rm');
    }
    if (s == 'docker stop') container = autoRm ? null : 'detenido';
    if (s == 'docker start' && container != null) container = 'corriendo';
    if (s == 'docker rm') container = null;
    if (s == 'docker rmi') image = false;
  }
  if (done.isEmpty) return 'Aún no hay imagen ni contenedor.';
  return 'Imagen: ${image ? 'existe' : 'no existe'} · '
      'Contenedor: ${container ?? 'no existe'}.';
}

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

  Map get _data => widget.ctx.data as Map;
  List<String> get _stages => _strings(_data['stages'], _lifecycleStages);

  /// Unidades que comparten este widget envían el estado de cada paso ya
  /// calculado por el servidor (null en el paso que se predice). Sin `states`
  /// vale la simulación local del ciclo imagen/contenedor.
  List<String?>? get _states {
    final v = _data['states'];
    return v is List && v.length == _stages.length
        ? [for (final s in v) s is String ? s : null]
        : null;
  }

  String _observed(int step) {
    final states = _states;
    if (states == null) return _lifecycleNote(_stages.take(step).toList());
    if (step == 0) return 'Aún no se ejecuta ningún paso.';
    return states[step - 1] ?? 'Este es el paso que predijiste: compara con la corrección.';
  }

  /// Paso (índice) sobre el que se predice; null = sin predicción (ejemplo).
  int? get _askIndex {
    final i = _data['ask_index'];
    if (i is num && i >= 0 && i < _stages.length) return i.toInt();
    final s = _data['ask_stage'];
    final j = _stages.indexOf('$s');
    return j >= 0 ? j : null;
  }

  void _advance() {
    if (step >= _stages.length) return;
    setState(() => step++);
    if (step == _stages.length && !sent) {
      sent = true;
      TutorEvents.send(context, 'ImageContainerLifecycle', 'evidenceSelected', {
        'completed': true,
        'stages': _stages,
        if (_askIndex != null) 'ask_index': _askIndex,
        if (_askIndex != null) 'ask_stage': _stages[_askIndex!],
        if (prediction != null) 'prediction': prediction,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stages = _stages;
    final ask = _askIndex;
    final options = _strings(_data['options'], const ['imagen', 'contenedor', 'ambos', 'ninguno']);
    // Primero se predice; la simulación se habilita después (predecir antes de ver).
    final mustPredict = ask != null && prediction == null;
    final cs = Theme.of(context).colorScheme;
    return titledCard(context, '${_data['title'] ?? 'Ciclo de vida'}', '${_data['question'] ?? ''}',
        icon: Icons.sync,
        accent: cs.secondary,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < stages.length; i++)
                Chip(
                  label: Text('${i + 1}. ${stages[i]}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  visualDensity: VisualDensity.compact,
                  side: i == ask ? BorderSide(color: cs.tertiary) : BorderSide.none,
                  backgroundColor: i < step ? cs.primaryContainer : null,
                ),
            ],
          ),
          if (_data['context'] is String) ...[
            const SizedBox(height: 8),
            Text('${_data['context']}', style: Theme.of(context).textTheme.bodySmall),
          ],
          if (ask != null) ...[
            const SizedBox(height: 8),
            Text(_states == null
                    ? 'Predice: tras el paso ${ask + 1} («${stages[ask]}»), ¿qué recursos existen?'
                    : 'Predice: ¿qué pasa en el paso ${ask + 1} («${stages[ask]}»)?',
                style: Theme.of(context).textTheme.labelLarge),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in options)
                ChoiceChip(
                  key: ValueKey('icl_pred_$o'),
                  label: Text(switch (o) {
                    'imagen' => 'Solo la imagen',
                    'contenedor' => 'Solo el contenedor',
                    'ambos' => 'Imagen y contenedor',
                    'ninguno' => 'Ninguno de los dos',
                    _ => o,
                  }),
                  selected: prediction == o,
                  onSelected: sent || step > ask ? null : (_) {
                    setState(() => prediction = o);
                    TutorEvents.send(context, 'ImageContainerLifecycle', 'selectionChanged', {
                      'prediction': o, 'ask_index': ask, 'ask_stage': stages[ask],
                      'completed': false,
                    });
                  },
                ),
            ]),
          ],
          const SizedBox(height: 8),
          Text('Comandos ejecutados: $step de ${stages.length}.',
              style: Theme.of(context).textTheme.labelMedium),
          Semantics(
            liveRegion: true,
            child: Text('${step == 0 ? 'Estado inicial' : 'Estado observado tras el paso $step'}: '
                '${_observed(step)}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: const ValueKey('icl_next'),
                onPressed: step >= stages.length || mustPredict ? null : _advance,
                child: Text(step < stages.length ? 'Ejecutar «${stages[step]}»' : 'Secuencia completa'),
              ),
              TextButton(
                key: const ValueKey('icl_reset'),
                onPressed: () {
                  setState(() {
                    step = 0;
                    sent = false;
                    prediction = null;
                  });
                  TutorEvents.send(context, 'ImageContainerLifecycle', 'selectionChanged', {
                    'completed': false, 'prediction': null,
                  });
                },
                child: const Text('Reiniciar'),
              ),
            ],
          ),
          if (mustPredict)
            Text('Elige tu predicción para empezar la simulación.',
                style: Theme.of(context).textTheme.bodySmall),
          if (!mustPredict && step < stages.length)
            Text('Ahora pulsa «Ejecutar…» para observar cada paso. La evaluación se habilita al completar la secuencia y escribir tu explicación.',
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
      'feedback_enabled': S.boolean(description: 'Corrección disponible durante la práctica'),
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
    // Sin botón: cada movimiento reconstruye y el servidor lo corrige.
    TutorEvents.send(context, 'DockerfileWorkbench', 'evidenceSelected', {'order': List.of(order)});
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
          Text(data['feedback_enabled'] == false
              ? 'Orden propuesto para la prueba; no se corrige antes de entregar.'
              : 'Cada movimiento cambia el orden propuesto; el servidor comprueba las restricciones del ejercicio.',
              style: Theme.of(context).textTheme.bodySmall),
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
      'feedback_enabled': S.boolean(description: 'Corrección disponible durante la práctica'),
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
    TutorEvents.send(context, 'PersistenceExperiment', 'evidenceSelected', {
      'mount': _mountLabels[mount ?? 0],
      'predicted': predicted,
      'observed': survives,
      'match': predicted == survives,
    });
  }

  void _predict(bool v) {
    setState(() => predicted = v);
    TutorEvents.send(context, 'PersistenceExperiment', 'selectionChanged', {
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
                    predicted = null;
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
                onSelected: mount == null || observed != null ? null : (_) => _predict(true),
              ),
              ChoiceChip(
                key: const ValueKey('pe_pred_lost'),
                label: const Text('Se pierde'),
                selected: predicted == false,
                onSelected: mount == null || observed != null ? null : (_) => _predict(false),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: const ValueKey('pe_write'),
                onPressed: mount == null || written ? null : () => setState(() => written = true),
                child: const Text('Escribir archivo'),
              ),
              FilledButton.tonal(
                key: const ValueKey('pe_recreate'),
                onPressed: !written || predicted == null || observed != null ? null : _recreate,
                child: const Text('Recrear'),
              ),
            ],
          ),
          if (observed != null)
            Text(
                'Lo escrito ${observed! ? 'sobrevivió' : 'se perdió'}'
                '${predicted == null || data['feedback_enabled'] == false ? '.' : (predicted == observed ? ' — coincide con tu predicción.' : ' — compara lo observado con tu predicción.')}',
                style: Theme.of(context).textTheme.bodySmall),
        ]);
  }
}

/// D03, D05, D06, D08–D12: decidir qué hacer en casos realistas. Los casos y
/// opciones (barajadas) los genera el servidor; la respuesta nunca llega aquí.
/// Emite evidenceSelected con el índice elegido en cada caso.
final decisionScenarios = CatalogItem(
  name: 'DecisionScenarios',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del reto'),
      'question': S.string(description: 'Consigna'),
      'items': S.list(
          description: 'Casos {prompt, options}',
          items: S.object(properties: {
            'prompt': S.string(),
            'options': S.list(items: S.string()),
          })),
      'mono': S.boolean(description: 'Opciones como comandos de terminal'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "DecisionScenarios", '
        '"title": "Decide en cada caso", "question": "¿Qué harías?"}]',
  ],
  widgetBuilder: (ctx) => _DecisionScenarios(ctx),
);

const _exampleDecision = [
  {
    'prompt': 'El servicio api no responde. ¿Qué miras primero?',
    'options': ['docker logs api', 'docker images', 'docker rm api'],
  },
];

class _DecisionScenarios extends StatefulWidget {
  final CatalogItemContext ctx;
  const _DecisionScenarios(this.ctx);
  @override
  State<_DecisionScenarios> createState() => _DecisionScenariosState();
}

class _DecisionScenariosState extends State<_DecisionScenarios> {
  final choices = <int, int>{};

  // Sin botón: cada elección se corrige en el servidor; completa = entrega.
  void _pick(int i, int j, int n) {
    setState(() => choices[i] = j);
    TutorEvents.send(context, 'DecisionScenarios',
        choices.length == n ? 'evidenceSelected' : 'selectionChanged',
        {'choices': [for (var k = 0; k < n; k++) choices[k]]});
  }

  List<Map> get _items {
    final v = (widget.ctx.data as Map)['items'];
    return v is List && v.isNotEmpty
        ? [for (final i in v) if (i is Map) i]
        : const [..._exampleDecision];
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final mono = data['mono'] == true;
    final items = _items;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ready = choices.length == items.length;
    return titledCard(context, '${data['title'] ?? 'Decide en cada caso'}', '${data['question'] ?? ''}',
        icon: mono ? Icons.terminal : Icons.fact_check_outlined,
        accent: cs.secondary,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            const SizedBox(height: 8),
            Text('Caso ${i + 1}. ${items[i]['prompt']}', style: tt.bodyMedium),
            const SizedBox(height: 4),
            for (final (j, opt) in _strings(items[i]['options'], const []).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: choices[i] == j ? cs.secondaryContainer : cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: choices[i] == j ? cs.secondary : cs.outlineVariant),
                  ),
                  child: InkWell(
                    key: ValueKey('ds_${i}_$j'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _pick(i, j, items.length),
                    child: Semantics(
                      selected: choices[i] == j,
                      button: true,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(children: [
                            Icon(choices[i] == j ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18, color: choices[i] == j ? cs.secondary : cs.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(mono ? '\$ $opt' : opt,
                                  style: mono
                                      ? const TextStyle(fontFamily: 'monospace', fontSize: 13)
                                      : tt.bodyMedium),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (!ready)
            Text('Seleccionados ${choices.length} de ${items.length}. Responde todos los casos y explica tus decisiones.',
                style: tt.bodySmall),
        ]);
  }
}


/// Compartido entre unidades (D04/D05/D08/D09/D10): marcar TODO lo que aplica.
/// Sin botón de envío: cada cambio es la evidencia actual y el servidor la
/// corrige al momento (lo que falta se avisa sin enumerarlo).
final configAudit = CatalogItem(
  name: 'ConfigAudit',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del reto'),
      'question': S.string(description: 'Consigna: qué hay que marcar'),
      'subject': S.string(description: 'Qué se audita (archivo, comando, configuración)'),
      'items': S.list(description: 'Elementos a marcar', items: S.string()),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "ConfigAudit", '
        '"title": "Auditoría", "question": "Marca todo lo que aplica"}]',
  ],
  widgetBuilder: (ctx) => _ConfigAudit(ctx),
);

const _auditItems = [
  '.env con contraseñas',
  'requirements.txt',
  'node_modules/',
];

class _ConfigAudit extends StatefulWidget {
  final CatalogItemContext ctx;
  const _ConfigAudit(this.ctx);
  @override
  State<_ConfigAudit> createState() => _ConfigAuditState();
}

class _ConfigAuditState extends State<_ConfigAudit> {
  final marked = <int>{};

  void _toggle(int i) {
    setState(() => marked.contains(i) ? marked.remove(i) : marked.add(i));
    TutorEvents.send(context, 'ConfigAudit', 'evidenceSelected',
        {'marked': marked.toList()..sort()});
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final items = _strings(data['items'], _auditItems);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return titledCard(context, '${data['title'] ?? 'Marca todo lo que aplica'}',
        '${data['question'] ?? ''}',
        icon: Icons.checklist_rtl,
        accent: cs.secondary,
        children: [
          if (data['subject'] is String) ...[
            const SizedBox(height: 4),
            Text('${data['subject']}', style: tt.bodySmall),
          ],
          const SizedBox(height: 4),
          for (var i = 0; i < items.length; i++)
            CheckboxListTile(
              key: ValueKey('ca_$i'),
              value: marked.contains(i),
              onChanged: (_) => _toggle(i),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text('${i + 1}. ${items[i]}', style: tt.bodyMedium),
            ),
          Text(marked.isEmpty
                  ? 'Puede aplicar más de uno: marca todos y revisa la corrección.'
                  : 'Marcados ${marked.length} de ${items.length}: cada cambio se comprueba al momento.',
              style: tt.bodySmall),
        ]);
  }
}

/// Compartido entre unidades (D03/D06/D07/D10): armar el comando por ranuras.
/// Una opción entre paréntesis significa «no añadir nada» (no se concatena).
final commandComposer = CatalogItem(
  name: 'CommandComposer',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del reto'),
      'question': S.string(description: 'Requisitos que debe cumplir el comando'),
      'prefix': S.string(description: 'Parte fija del comando'),
      'slots': S.list(
          description: 'Ranuras {label, options}',
          items: S.object(properties: {
            'label': S.string(),
            'options': S.list(items: S.string()),
          })),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "CommandComposer", '
        '"title": "Arma el comando", "question": "Cumple todos los requisitos"}]',
  ],
  widgetBuilder: (ctx) => _CommandComposer(ctx),
);

const _exampleSlots = [
  {
    'label': 'modo',
    'options': ['-d', '-it', '(sin esa opción)'],
  },
];

class _CommandComposer extends StatefulWidget {
  final CatalogItemContext ctx;
  const _CommandComposer(this.ctx);
  @override
  State<_CommandComposer> createState() => _CommandComposerState();
}

class _CommandComposerState extends State<_CommandComposer> {
  final picks = <int, int>{};

  List<Map> get _slots {
    final v = (widget.ctx.data as Map)['slots'];
    return v is List && v.isNotEmpty
        ? [for (final s in v) if (s is Map) s]
        : const [..._exampleSlots];
  }

  // Sin botón: completar todas las ranuras es la entrega.
  void _pick(int i, int j, int n) {
    setState(() => picks[i] = j);
    TutorEvents.send(context, 'CommandComposer',
        picks.length == n ? 'evidenceSelected' : 'selectionChanged',
        {'slots': [for (var k = 0; k < n; k++) picks[k]]});
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final slots = _slots;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final chosen = [
      for (var i = 0; i < slots.length; i++)
        if (picks[i] != null) _strings(slots[i]['options'], const [])[picks[i]!],
    ].where((o) => !o.startsWith('(')).toList();
    return titledCard(context, '${data['title'] ?? 'Arma el comando'}',
        '${data['question'] ?? ''}',
        icon: Icons.terminal,
        accent: cs.secondary,
        children: [
          for (var i = 0; i < slots.length; i++) ...[
            const SizedBox(height: 8),
            Text('${slots[i]['label']}', style: tt.labelLarge),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (j, opt) in _strings(slots[i]['options'], const []).indexed)
                ChoiceChip(
                  key: ValueKey('cc_${i}_$j'),
                  label: Text(opt,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  selected: picks[i] == j,
                  onSelected: (_) => _pick(i, j, slots.length),
                ),
            ]),
          ],
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                  '\$ ${data['prefix'] ?? 'docker'}${chosen.isEmpty ? '' : ' ${chosen.join(' ')}'}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
          ),
          if (picks.length < slots.length)
            Text('Elegidas ${picks.length} de ${slots.length} ranuras: cada elección se comprueba al momento.',
                style: tt.bodySmall),
        ]);
  }
}
