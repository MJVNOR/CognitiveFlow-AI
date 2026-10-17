import 'package:flutter/material.dart';

import '../session/lab_session.dart';
import '../state/app_state.dart';
import '../widgets/cards.dart';
import '../genui/tutor_surface.dart';
import 'ml_lab_page.dart'; // ConceptPrimer

// M08: Docker Academy — 4 unidades con widgets GenUI + transferencia al postest.
// La actividad usa el mismo TutorSurface que las intervenciones: el widget emite
// eventos al backend y la justificación viaja en el intento (extra.unit).
class DockerLabPage extends StatefulWidget {
  final String labId;
  final String title;
  const DockerLabPage({super.key, required this.labId, required this.title});
  @override
  State<DockerLabPage> createState() => _DockerState();
}

/// Unidad → widget GenUI + título (espejo de backend DOCKER_WIDGETS).
({String widget, String title}) dockerUnitWidget(String unit) => switch (unit) {
      'M08-D01-containers' =>
        (widget: 'ContainerVsVmExplorer', title: 'Clasifica cada escenario'),
      'M08-D02-lifecycle' =>
        (widget: 'ImageContainerLifecycle', title: 'Avanza el ciclo'),
      'M08-D04-dockerfile' =>
        (widget: 'DockerfileWorkbench', title: 'Ordena y reconstruye'),
      'M08-D07-persistence' =>
        (widget: 'PersistenceExperiment', title: 'Predice y recrea'),
      _ => (widget: 'SocraticQuestionCard', title: 'Docker'),
    };

const _dockerUnits = [
  'M08-D01-containers',
  'M08-D02-lifecycle',
  'M08-D04-dockerfile',
  'M08-D07-persistence',
];

const _unitPrompts = {
  'M08-D01-containers': 'Tres escenarios: ¿contenedor o VM? Justifica cada uno.',
  'M08-D02-lifecycle': 'Ordena el ciclo y predice qué sobrevive a cada paso.',
  'M08-D04-dockerfile':
      'Ordena las instrucciones y predice qué invalida la caché.',
  'M08-D07-persistence': 'Predice qué archivos sobreviven con cada montaje.',
};

class _DockerState extends State<DockerLabPage> {
  final lab = LabSession();
  final statusKey = GlobalKey();
  String unit = 'M08-D01-containers';
  String? posttestUnit;
  List<Map<String, dynamic>>? objectives;
  final justification = TextEditingController();
  final Map<String, Object?> _evidence = {};

  int get seed => lab.posttestMode ? lab.variantSeed(99) : 1;
  String get _activeUnit =>
      lab.posttestMode ? (posttestUnit ?? unit) : unit;

  @override
  void initState() {
    super.initState();
    justification.addListener(
        () => saveDraft(widget.labId, 'justification', justification.text));
    _init();
  }

  Future<void> _init() async {
    // P1.6: reanudar abierta antes de crear una nueva.
    if (!await lab.resume(widget.labId)) {
      await lab.init(widget.labId);
      if (lab.sessionId == null) {
        setState(() {});
        return;
      }
    }
    // Sprint 5: lección por unidad (no bloquea si falla).
    try {
      final objs = await fetchJson('/labs/${widget.labId}/objectives');
      if (!mounted) return;
      setState(() => objectives = [
            for (final o in objs) Map<String, dynamic>.from(o as Map)
          ]);
    } catch (_) {}
    final u = await loadDraft(widget.labId, 'unit');
    final pu = await loadDraft(widget.labId, 'posttest_unit');
    final j = await loadDraft(widget.labId, 'justification');
    if (!mounted) return;
    setState(() {
      if (u != null && _dockerUnits.contains(u)) unit = u;
      if (pu != null && _dockerUnits.contains(pu)) posttestUnit = pu;
      if (j != null) justification.text = j;
    });
  }

  Map<String, dynamic>? _objectiveFor(String id) {
    for (final o in objectives ?? const []) {
      if (o['id'] == id) return o;
    }
    return null;
  }

  Map<String, Object?> _unitIntervention() {
    final u = dockerUnitWidget(_activeUnit);
    return {
      'widget_type': u.widget,
      'widget_parameters': {'title': u.title},
      'socratic_question':
          _unitPrompts[_activeUnit] ?? 'Experimenta y justifica.',
    };
  }

  Future<void> _onActivityEvent(
      String wt, String et, Map<String, Object?> p) async {
    final sid = lab.sessionId;
    if (sid != null) {
      try {
        await postJson('/sessions/$sid/events', {
          'client_event_id': newEventId(),
          'widget_type': wt,
          'event_type': et,
          'payload': p,
        });
      } catch (_) {}
    }
    // La evidencia del widget alimenta la evaluación del intento.
    if (!mounted || et != 'evidenceSelected') return;
    setState(() {
      if (p['order'] is List) {
        _evidence['order'] =
            (p['order'] as List).map((e) => '$e').toList();
      }
      for (final k in ['mount', 'predicted', 'observed']) {
        if (p.containsKey(k)) _evidence[k] = p[k];
      }
    });
  }

  Future<void> _send() async {
    if (lab.sessionId == null || lab.evaluating) return;
    if (justification.text.trim().isEmpty) {
      setState(() => lab.status = lab.posttestMode
          ? 'El diagnóstico es obligatorio'
          : 'La justificación es obligatoria');
      return;
    }
    setState(() {
      lab.evaluating = true;
      lab.status = '';
    });
    try {
      await lab.send({
        'seed': seed,
        'extra': {'unit': _activeUnit, ..._evidence},
        'answer_text': justification.text,
      }, posttest: lab.posttestMode);
      setState(() {
        lab.evaluating = false;
        if (lab.posttestMode) {
          lab.posttestSent = true;
          lab.status = 'Postest entregado (sin ayuda de IA)';
        } else {
          lab.status = 'Guardado ✓ (simulación, sin IA)';
        }
      });
      if (!lab.posttestMode) {
        await lab.evaluate();
        setState(() {});
      }
    } catch (e) {
      setState(() {
        lab.evaluating = false;
        lab.status = 'Error envío: $e';
      });
    }
  }

  Future<void> _retry() async {
    setState(() => lab.evaluating = true);
    await lab.evaluate();
    setState(() => lab.evaluating = false);
  }

  Future<void> _next() async {
    setState(() => lab.nextBusy = true);
    await lab.next();
    setState(() => lab.nextBusy = false);
  }

  @override
  void dispose() {
    justification.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sent = lab.posttestSent;
    final locked = sent || lab.posttestMode;
    final cs = Theme.of(context).colorScheme;
    final obj = _objectiveFor(_activeUnit);
    final parts = _activeUnit.split('-');
    final controls = [
      LabHeader(
        crumb: parts.length >= 2 ? 'Módulo ${parts[0]} · Unidad ${parts[1]}' : null,
        meta: sessionMeta(lab),
        objective: lab.posttestMode
            ? 'Variante nueva. Sin pistas ni tutor hasta entregar.'
            : 'Experimenta con la unidad y justifica por qué',
        step: lab.step,
      ),
      const SizedBox(height: 12),
      if (obj != null) ConceptPrimer(objective: obj),
      if (obj != null) const SizedBox(height: 12),
      if (lab.posttestMode) const PosttestBanner(),
      if (lab.posttestMode) const SizedBox(height: 12),
      SectionCard(
        icon: Icons.science,
        title: '1 · Experimenta con Docker',
        accent: lab.posttestMode ? null : cs.secondary,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final u in _dockerUnits)
                ChoiceChip(
                  key: ValueKey('docker_unit_$u'),
                  label: Text(u.split('-')[1]),
                  selected: _activeUnit == u,
                  onSelected: locked
                      ? null
                      : (_) {
                          setState(() {
                            unit = u;
                            _evidence.clear();
                          });
                          saveDraft(widget.labId, 'unit', u);
                        },
                ),
            ],
          ),
          const SizedBox(height: 8),
          TutorSurface(
            key: ValueKey('docker_activity_$_activeUnit'),
            intervention: _unitIntervention(),
            onEvent: _onActivityEvent,
          ),
        ],
      ),
      const SizedBox(height: 12),
      SectionCard(
        icon: Icons.edit_note,
        title: '2 · Justifica tu decisión',
        accent: lab.posttestMode ? null : cs.tertiary,
        children: [
          TextField(
            key: const ValueKey('docker_justification'),
            controller: justification,
            maxLines: 4,
            minLines: 3,
            enabled: !sent,
            decoration: const InputDecoration(
              labelText: 'Justificación (obligatoria)',
              helperText: 'Cita lo que observaste en el experimento.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (!sent)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('docker_send'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                onPressed: lab.evaluating ? null : _send,
                child: Text(lab.posttestMode
                    ? Strings.deliverPosttest
                    : Strings.sendAttempt),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ];
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!lab.posttestMode &&
            (lab.evalResult != null || lab.intervention != null))
          TextButton(
            key: const ValueKey('go_posttest'),
            onPressed: lab.sessionId == null
                ? null
                : () => confirmEnterPosttest(context, lab, setState, () async {},
                    () {
                      posttestUnit = unit;
                      saveDraft(widget.labId, 'posttest_unit', unit);
                    }),
            child: const Text(Strings.goPosttestNoAI),
          ),
        if (!lab.posttestMode &&
            (lab.evalResult != null ||
                lab.evaluating ||
                lab.evalError != null ||
                lab.intervention != null))
          SectionCard(
            icon: Icons.fact_check,
            title: '3 · Evidencia y siguiente paso',
            children: [
              ResultPanel(lab: lab, onNext: _next, onRetry: _retry),
            ],
          ),
        if (!lab.posttestMode &&
            lab.evalResult == null &&
            !lab.evaluating &&
            lab.evalError == null &&
            lab.intervention == null)
          ResultPanel(lab: lab, onNext: _next, onRetry: _retry),
        if (lab.posttestMode && sent)
          PosttestReflection(
              lab: lab,
              labId: widget.labId,
              onUpdate: () {
                if (lab.done) {
                  clearDrafts(widget.labId,
                      const ['unit', 'posttest_unit', 'justification']);
                }
                setState(() {});
              }),
        StatusText(lab.status, key: statusKey),
      ],
    );
    return Scaffold(
      appBar: DoubleTitleBar(
          title: widget.title, backRoute: '/labs', posttest: lab.posttestMode),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1100) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ListView(padding: const EdgeInsets.all(16), children: controls)),
                    SizedBox(
                      width: (constraints.maxWidth * 0.35).clamp(320.0, 420.0),
                      child: ListView(padding: const EdgeInsets.all(16), children: [result]),
                    ),
                  ],
                );
              }
              return ListView(padding: const EdgeInsets.all(16), children: [...controls, result]);
            },
          ),
        ),
      ),
    );
  }
}
