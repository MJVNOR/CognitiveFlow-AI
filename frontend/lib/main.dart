import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'genui/tutor_surface.dart';

const apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

String? apiToken;

Map<String, String> _headers([bool json = false]) => {
      if (apiToken != null) 'Authorization': 'Bearer $apiToken',
      if (json) 'Content-Type': 'application/json',
    };

void main() => runApp(const CognitiveFlowApp());

class CognitiveFlowApp extends StatefulWidget {
  const CognitiveFlowApp({super.key});
  @override
  State<CognitiveFlowApp> createState() => _AppState();
}

class _AppState extends State<CognitiveFlowApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CognitiveFlow AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: apiToken == null
          ? LoginPage(onLogin: (t) => setState(() => apiToken = t))
          : const Shell(),
    );
  }
}

class LoginPage extends StatefulWidget {
  final void Function(String token) onLogin;
  const LoginPage({super.key, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginState();
}

class _LoginState extends State<LoginPage> {
  final userId = TextEditingController(text: 's1');
  String status = '';

  Future<void> _login() async {
    try {
      final r = await http.post(
        Uri.parse('$apiBase/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId.text.trim()}),
      );
      if (r.statusCode != 200) throw Exception('${r.statusCode} usuario desconocido');
      widget.onLogin((jsonDecode(r.body) as Map)['token'] as String);
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CognitiveFlow AI')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Login demo (s1-s4 estudiante, i1 instructor)'),
            TextField(controller: userId, decoration: const InputDecoration(labelText: 'user_id')),
            const SizedBox(height: 12),
            FilledButton(onPressed: _login, child: const Text('Entrar')),
            if (status.isNotEmpty) Text(status),
          ],
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = const [
      AcademyPage(),
      LabsPage(),
      ProgressPage(),
      InstructorPage(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('CognitiveFlow AI')),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school), label: 'Academia'),
          NavigationDestination(icon: Icon(Icons.science), label: 'Lab'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'Progreso'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Instructor'),
        ],
      ),
    );
  }
}

Future<List<dynamic>> fetchJson(String path) async {
  final r = await http.get(Uri.parse('$apiBase$path'), headers: _headers());
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as List;
}

Future<Map<String, dynamic>> fetchMap(String path) async {
  final r = await http.get(Uri.parse('$apiBase$path'), headers: _headers());
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
  final r = await http.post(
    Uri.parse('$apiBase$path'),
    headers: _headers(true),
    body: jsonEncode(body),
  );
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

class AcademyPage extends StatelessWidget {
  const AcademyPage({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: fetchJson('/modules'),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return Center(child: Text('Sin conexión API: ${s.error}'));
        final modules = s.data!;
        return ListView(
          children: [for (final m in modules) ListTile(title: Text(m['title']))],
        );
      },
    );
  }
}

class LabsPage extends StatelessWidget {
  const LabsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: fetchJson('/labs'),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return Center(child: Text('Sin conexión API: ${s.error}'));
        final labs = s.data!;
        return ListView(
          children: [
            for (final l in labs)
              ListTile(
                title: Text(l['title']),
                subtitle: Text(l['lab_type']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final Widget page = switch (l['lab_type']) {
                    'data_detective' => DataLabPage(labId: l['id'], title: l['title']),
                    'model_monitoring' => MonitorLabPage(labId: l['id'], title: l['title']),
                    _ => LabDetailPage(labId: l['id'], title: l['title']),
                  };
                  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
                },
              ),
          ],
        );
      },
    );
  }
}

/// Panel compartido: evaluación + socrática + siguiente intervención GenUI.
class ResultPanel extends StatelessWidget {
  final Map<String, dynamic>? evalResult;
  final String socraticQ;
  final Map? intervention;
  final VoidCallback onNext;
  const ResultPanel({
    super.key,
    required this.evalResult,
    required this.socraticQ,
    required this.intervention,
    required this.onNext,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (evalResult != null)
          Text(
            'Evaluación (${evalResult!['evaluator']}): '
            '${(evalResult!['criteria'] as List).map((c) => "${c['id']}=${c['score']}").join(', ')}',
            style: const TextStyle(fontSize: 12),
          ),
        if (socraticQ.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Tutor: $socraticQ', style: const TextStyle(fontStyle: FontStyle.italic)),
          FilledButton.tonal(onPressed: onNext, child: const Text('Siguiente actividad')),
        ],
        if (intervention != null) ...[
          const SizedBox(height: 8),
          TutorSurface(intervention: intervention!),
        ],
      ],
    );
  }
}

// G1: tabla sintética, marcar anomalías, justificar, postest con tabla nueva.
class DataLabPage extends StatefulWidget {
  final String labId;
  final String title;
  const DataLabPage({super.key, required this.labId, required this.title});
  @override
  State<DataLabPage> createState() => _DataLabState();
}

class _DataLabState extends State<DataLabPage> {
  String? sessionId;
  String? attemptId;
  List columns = [];
  List rows = [];
  final flagged = <int>{};
  final justification = TextEditingController();
  Map<String, dynamic>? evalResult;
  Map? intervention;
  String socraticQ = '';
  String status = '';
  bool posttestMode = false;

  int get seed => posttestMode ? 99 : 1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final s = await postJson('/sessions', {
        'student_id': 's1',
        'lab_template_id': widget.labId,
      });
      sessionId = s['id'] as String;
      await _loadTable();
    } catch (e) {
      setState(() => status = 'Error API: $e');
    }
  }

  Future<void> _loadTable() async {
    try {
      final ds = await fetchMap('/labs/${widget.labId}/dataset?seed=$seed');
      setState(() {
        columns = ds['columns'] as List;
        rows = ds['rows'] as List;
        flagged.clear();
      });
    } catch (e) {
      setState(() => status = 'Error tabla: $e');
    }
  }

  Future<void> _send() async {
    if (sessionId == null) return;
    try {
      final path = posttestMode ? 'posttest' : 'attempts';
      final a = await postJson('/sessions/$sessionId/$path', {
        'seed': seed,
        'flags': flagged.toList(),
        'answer_text': justification.text,
      });
      attemptId = a['id'] as String;
      setState(() => status = posttestMode ? 'Postest entregado (sin ayuda)' : 'Guardado ✓');
      if (!posttestMode) await _evaluate();
    } catch (e) {
      setState(() => status = 'Error envío: $e');
    }
  }

  Future<void> _evaluate() async {
    try {
      final ev = await postJson('/sessions/$sessionId/evaluate', {'attempt_id': attemptId});
      final sq = await postJson('/sessions/$sessionId/socratic', {'attempt_id': attemptId});
      setState(() {
        evalResult = ev;
        socraticQ = (sq['question'] ?? '') as String;
      });
    } catch (e) {
      setState(() => status = 'Error evaluación: $e');
    }
  }

  Future<void> _next() async {
    try {
      final iv = await postJson(
          '/sessions/$sessionId/next-intervention', {'attempt_id': attemptId});
      setState(() => intervention = iv);
    } catch (e) {
      setState(() => status = 'Error siguiente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(posttestMode ? '${widget.title} (postest)' : widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(posttestMode
              ? 'Tabla nueva, sin ayuda. Marca anomalías y justifica.'
              : 'Marca las filas con anomalías y justifica tu plan de limpieza.'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [for (final c in columns) DataColumn(label: Text('$c'))],
              rows: [
                for (final r in rows)
                  DataRow(
                    selected: flagged.contains(r['id']),
                    onSelectChanged: (_) => setState(() {
                      flagged.contains(r['id'])
                          ? flagged.remove(r['id'])
                          : flagged.add(r['id'] as int);
                    }),
                    cells: [for (final c in columns) DataCell(Text('${r['$c'] ?? '—'}'))],
                  ),
              ],
            ),
          ),
          TextField(
            controller: justification,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Justificación y plan de limpieza',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _send,
            child: Text(posttestMode ? 'Entregar postest' : 'Enviar intento'),
          ),
          if (!posttestMode)
            TextButton(
              onPressed: sessionId == null
                  ? null
                  : () => setState(() {
                        posttestMode = true;
                        evalResult = null;
                        intervention = null;
                        socraticQ = '';
                        _loadTable();
                      }),
              child: const Text('Ir al postest (tabla nueva, sin ayuda)'),
            ),
          if (!posttestMode)
            ResultPanel(
              evalResult: evalResult,
              socraticQ: socraticQ,
              intervention: intervention,
              onNext: _next,
            ),
          if (status.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(status)),
        ],
      ),
    );
  }
}

class LabDetailPage extends StatefulWidget {
  final String labId;
  final String title;
  const LabDetailPage({super.key, required this.labId, required this.title});
  @override
  State<LabDetailPage> createState() => _LabDetailState();
}

class _LabDetailState extends State<LabDetailPage> {
  double complexity = 5;
  double noise = 20;
  final hypo = TextEditingController();
  String? sessionId;
  String? attemptId;
  Map<String, dynamic>? curve;
  Map<String, dynamic>? evalResult;
  Map<String, dynamic>? intervention;
  String socraticQ = '';
  String status = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final s = await postJson('/sessions', {
        'student_id': 's1',
        'lab_template_id': widget.labId,
      });
      sessionId = s['id'] as String;
      await _loadCurve();
    } catch (e) {
      setState(() => status = 'Error API: $e');
    }
  }

  Future<void> _loadCurve() async {
    try {
      final c = await fetchMap(
        '/labs/${widget.labId}/curve?complexity=${complexity.round()}&noise_pct=${noise.round()}&seed=1',
      );
      setState(() => curve = c);
    } catch (e) {
      setState(() => status = 'Error curva: $e');
    }
  }

  Future<void> _send() async {
    if (sessionId == null) return;
    try {
      final a = await postJson('/sessions/$sessionId/attempts', {
        'complexity': complexity.round(),
        'noise_pct': noise.round(),
        'seed': 1,
        'answer_text': hypo.text,
      });
      attemptId = a['id'] as String;
      setState(() => status = 'Guardado ✓ (simulación, sin IA)');
      await _evaluate();
    } catch (e) {
      setState(() => status = 'Error envío: $e');
    }
  }

  Future<void> _evaluate() async {
    if (sessionId == null || attemptId == null) return;
    try {
      final ev = await postJson('/sessions/$sessionId/evaluate', {'attempt_id': attemptId});
      final sq = await postJson('/sessions/$sessionId/socratic', {'attempt_id': attemptId});
      setState(() {
        evalResult = ev;
        socraticQ = (sq['question'] ?? '') as String;
      });
    } catch (e) {
      setState(() => status = 'Error evaluación: $e');
    }
  }

  Future<void> _next() async {
    if (sessionId == null || attemptId == null) return;
    try {
      final iv = await postJson('/sessions/$sessionId/next-intervention', {'attempt_id': attemptId});
      setState(() => intervention = iv);
    } catch (e) {
      setState(() => status = 'Error siguiente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final train = (curve?['train'] as List?)?.cast<num>() ?? [];
    final val = (curve?['val'] as List?)?.cast<num>() ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Predice el efecto de la complejidad y justifica por qué'),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: CustomPaint(painter: CurvePainter(train, val)),
          ),
          if (curve?['simulated'] == true)
            const Text('Curvas sintéticas (simulación)', style: TextStyle(fontSize: 12)),
          Slider(
            value: complexity, min: 1, max: 10, divisions: 9,
            label: 'Complejidad ${complexity.round()}',
            onChanged: (v) { setState(() => complexity = v); _loadCurve(); },
          ),
          Slider(
            value: noise, min: 0, max: 50, divisions: 10,
            label: 'Ruido ${noise.round()}%',
            onChanged: (v) { setState(() => noise = v); _loadCurve(); },
          ),
          TextField(
            controller: hypo,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Hipótesis / justificación (obligatoria)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _send, child: const Text('Enviar intento')),
          ResultPanel(
            evalResult: evalResult,
            socraticQ: socraticQ,
            intervention: intervention,
            onNext: _next,
          ),
          TextButton(
            onPressed: sessionId == null ? null : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PosttestPage(labId: widget.labId, sessionId: sessionId!),
              ),
            ),
            child: const Text('Ir al postest (sin ayuda de IA)'),
          ),
          if (status.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(status),
          ),
        ],
      ),
    );
  }
}

// D4: variante nueva (seed 99), sin pistas ni tutor; luego reflexión honesta.
class PosttestPage extends StatefulWidget {
  final String labId;
  final String sessionId;
  const PosttestPage({super.key, required this.labId, required this.sessionId});
  @override
  State<PosttestPage> createState() => _PosttestState();
}

class _PosttestState extends State<PosttestPage> {
  double complexity = 6;
  double noise = 20;
  final answer = TextEditingController();
  final reflection = TextEditingController();
  Map<String, dynamic>? curve;
  String status = '';
  bool sent = false;
  bool done = false;

  @override
  void initState() {
    super.initState();
    _loadCurve();
  }

  Future<void> _loadCurve() async {
    try {
      final c = await fetchMap(
        '/labs/${widget.labId}/curve?complexity=${complexity.round()}&noise_pct=${noise.round()}&seed=99',
      );
      setState(() => curve = c);
    } catch (e) {
      setState(() => status = 'Error curva: $e');
    }
  }

  Future<void> _sendPosttest() async {
    try {
      await postJson('/sessions/${widget.sessionId}/posttest', {
        'complexity': complexity.round(),
        'noise_pct': noise.round(),
        'answer_text': answer.text,
      });
      setState(() {
        sent = true;
        status = 'Postest entregado (sin ayuda de IA)';
      });
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  Future<void> _sendReflection() async {
    try {
      await postJson('/sessions/${widget.sessionId}/reflection', {'text': reflection.text});
      setState(() {
        done = true;
        status = 'Sesión cerrada. Gracias por tu reflexión.';
      });
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final train = (curve?['train'] as List?)?.cast<num>() ?? [];
    final val = (curve?['val'] as List?)?.cast<num>() ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Postest (sin ayuda)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Variante nueva. Sin pistas ni tutor hasta entregar.'),
          const SizedBox(height: 12),
          SizedBox(height: 180, child: CustomPaint(painter: CurvePainter(train, val))),
          Slider(
            value: complexity, min: 1, max: 10, divisions: 9,
            label: 'Complejidad ${complexity.round()}',
            onChanged: sent ? null : (v) { setState(() => complexity = v); _loadCurve(); },
          ),
          TextField(
            controller: answer, maxLines: 3, enabled: !sent,
            decoration: const InputDecoration(
              labelText: 'Tu diagnóstico y justificación',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (!sent) FilledButton(onPressed: _sendPosttest, child: const Text('Entregar postest')),
          if (sent && !done) ...[
            TextField(
              controller: reflection, maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reflexión: ¿qué aprendiste?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _sendReflection, child: const Text('Enviar reflexión y cerrar')),
          ],
          if (status.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(status),
          ),
        ],
      ),
    );
  }
}

class CurvePainter extends CustomPainter {  final List<num> train;
  final List<num> val;
  CurvePainter(this.train, this.val);
  @override
  void paint(Canvas canvas, Size size) {
    if (train.isEmpty) return;
    final pTrain = Paint()..color = Colors.blue..strokeWidth = 2;
    final pVal = Paint()..color = Colors.orange..strokeWidth = 2;
    Path pathFor(List<num> ys) {
      final p = Path();
      for (var i = 0; i < ys.length; i++) {
        final x = size.width * i / (ys.length - 1);
        final y = size.height - (ys[i].toDouble().clamp(0, 1) * size.height);
        if (i == 0) { p.moveTo(x, y); } else { p.lineTo(x, y); }
      }
      return p;
    }
    canvas.drawPath(pathFor(train), pTrain);
    canvas.drawPath(pathFor(val), pVal);
  }
  @override
  bool shouldRepaint(covariant CurvePainter old) =>
      old.train != train || old.val != val;
}

// E5: instructor revisa intentos con rúbrica propia (0-4 por criterio).
class StudentSessionsPage extends StatelessWidget {
  final String studentId;
  final String name;
  const StudentSessionsPage({super.key, required this.studentId, required this.name});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: FutureBuilder<List<dynamic>>(
        future: fetchJson('/instructor/students/$studentId/sessions'),
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          final sessions = s.data!;
          if (sessions.isEmpty) return const Center(child: Text('Sin sesiones'));
          return ListView(
            children: [
              for (final se in sessions)
                ListTile(
                  title: Text('${se['lab_template_id']} · ${se['status']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionReviewPage(sessionId: se['id']),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

const reviewCriteria = ['exactitud', 'evidencia', 'causal', 'alternativas', 'metacognicion'];

class SessionReviewPage extends StatefulWidget {
  final String sessionId;
  const SessionReviewPage({super.key, required this.sessionId});
  @override
  State<SessionReviewPage> createState() => _ReviewState();
}

class _ReviewState extends State<SessionReviewPage> {
  final scores = {for (final c in reviewCriteria) c: 2.0};
  final notes = TextEditingController();
  String status = '';

  Future<void> _send(String attemptId) async {
    try {
      await postJson('/instructor/attempts/$attemptId/reviews', {
        'rubric_scores': {for (final e in scores.entries) e.key: e.value.round()},
        'notes': notes.text,
      });
      setState(() => status = 'Revisión guardada ✓');
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar intentos')),
      body: FutureBuilder<List<dynamic>>(
        future: fetchJson('/sessions/${widget.sessionId}/attempts'),
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          final attempts = s.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final a in attempts) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${a['answer']}', style: const TextStyle(fontSize: 13)),
                        for (final crit in reviewCriteria)
                          Row(
                            children: [
                              SizedBox(width: 110, child: Text(crit, style: const TextStyle(fontSize: 12))),
                              Expanded(
                                child: Slider(
                                  value: scores[crit]!, min: 0, max: 4, divisions: 4,
                                  label: '${scores[crit]!.round()}',
                                  onChanged: (v) => setState(() => scores[crit] = v),
                                ),
                              ),
                            ],
                          ),
                        TextField(
                          controller: notes,
                          decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder()),
                        ),
                        FilledButton(
                          onPressed: () => _send(a['id']),
                          child: const Text('Guardar revisión'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (status.isNotEmpty) Text(status),
            ],
          );
        },
      ),
    );
  }
}

// G2: referencia vs actual + serie con cambio; diagnosticar deriva y decidir acción.
class MonitorLabPage extends StatefulWidget {
  final String labId;
  final String title;
  const MonitorLabPage({super.key, required this.labId, required this.title});
  @override
  State<MonitorLabPage> createState() => _MonitorState();
}

class _MonitorState extends State<MonitorLabPage> {
  String? sessionId;
  String? attemptId;
  String feature = 'temp';
  double changepoint = 90;
  final answer = TextEditingController();
  Map<String, dynamic>? dist;
  Map<String, dynamic>? evalResult;
  Map? intervention;
  String socraticQ = '';
  String status = '';
  bool posttestMode = false;

  int get seed => posttestMode ? 99 : 1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final s = await postJson('/sessions', {
        'student_id': 's1',
        'lab_template_id': widget.labId,
      });
      sessionId = s['id'] as String;
      await _load();
    } catch (e) {
      setState(() => status = 'Error API: $e');
    }
  }

  Future<void> _load() async {
    try {
      final d = await fetchMap('/labs/${widget.labId}/distributions?seed=$seed');
      setState(() => dist = d);
    } catch (e) {
      setState(() => status = 'Error datos: $e');
    }
  }

  Future<void> _send() async {
    if (sessionId == null) return;
    try {
      final path = posttestMode ? 'posttest' : 'attempts';
      final a = await postJson('/sessions/$sessionId/$path', {
        'seed': seed,
        'extra': {'feature': feature, 'changepoint': changepoint.round()},
        'answer_text': answer.text,
      });
      attemptId = a['id'] as String;
      setState(() => status = posttestMode ? 'Postest entregado (sin ayuda)' : 'Guardado ✓');
      if (!posttestMode) await _evaluate();
    } catch (e) {
      setState(() => status = 'Error envío: $e');
    }
  }

  Future<void> _evaluate() async {
    try {
      final ev = await postJson('/sessions/$sessionId/evaluate', {'attempt_id': attemptId});
      final sq = await postJson('/sessions/$sessionId/socratic', {'attempt_id': attemptId});
      setState(() {
        evalResult = ev;
        socraticQ = (sq['question'] ?? '') as String;
      });
    } catch (e) {
      setState(() => status = 'Error evaluación: $e');
    }
  }

  Future<void> _next() async {
    try {
      final iv = await postJson(
          '/sessions/$sessionId/next-intervention', {'attempt_id': attemptId});
      setState(() => intervention = iv);
    } catch (e) {
      setState(() => status = 'Error siguiente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final feats = (dist?['features'] as Map?) ?? {};
    final sel = (feats[feature] as Map?) ?? {};
    final ref = (sel['ref'] as List?)?.cast<num>() ?? [];
    final cur = (sel['cur'] as List?)?.cast<num>() ?? [];
    final series = (dist?['series'] as List?)?.cast<num>() ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(posttestMode ? '${widget.title} (postest)' : widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(posttestMode
              ? 'Distribución nueva, sin ayuda. ¿Deriva? ¿Reentrenar o monitorear?'
              : '¿Qué feature deriva? Compara referencia vs actual y ubica el cambio.'),
          DropdownButton<String>(
            value: feature,
            items: const [
              DropdownMenuItem(value: 'temp', child: Text('temp')),
              DropdownMenuItem(value: 'pressure', child: Text('pressure')),
              DropdownMenuItem(value: 'vibration', child: Text('vibration')),
            ],
            onChanged: (v) => setState(() => feature = v ?? feature),
          ),
          SizedBox(height: 120, child: CustomPaint(painter: HistPainter(ref, cur))),
          const Text('Azul=referencia, naranja=actual', style: TextStyle(fontSize: 12)),
          SizedBox(height: 120, child: CustomPaint(painter: CurvePainter(series, const []))),
          Slider(
            value: changepoint, min: 0, max: 179, divisions: 179,
            label: 'Cambio en t=${changepoint.round()}',
            onChanged: (v) => setState(() => changepoint = v),
          ),
          TextField(
            controller: answer, maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Hipótesis de deriva y decisión',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _send,
            child: Text(posttestMode ? 'Entregar postest' : 'Enviar intento'),
          ),
          if (!posttestMode)
            TextButton(
              onPressed: sessionId == null
                  ? null
                  : () => setState(() {
                        posttestMode = true;
                        evalResult = null;
                        intervention = null;
                        socraticQ = '';
                        _load();
                      }),
              child: const Text('Ir al postest (sin ayuda)'),
            ),
          if (!posttestMode)
            ResultPanel(
              evalResult: evalResult,
              socraticQ: socraticQ,
              intervention: intervention,
              onNext: _next,
            ),
          if (status.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(status)),
        ],
      ),
    );
  }
}

class HistPainter extends CustomPainter {
  final List<num> ref;
  final List<num> cur;
  HistPainter(this.ref, this.cur);
  @override
  void paint(Canvas canvas, Size size) {
    if (ref.isEmpty) return;
    final maxV = [...ref, ...cur].reduce((a, b) => a > b ? a : b).toDouble();
    final bw = size.width / ref.length;
    for (var i = 0; i < ref.length; i++) {
      final h1 = size.height * ref[i].toDouble() / maxV;
      final h2 = size.height * (i < cur.length ? cur[i].toDouble() : 0) / maxV;
      canvas.drawRect(
        Rect.fromLTWH(i * bw + 1, size.height - h1, bw / 2 - 1, h1),
        Paint()..color = Colors.blue,
      );
      canvas.drawRect(
        Rect.fromLTWH(i * bw + bw / 2, size.height - h2, bw / 2 - 1, h2),
        Paint()..color = Colors.orange,
      );
    }
  }
  @override
  bool shouldRepaint(covariant HistPainter old) => old.ref != ref || old.cur != cur;
}

class ProgressPage extends StatelessWidget {  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Progreso por evidencias (siguiente slice)'));
  }
}

class InstructorPage extends StatelessWidget {
  const InstructorPage({super.key});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: fetchJson('/instructor/students'),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return Center(child: Text('Sin conexión API: ${s.error}'));
        final students = s.data!;
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${students.length} estudiantes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final st in students)
              ListTile(
                title: Text(st['display_name']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentSessionsPage(
                      studentId: st['id'],
                      name: st['display_name'],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
