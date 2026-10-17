// Unit tests de ViewModels (MVVM): red simulada vía ApiClient fake.
// Sin backend, sin SharedPreferences reales.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cognitiveflow/core/auth/auth_state.dart';
import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/data/services/api_client.dart';
import 'package:cognitiveflow/ui/auth/view_models/login_viewmodel.dart';
import 'package:cognitiveflow/ui/labs/view_models/lab_session_viewmodel.dart';

class FakeApi extends ApiClient {
  FakeApi() : super(baseUrl: 'http://fake');

  @override
  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    if (path == '/auth/login') {
      if (body['user_id'] == 's1') {
        return {'token': 'tok', 'user_id': 's1', 'role': 'student'};
      }
      throw Exception('401 usuario desconocido');
    }
    if (path == '/sessions') return {'id': 'sess-1'};
    if (path == '/sessions/sess-1/attempts') return {'id': 'att-1'};
    if (path == '/sessions/sess-1/evaluate') {
      return {
        'evaluator': 'mock',
        'status': 'evaluated',
        'criteria': [
          {'id': 'exactitud', 'score': 2},
        ],
      };
    }
    if (path == '/sessions/sess-1/socratic') {
      return {
        'question': '¿Por qué?',
        'feedback': {'texto': 'bien'},
      };
    }
    if (path == '/sessions/sess-1/next-intervention') {
      return {
        'widget_type': 'SocraticQuestionCard',
        'widget_parameters': {'title': 'T'},
      };
    }
    if (path == '/sessions/sess-9/reflection') {
      return {
        'summary': {'mejora': 'evidencia', 'desafio': null},
      };
    }
    if (path == '/sessions/sess-9/posttest') return {'seed': 7};
    throw Exception('404 $path');
  }

  @override
  Future<List<dynamic>> getList(String path) async {
    if (path == '/sessions/sess-1/tutor-history') {
      return [
        {'question': 'q1', 'provider': 'mock'},
      ];
    }
    if (path == '/me/sessions?lab_template_id=lab-x') {
      return [
        {'id': 'sess-9', 'status': 'active'},
      ];
    }
    if (path == '/sessions/sess-9/attempts') return [];
    if (path == '/sessions/sess-9/tutor-history') return [];
    if (path == '/sessions/sess-9/interventions') return [];
    throw Exception('404 $path');
  }

  @override
  Future<Map<String, dynamic>> getMap(String path) async {
    if (path == '/sessions/sess-9') {
      return {
        'status': 'active',
        'level': 'guided_practice',
        'assistance': {'hints': 1, 'interventions': 0},
      };
    }
    throw Exception('404 $path');
  }
}

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(FakeApi())],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LoginViewModel', () {
    test('login ok guarda auth y navega la página', () async {
      final c = _container();
      final creds =
          await c.read(loginViewModelProvider.notifier).login('s1');
      expect(creds, isNotNull);
      expect(c.read(loginViewModelProvider).busy, isFalse);
      expect(c.read(authProvider)?.userId, 's1');
    });

    test('usuario desconocido mapea mensaje', () async {
      final c = _container();
      final creds =
          await c.read(loginViewModelProvider.notifier).login('zzz');
      expect(creds, isNull);
      expect(c.read(loginViewModelProvider).status, contains('desconocido'));
    });

    test('vacío pide user_id sin llamar red', () async {
      final c = _container();
      final creds = await c.read(loginViewModelProvider.notifier).login('  ');
      expect(creds, isNull);
      expect(c.read(loginViewModelProvider).status, contains('user_id'));
    });
  });

  group('LabSessionViewModel', () {
    test('init crea sesión', () async {
      final c = _container();
      final vm = c.read(labSessionProvider('lab-x').notifier);
      await vm.init('lab-x');
      expect(c.read(labSessionProvider('lab-x')).sessionId, 'sess-1');
    });

    test('resume restaura abierta sin evaluar', () async {
      final c = _container();
      final vm = c.read(labSessionProvider('lab-x').notifier);
      expect(await vm.resume('lab-x'), isTrue);
      final s = c.read(labSessionProvider('lab-x'));
      expect(s.sessionId, 'sess-9');
      expect(s.level, 'guided_practice');
      expect(s.assistance, {'hints': 1, 'interventions': 0});
      expect(s.evalResult, isNull);
    });

    test('send + evaluate guarda evidencia y pregunta', () async {
      final c = _container();
      final vm = c.read(labSessionProvider('lab-x').notifier);
      await vm.init('lab-x');
      await vm.send({'answer_text': 'h'}, posttest: false);
      await vm.evaluate();
      final s = c.read(labSessionProvider('lab-x'));
      expect(s.attemptId, 'att-1');
      expect(s.evalResult?['status'], 'evaluated');
      expect(s.socraticQ, '¿Por qué?');
      expect(s.feedback?['texto'], 'bien');
      expect(s.tutorHistory, hasLength(1));
      expect(s.step, 1);
    });

    test('next trae intervención (paso 2)', () async {
      final c = _container();
      final vm = c.read(labSessionProvider('lab-x').notifier);
      await vm.init('lab-x');
      await vm.send({'answer_text': 'h'}, posttest: false);
      await vm.evaluate();
      await vm.next();
      final s = c.read(labSessionProvider('lab-x'));
      expect(s.intervention?['widget_type'], 'SocraticQuestionCard');
      expect(s.step, 2);
    });

    test('reflect cierra y beginPosttest fija variante', () async {
      final c = _container();
      final vm = c.read(labSessionProvider('lab-x').notifier);
      expect(await vm.resume('lab-x'), isTrue);
      await vm.reflect('aprendí');
      expect(c.read(labSessionProvider('lab-x')).done, isTrue);
      expect(await vm.beginPosttest(), isTrue);
      expect(
          c.read(labSessionProvider('lab-x')).posttestVariant?['seed'], 7);
    });
  });
}
