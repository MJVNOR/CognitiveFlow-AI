import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'genui/tutor_surface.dart';

const apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

// ponytail: copy centralizado (ES ahora, i18n después); no añadir intl hasta que se pida.
abstract final class Strings {
  static const appTitle = 'CognitiveFlow AI';
  static const loginHint = 'Login demo (s1-s4 estudiante, i1 instructor)';
  static const loginUserId = 'user_id';
  static const loginEnter = 'Entrar';
  static const tabAcademy = 'Academia';
  static const tabLabs = 'Lab';
  static const tabProgress = 'Progreso';
  static const tabInstructor = 'Instructor';
  static const noApi = 'Sin conexión API';
  static const sendAttempt = 'Enviar intento';
  static const deliverPosttest = 'Entregar postest';
  static const goPosttest = 'Ir al postest (tabla nueva, sin ayuda)';
  static const goPosttestNoAI = 'Ir al postest (sin ayuda de IA)';
  static const chartDataTable = 'Ver datos como tabla';
  static const scrollHint = 'Desliza → para ver todas las columnas';
  static const legendTrain = 'Entrenamiento (línea continua)';
  static const legendVal = 'Validación (línea discontinua)';
  static const legendRef = 'Referencia (barra izquierda)';
  static const legendCur = 'Actual (barra derecha)';
  static const simulated = 'Curvas sintéticas (simulación)';
}

String? apiToken;
String? apiRole; // student|instructor (lo dice /auth/login y /auth/me)
String? apiUserId;

/// Notifica a GoRouter cuando cambia el estado de auth (login/logout).
final authRefresh = ValueNotifier<int>(0);

Map<String, String> _headers([bool json = false]) => {
      if (apiToken != null) 'Authorization': 'Bearer $apiToken',
      if (json) 'Content-Type': 'application/json',
    };

// Anuncia errores/estados a lectores de pantalla (WCAG 4.1.3).
class StatusText extends StatelessWidget {
  final String status;
  const StatusText(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(status),
      ),
    );
  }
}

Future<void> _persistAuth(String token, String userId, String role) async {
  apiToken = token;
  apiUserId = userId;
  apiRole = role;
  authRefresh.value++;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('apiToken', token);
  await prefs.setString('apiUserId', userId);
  await prefs.setString('apiRole', role);
}

Future<void> _restoreAuth() async {
  final prefs = await SharedPreferences.getInstance();
  apiToken = prefs.getString('apiToken');
  apiUserId = prefs.getString('apiUserId');
  apiRole = prefs.getString('apiRole');
}

Future<void> _clearAuth() async {
  apiToken = null;
  apiUserId = null;
  apiRole = null;
  authRefresh.value++;
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('apiToken');
  await prefs.remove('apiUserId');
  await prefs.remove('apiRole');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _restoreAuth();
  runApp(const CognitiveFlowApp());
}

final router = GoRouter(
  initialLocation: '/academy',
  refreshListenable: authRefresh,
  redirect: (context, state) {
    final logged = apiToken != null;
    final loggingIn = state.matchedLocation == '/login';
    if (!logged && !loggingIn) return '/login';
    if (logged && loggingIn) return '/academy';
    // Guardia de rol: instructor/* solo para instructor.
    if (state.matchedLocation.startsWith('/instructor') && apiRole == 'student') {
      return '/academy';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
    ShellRoute(
      builder: (c, s, child) => Shell(location: s.matchedLocation, child: child),
      routes: [
        GoRoute(path: '/academy', builder: (c, s) => const AcademyPage()),
        GoRoute(path: '/labs', builder: (c, s) => const LabsPage()),
        GoRoute(
          path: '/labs/:labId',
          builder: (c, s) {
            final extra = s.extra as Map? ?? {};
            final title = (extra['title'] ?? s.pathParameters['labId']!) as String;
            return switch (extra['lab_type']) {
              'data_detective' => DataLabPage(labId: s.pathParameters['labId']!, title: title),
              'model_monitoring' =>
                MonitorLabPage(labId: s.pathParameters['labId']!, title: title),
              _ => LabDetailPage(labId: s.pathParameters['labId']!, title: title),
            };
          },
        ),
        GoRoute(
          path: '/labs/:labId/posttest/:sid',
          builder: (c, s) => PosttestPage(
            labId: s.pathParameters['labId']!,
            sessionId: s.pathParameters['sid']!,
          ),
        ),
        GoRoute(path: '/progress', builder: (c, s) => const ProgressPage()),
        GoRoute(path: '/instructor', builder: (c, s) => const InstructorPage()),
        GoRoute(
          path: '/instructor/session/:sid',
          builder: (c, s) => SessionReviewPage(sessionId: s.pathParameters['sid']!),
        ),
      ],
    ),
  ],
);

class CognitiveFlowApp extends StatelessWidget {
  const CognitiveFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: Strings.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
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
      final body = jsonDecode(r.body) as Map;
      await _persistAuth(
        body['token'] as String,
        (body['user_id'] ?? userId.text.trim()) as String,
        (body['role'] ?? 'student') as String,
      );
      if (mounted) router.go('/academy');
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(Strings.loginHint),
                TextField(controller: userId, decoration: const InputDecoration(labelText: Strings.loginUserId), onSubmitted: (_) => _login()),
                const SizedBox(height: 12),
                FilledButton(onPressed: _login, child: const Text(Strings.loginEnter)),
                StatusText(status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _shellTabs = ['/academy', '/labs', '/progress', '/instructor'];

class Shell extends StatelessWidget {
  final String location;
  final Widget child;
  const Shell({super.key, required this.location, required this.child});

  int get _index {
    if (location.startsWith('/labs')) return 1;
    if (location.startsWith('/progress')) return 2;
    if (location.startsWith('/instructor')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        void go(int i) => router.go(_shellTabs[i]);
        final rail = NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: go,
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.school), label: Text(Strings.tabAcademy)),
            NavigationRailDestination(icon: Icon(Icons.science), label: Text(Strings.tabLabs)),
            NavigationRailDestination(icon: Icon(Icons.trending_up), label: Text(Strings.tabProgress)),
            NavigationRailDestination(icon: Icon(Icons.person), label: Text(Strings.tabInstructor)),
          ],
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: IconButton(
                  tooltip: 'Salir',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await _clearAuth();
                    router.go('/login');
                  },
                ),
              ),
            ),
          ),
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text(Strings.appTitle),
            actions: [
              if (!wide)
                IconButton(
                  tooltip: 'Salir',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await _clearAuth();
                    router.go('/login');
                  },
                ),
            ],
          ),
          body: wide
              ? Row(children: [rail, const VerticalDivider(width: 1), Expanded(child: child)])
              : child,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: go,
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.school), label: Strings.tabAcademy),
                    NavigationDestination(icon: Icon(Icons.science), label: Strings.tabLabs),
                    NavigationDestination(icon: Icon(Icons.trending_up), label: Strings.tabProgress),
                    NavigationDestination(icon: Icon(Icons.person), label: Strings.tabInstructor),
                  ],
                ),
        );
      },
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

class AcademyPage extends StatefulWidget {
  const AcademyPage({super.key});
  @override
  State<AcademyPage> createState() => _AcademyState();
}

class _AcademyState extends State<AcademyPage> {
  // ponytail: hoisted from build; recreating future per build refired GET on every setState.
  late final _future = fetchJson('/modules');
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Semantics(
              liveRegion: true,
              child: Text('${Strings.noApi}: ${s.error}'),
            ),
          );
        }
        final modules = s.data!;
        return ListView(
          children: [for (final m in modules) ListTile(title: Text(m['title']))],
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
  late final _future = fetchJson('/labs');
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Semantics(
              liveRegion: true,
              child: Text('${Strings.noApi}: ${s.error}'),
            ),
          );
        }
        final labs = s.data!;
        return ListView(
          children: [
            for (final l in labs)
              ListTile(
                title: Text(l['title']),
                subtitle: Text(l['lab_type']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => router.go(
                  '/labs/${l['id']}',
                  extra: {'lab_type': l['lab_type'], 'title': l['title']},
                ),
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
      // ponytail: student_id derived server-side from token (main.py:159); don't send it.
      final s = await postJson('/sessions', {
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
    if (justification.text.trim().isEmpty) {
      setState(() => status = 'La justificación es obligatoria');
      return;
    }
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

  final scrollCtrl = ScrollController();
  final hCtrl = ScrollController();

  @override
  void dispose() {
    justification.dispose();
    scrollCtrl.dispose();
    hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(posttestMode ? '${widget.title} (postest)' : widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(16),
            controller: scrollCtrl,
            children: [
              Text(posttestMode
                  ? 'Tabla nueva, sin ayuda. Marca anomalías y justifica.'
                  : 'Marca las filas con anomalías y justifica tu plan de limpieza.'),
              const SizedBox(height: 8),
              const Text(Strings.scrollHint, style: TextStyle(fontSize: 12)),
              Scrollbar(
                controller: hCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: hCtrl,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: true,
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
              ),
          TextField(
            controller: justification,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Justificación y plan de limpieza *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _send,
            child: Text(posttestMode ? Strings.deliverPosttest : Strings.sendAttempt),
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
              child: const Text(Strings.goPosttest),
            ),
          if (!posttestMode)
            ResultPanel(
              evalResult: evalResult,
              socraticQ: socraticQ,
              intervention: intervention,
              onNext: _next,
            ),
          StatusText(status),
            ],
          ),
        ),
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
      // ponytail: student_id derived server-side from token; don't send it.
      final s = await postJson('/sessions', {
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
    if (hypo.text.trim().isEmpty) {
      setState(() => status = 'La hipótesis es obligatoria');
      return;
    }
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
    final controls = [
      const Text('Predice el efecto de la complejidad y justifica por qué'),
      const SizedBox(height: 12),
      AccessibleCurveChart(train: train, val: val, label: 'Curvas de pérdida'),
      if (curve?['simulated'] == true)
        const Text(Strings.simulated, style: TextStyle(fontSize: 12)),
      Slider(
        value: complexity, min: 1, max: 10, divisions: 9,
        label: 'Complejidad ${complexity.round()}',
        onChanged: (v) => setState(() => complexity = v),
        onChangeEnd: (_) => _loadCurve(),
      ),
      Slider(
        value: noise, min: 0, max: 50, divisions: 10,
        label: 'Ruido ${noise.round()}%',
        onChanged: (v) => setState(() => noise = v),
        onChangeEnd: (_) => _loadCurve(),
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
      FilledButton(onPressed: _send, child: const Text(Strings.sendAttempt)),
    ];
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultPanel(
          evalResult: evalResult,
          socraticQ: socraticQ,
          intervention: intervention,
          onNext: _next,
        ),
        TextButton(
          onPressed: sessionId == null
              ? null
              : () => router.go('/labs/${widget.labId}/posttest/$sessionId'),
          child: const Text(Strings.goPosttestNoAI),
        ),
        StatusText(status),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1024) {
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
    if (answer.text.trim().isEmpty) {
      setState(() => status = 'El diagnóstico es obligatorio');
      return;
    }
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Variante nueva. Sin pistas ni tutor hasta entregar.'),
              const SizedBox(height: 12),
              AccessibleCurveChart(train: train, val: val, label: 'Curvas del postest'),
              Slider(
                value: complexity, min: 1, max: 10, divisions: 9,
                label: 'Complejidad ${complexity.round()}',
                onChanged: sent ? null : (v) => setState(() => complexity = v),
                onChangeEnd: sent ? null : (_) => _loadCurve(),
              ),
              Slider(
                value: noise, min: 0, max: 50, divisions: 10,
                label: 'Ruido ${noise.round()}%',
                onChanged: sent ? null : (v) => setState(() => noise = v),
                onChangeEnd: sent ? null : (_) => _loadCurve(),
              ),
              TextField(
                controller: answer, maxLines: 3, enabled: !sent,
                decoration: const InputDecoration(
                  labelText: 'Tu diagnóstico y justificación *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (!sent) FilledButton(onPressed: _sendPosttest, child: const Text(Strings.deliverPosttest)),
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
              StatusText(status),
            ],
          ),
        ),
      ),
    );
  }
}

/// Curva de entrenamiento (continua) vs validación (discontinua).
/// Colores desde el tema — nunca hard-coded — para modo claro/oscuro y
/// diferenciación por estilo además de color (WCAG 1.4.1).
class CurvePainter extends CustomPainter {
  final List<num> train;
  final List<num> val;
  final Color trainColor;
  final Color valColor;
  CurvePainter(this.train, this.val, {required this.trainColor, required this.valColor});

  Path _pathFor(List<num> ys, Size size) {
    final p = Path();
    for (var i = 0; i < ys.length; i++) {
      final x = size.width * i / (ys.length - 1);
      final y = size.height - (ys[i].toDouble().clamp(0, 1) * size.height);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p;
  }

  // Convierte un path en discontinuo (dash 6/4) para la serie de validación.
  Path _dashed(Path src) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        out.addPath(m.extractPath(d, d + 6), Offset.zero);
        d += 10;
      }
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (train.isEmpty) return;
    canvas.drawPath(
      _pathFor(train, size),
      Paint()..color = trainColor..strokeWidth = 2..style = PaintingStyle.stroke,
    );
    if (val.isNotEmpty) {
      canvas.drawPath(
        _dashed(_pathFor(val, size)),
        Paint()..color = valColor..strokeWidth = 2..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CurvePainter old) =>
      old.train != train || old.val != val ||
      old.trainColor != trainColor || old.valColor != valColor;
}

/// Gráfico de curvas con alternativa textual (WCAG 1.1.1) y leyenda sin
/// nombres de color.
class AccessibleCurveChart extends StatelessWidget {
  final List<num> train;
  final List<num> val;
  final String label;
  const AccessibleCurveChart({super.key, required this.train, required this.val, required this.label});

  String _summary(List<num> ys) {
    if (ys.isEmpty) return 'sin datos';
    final min = ys.reduce((a, b) => a < b ? a : b);
    final max = ys.reduce((a, b) => a > b ? a : b);
    return '${ys.length} puntos, mín ${min.toStringAsFixed(2)}, máx ${max.toStringAsFixed(2)}, '
        'último ${ys.last.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$label. Entrenamiento: ${_summary(train)}. Validación: ${_summary(val)}.',
          child: SizedBox(
            height: 180,
            child: CustomPaint(painter: CurvePainter(train, val, trainColor: cs.primary, valColor: cs.tertiary)),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 24, height: 3, color: cs.primary),
              const SizedBox(width: 6),
              const Text(Strings.legendTrain, style: TextStyle(fontSize: 12)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 24, height: 3, color: cs.tertiary),
              const SizedBox(width: 6),
              const Text(Strings.legendVal, style: TextStyle(fontSize: 12)),
            ]),
          ],
        ),
        ExpansionTile(
          title: const Text(Strings.chartDataTable, style: TextStyle(fontSize: 13)),
          tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('i')),
                  DataColumn(label: Text('entrenamiento')),
                  DataColumn(label: Text('validación')),
                ],
                rows: [
                  for (var i = 0; i < train.length; i++)
                    DataRow(cells: [
                      DataCell(Text('$i')),
                      DataCell(Text(train[i].toStringAsFixed(3))),
                      DataCell(Text(i < val.length ? val[i].toStringAsFixed(3) : '—')),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// E5: instructor revisa intentos con rúbrica propia (0-4 por criterio).
// ponytail: StudentSessionsPage eliminada; el diálogo de InstructorPage va
// directo a /instructor/session/:sid (una pantalla menos, mismo flujo).

const reviewCriteria = ['exactitud', 'evidencia', 'causal', 'alternativas', 'metacognicion'];

class SessionReviewPage extends StatefulWidget {
  final String sessionId;
  const SessionReviewPage({super.key, required this.sessionId});
  @override
  State<SessionReviewPage> createState() => _ReviewState();
}

class _ReviewState extends State<SessionReviewPage> {
  String status = '';
  late final _future = fetchJson('/sessions/${widget.sessionId}/attempts');

  Future<void> _send(String attemptId, Map<String, double> scores, String notes) async {
    try {
      await postJson('/instructor/attempts/$attemptId/reviews', {
        'rubric_scores': {for (final e in scores.entries) e.key: e.value.round()},
        'notes': notes,
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
        future: _future,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Center(
              child: Semantics(liveRegion: true, child: Text('Error: ${s.error}')),
            );
          }
          final attempts = s.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final a in attempts)
                AttemptReviewCard(
                  key: ValueKey(a['id']),
                  answer: '${a['answer']}',
                  onSave: (scores, notes) => _send(a['id'], scores, notes),
                ),
              StatusText(status),
            ],
          );
        },
      ),
    );
  }
}

// ponytail: per-attempt state; shared map+controller contaminated grades across cards.
class AttemptReviewCard extends StatefulWidget {
  final String answer;
  final void Function(Map<String, double> scores, String notes) onSave;
  const AttemptReviewCard({super.key, required this.answer, required this.onSave});
  @override
  State<AttemptReviewCard> createState() => _AttemptReviewCardState();
}

class _AttemptReviewCardState extends State<AttemptReviewCard> {
  late Map<String, double> scores;
  late TextEditingController notes;
  @override
  void initState() {
    super.initState();
    scores = {for (final c in reviewCriteria) c: 2.0};
    notes = TextEditingController();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.answer, style: const TextStyle(fontSize: 13)),
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
              onPressed: () => widget.onSave(scores, notes.text),
              child: const Text('Guardar revisión'),
            ),
          ],
        ),
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
      // ponytail: student_id derived server-side from token; don't send it.
      final s = await postJson('/sessions', {
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
    if (answer.text.trim().isEmpty) {
      setState(() => status = 'La hipótesis es obligatoria');
      return;
    }
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
    final controls = [
      Text(posttestMode
          ? 'Distribución nueva, sin ayuda. ¿Deriva? ¿Reentrenar o monitorear?'
          : '¿Qué feature deriva? Compara referencia vs actual y ubica el cambio.'),
      Semantics(
        label: '¿Qué feature deriva?',
        child: DropdownButton<String>(
          value: feats.containsKey(feature) ? feature : (feats.keys.firstOrNull as String? ?? feature),
          hint: const Text('¿Qué feature deriva?'),
          items: [
            for (final k in feats.keys.cast<String>())
              DropdownMenuItem(value: k, child: Text(k)),
            if (feats.isEmpty)
              DropdownMenuItem(value: feature, child: Text(feature)),
          ],
          onChanged: (v) => setState(() => feature = v ?? feature),
        ),
      ),
      AccessibleHistChart(ref: ref, cur: cur, label: 'Distribución $feature'),
      AccessibleCurveChart(train: series, val: const [], label: 'Serie temporal'),
      Slider(
        value: changepoint, min: 0, max: 179, divisions: 179,
        label: 'Cambio en t=${changepoint.round()}',
        onChanged: (v) => setState(() => changepoint = v),
      ),
      TextField(
        controller: answer, maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Hipótesis de deriva y decisión *',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _send,
        child: Text(posttestMode ? Strings.deliverPosttest : Strings.sendAttempt),
      ),
    ];
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            child: const Text(Strings.goPosttest),
          ),
        if (!posttestMode)
          ResultPanel(
            evalResult: evalResult,
            socraticQ: socraticQ,
            intervention: intervention,
            onNext: _next,
          ),
        StatusText(status),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(posttestMode ? '${widget.title} (postest)' : widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1024) {
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

class HistPainter extends CustomPainter {
  final List<num> ref;
  final List<num> cur;
  final Color refColor;
  final Color curColor;
  HistPainter(this.ref, this.cur, {required this.refColor, required this.curColor});
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
        Paint()..color = refColor,
      );
      canvas.drawRect(
        Rect.fromLTWH(i * bw + bw / 2, size.height - h2, bw / 2 - 1, h2),
        Paint()..color = curColor,
      );
    }
  }
  @override
  bool shouldRepaint(covariant HistPainter old) =>
      old.ref != ref || old.cur != cur || old.refColor != refColor || old.curColor != curColor;
}

/// Histograma referencia vs actual con alternativa textual y leyenda por
/// posición (izquierda/derecha), no por color.
class AccessibleHistChart extends StatelessWidget {
  final List<num> ref;
  final List<num> cur;
  final String label;
  const AccessibleHistChart({super.key, required this.ref, required this.cur, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$label. ${ref.length} barras. Referencia suma '
              '${ref.fold<num>(0, (a, b) => a + b).toStringAsFixed(2)}, '
              'actual ${cur.fold<num>(0, (a, b) => a + b).toStringAsFixed(2)}.',
          child: SizedBox(
            height: 120,
            child: CustomPaint(painter: HistPainter(ref, cur, refColor: cs.primary, curColor: cs.tertiary)),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 12, color: cs.primary),
              const SizedBox(width: 6),
              const Text(Strings.legendRef, style: TextStyle(fontSize: 12)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 12, color: cs.tertiary),
              const SizedBox(width: 6),
              const Text(Strings.legendCur, style: TextStyle(fontSize: 12)),
            ]),
          ],
        ),
        ExpansionTile(
          title: const Text(Strings.chartDataTable, style: TextStyle(fontSize: 13)),
          tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('bin')),
                  DataColumn(label: Text('referencia')),
                  DataColumn(label: Text('actual')),
                ],
                rows: [
                  for (var i = 0; i < ref.length; i++)
                    DataRow(cells: [
                      DataCell(Text('$i')),
                      DataCell(Text(ref[i].toStringAsFixed(3))),
                      DataCell(Text(i < cur.length ? cur[i].toStringAsFixed(3) : '—')),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ProgressPage extends StatelessWidget {  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Progreso por evidencias (siguiente slice)'));
  }
}

class InstructorPage extends StatefulWidget {
  const InstructorPage({super.key});
  @override
  State<InstructorPage> createState() => _InstructorState();
}

class _InstructorState extends State<InstructorPage> {
  late final _future = fetchJson('/instructor/students');
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Semantics(
              liveRegion: true,
              child: Text('${Strings.noApi}: ${s.error}'),
            ),
          );
        }
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
                onTap: () => showDialog(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text(st['display_name']),
                    content: _SessionsDialog(studentId: '${st['id']}'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ponytail: future hoisted to dialog state so rebuilds don't refetch.
class _SessionsDialog extends StatefulWidget {
  final String studentId;
  const _SessionsDialog({required this.studentId});
  @override
  State<_SessionsDialog> createState() => _SessionsDialogState();
}

class _SessionsDialogState extends State<_SessionsDialog> {
  late final _future = fetchJson('/instructor/students/${widget.studentId}/sessions');
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c2, s2) {
        if (!s2.hasData) return const LinearProgressIndicator();
        final sessions = s2.data!;
        if (sessions.isEmpty) return const Text('Sin sesiones');
        return SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final se in sessions)
                ListTile(
                  dense: true,
                  title: Text('${se['lab_template_id']} · ${se['status']}'),
                  onTap: () {
                    Navigator.pop(context);
                    router.go('/instructor/session/${se['id']}');
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
