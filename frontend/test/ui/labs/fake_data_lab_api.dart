// ApiClient falso para Data Detective: misma forma de respuestas que el
// backend (labs_data.generate, evaluate mock, next-intervention). Sin red.
import 'dart:convert';

import 'package:cognitiveflow/data/services/api_client.dart';

/// Etapa del servidor simulada: qué ya existe en la sesión al reanudar.
enum FakeStage { fresh, evaluated, intervention, posttest }

class FakeDataLabApi extends ApiClient {
  FakeStage stage;
  final posts = <String>[];
  final events = <Map<String, dynamic>>[];
  /// Estado por unidad Docker que devuelve `/me/docker-units`.
  Map<String, dynamic> dockerUnits = {};

  /// Intervención que «elige» el servidor (por defecto, la de datos).
  final Map<String, dynamic> iv;
  FakeDataLabApi([this.stage = FakeStage.fresh, Map<String, dynamic>? iv])
      : iv = iv ?? intervention,
        super(baseUrl: 'http://fake');

  static Map<String, dynamic> dataset(int seed) {
    // Determinista y con los mismos problemas plantados que el backend.
    var x = seed * 9301 + 49297;
    double rnd(double a, double b) {
      x = (x * 9301 + 49297) % 233280;
      return a + (b - a) * x / 233280;
    }

    final rows = <Map<String, dynamic>>[
      for (var i = 0; i < 30; i++)
        {
          'id': i,
          'temp': double.parse(rnd(18, 25).toStringAsFixed(1)),
          'unit': 'C',
          'pressure': double.parse(rnd(100, 110).toStringAsFixed(1)),
          'line': i % 3 == 0 ? 'B' : 'A',
        },
    ];
    rows[3]['pressure'] = null;
    rows[17]['pressure'] = null;
    rows[12] = {...rows[5], 'id': 12};
    for (final r in [7, 21]) {
      rows[r]['temp'] =
          double.parse(((rows[r]['temp'] as double) * 9 / 5 + 32).toStringAsFixed(1));
      rows[r]['unit'] = 'F';
    }
    rows[25]['pressure'] = 999.9;
    rows[2]['temp'] = -273.2;
    return {
      'lab_id': 'lab-data',
      'columns': ['id', 'temp', 'unit', 'pressure', 'line'],
      'rows': rows,
    };
  }

  static const evaluated = {
    'evaluator': 'mock',
    'status': 'evaluated',
    'rubric_version': 'data-cleaning-v1',
    'criteria': [
      {'id': 'exactitud', 'score': 2},
      {'id': 'evidencia', 'score': 2},
      {'id': 'causal', 'score': 2},
      {'id': 'alternativas', 'score': 0},
      {'id': 'metacognicion', 'score': 0},
    ],
    'detail': {
      'types': {
        '25': {'claimed': 'outlier', 'actual': 'outlier', 'ok': true},
        '7': {'claimed': 'outlier', 'actual': 'unit', 'ok': false},
      },
      'types_ok': 1,
    },
  };

  static const intervention = {
    'widget_type': 'DataTableExplorer',
    'widget_parameters': {
      'type': 'DataTableExplorer',
      'title': 'Revisa las filas marcadas',
      'parameters': {
        'n_rows': 30,
        'rows': [
          {'ref': '2', 'temp': -273.2, 'unit': 'C', 'pressure': 109.0, 'line': 'A'},
          {'ref': '4', 'temp': 21.6, 'unit': 'C', 'pressure': 107.8, 'line': 'A'},
          {'ref': '7', 'temp': 69.6, 'unit': 'F', 'pressure': 100.1, 'line': 'A'},
          {'ref': '17', 'temp': 22.4, 'unit': 'C', 'pressure': null, 'line': 'A'},
          {'ref': '25', 'temp': 20.3, 'unit': 'C', 'pressure': 999.9, 'line': 'B'},
          {'ref': '26', 'temp': 23.1, 'unit': 'C', 'pressure': 104.4, 'line': 'A'},
        ],
      },
    },
    'socratic_question':
        '¿Qué diferencia una lectura imposible de una unidad distinta?',
    'strategy': 'remediate',
    'reason': 'Promedio 1.2: faltan anomalías por detectar o justificar',
  };

  @override
  Future<Map<String, dynamic>> getMap(String path) async {
    if (path.contains('/curve?')) {
      // Curvas sintéticas: la validación se despega desde la época 4.
      return {
        'simulated': true,
        'train': [for (var i = 0; i < 10; i++) 1.0 - i * 0.08],
        'val': [for (var i = 0; i < 10; i++) i < 4 ? 1.0 - i * 0.08 : 0.68 + (i - 4) * 0.05],
      };
    }
    if (path.contains('/docker-activity?')) {
      final q = Uri.parse(path).queryParameters;
      final seed = int.tryParse(q['seed'] ?? '1') ?? 1;
      return switch (q['unit']) {
        'M08-D01-containers' => {
            'unit': q['unit'],
            'seed': seed,
            'scenarios': ['Caso A $seed', 'Caso B $seed', 'Caso C $seed'],
          },
        'M08-D02-lifecycle' => {
            'unit': q['unit'],
            'seed': seed,
            'stages': ['docker pull', 'docker run', 'docker stop', 'docker rm'],
            'ask_index': 3,
            'ask_stage': 'docker rm',
            'options': ['imagen', 'contenedor', 'ambos', 'ninguno'],
          },
        _ => {'unit': q['unit'], 'seed': seed},
      };
    }
    if (path == '/me/docker-units') return dockerUnits;
    if (path.contains('/distributions?')) {
      return {
        'features': {
          'temp': {'ref': [2, 5, 9, 5, 2], 'cur': [1, 2, 5, 9, 6], 'bins': [18, 20, 22, 24, 26]},
          'pressure': {'ref': [2, 5, 9, 5, 2], 'cur': [2, 5, 9, 5, 2], 'bins': [100, 102, 104, 106, 108]},
        },
        'series': [for (var i = 0; i < 180; i++) i < 90 ? 20.0 : 23.0],
      };
    }
    if (path.contains('/dataset')) {
      final seed = int.tryParse(Uri.parse(path).queryParameters['seed'] ?? '1') ?? 1;
      return dataset(seed);
    }
    if (path == '/sessions/sess-1') {
      return {
        'id': 'sess-1',
        'status': stage == FakeStage.posttest ? 'posttest' : 'active',
        'level': 'guided_practice',
        'assistance': {'hints': 0, 'socratic': 0, 'interventions': 0},
        // Como el backend: intento evaluado + respuesta al reto GenUI.
        'can_enter_posttest': stage == FakeStage.intervention ||
            events.any((e) =>
                e['widget_type'] == iv['widget_type'] &&
                e['event_type'] == _submitEvent[iv['widget_type']]),
        'last_eval': stage == FakeStage.fresh ? null : _json(evaluated),
        'variant': stage == FakeStage.posttest ? {'seed': 412} : null,
      };
    }
    throw Exception('404 $path');
  }

  @override
  Future<List<dynamic>> getList(String path) async {
    if (path.startsWith('/me/sessions')) {
      return [
        {'id': 'sess-1', 'status': 'active'}
      ];
    }
    if (path == '/sessions/sess-1/attempts') {
      return stage == FakeStage.fresh
          ? []
          : [
              {
                'id': 'att-1',
                'input': {'flags': [25, 7], 'seed': 1},
              }
            ];
    }
    if (path == '/sessions/sess-1/interventions') {
      return stage == FakeStage.intervention ? [_json(iv)] : [];
    }
    if (path == '/sessions/sess-1/tutor-history') {
      return stage == FakeStage.fresh && !posts.contains('/sessions/sess-1/socratic')
          ? []
          : [
              {'question': '¿Qué evidencia distingue la fila 7 de la 25?', 'provider': 'mock'}
            ];
    }
    if (path.endsWith('/objectives')) {
      return [
        {
          'id': 'M04-DATA-quality',
          'title': 'Calidad de datos antes de entrenar',
          'lesson': 'Un modelo aprende lo que hay en la tabla, incluidos sus errores.',
          'worked_example': [],
        }
      ];
    }
    throw Exception('404 $path');
  }

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    posts.add(path);
    if (path == '/sessions') return {'id': 'sess-1'};
    if (path == '/sessions/sess-1/attempts') return {'id': 'att-1'};
    if (path == '/sessions/sess-1/evaluate') return _json(evaluated);
    if (path == '/sessions/sess-1/socratic') {
      return {
        'question': '¿Qué evidencia distingue la fila 7 de la 25?',
        'feedback': {'texto': 'Detectaste la presión imposible con evidencia.'},
      };
    }
    if (path == '/sessions/sess-1/next-intervention') return _json(iv);
    if (path == '/sessions/sess-1/events') {
      events.add(body);
      // Como el backend: solo la entrega del reto contrastivo trae corrección.
      if (body['widget_type'] == 'DataTableExplorer' && body['event_type'] == 'argumentSubmitted') {
        final cls = (body['payload'] as Map)['classifications'] as Map? ?? {};
        return {
          'id': body['client_event_id'],
          'deduped': false,
          'check': {
            'correctas': [if (cls['25'] == 'outlier') '25'],
            'revisar': [if (cls['7'] != 'unit') '7', '2', '17'],
            'item': 'fila',
            'consejo': 'Compara su evidencia con las demás.',
          },
        };
      }
      return {'id': body['client_event_id'], 'deduped': false};
    }
    if (path == '/sessions/sess-1/posttest') return {'status': 'begin', 'seed': 412};
    throw Exception('404 $path');
  }
}

// Copia mutable, como un body JSON real (los widgets ordenan listas in situ).
Map<String, dynamic> _json(Map m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

// Espejo de backend SUBMIT_EVENT (evento de entrega real de cada widget).
const _submitEvent = {
  'DataTableExplorer': 'argumentSubmitted',
  'DriftDistributionExplorer': 'argumentSubmitted',
  'EvidenceComparison': 'argumentSubmitted',
  'HypothesisEditor': 'hypothesisSubmitted',
  'ContainerVsVmExplorer': 'evidenceSelected',
  'DockerfileWorkbench': 'evidenceSelected',
};
