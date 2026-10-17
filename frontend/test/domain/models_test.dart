import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/domain/models/models.dart';

void main() {
  test('parseLabs mapea el shape de GET /labs', () {
    final labs = parseLabs([
      {
        'id': 'lab-ml',
        'title': 'ML',
        'lab_type': 'ml_experiment',
        'description': 'd',
        'order_index': 1,
        'module_id': 'm1',
      }
    ]);
    expect(labs.single.labType, 'ml_experiment');
    expect(labs.single.moduleId, 'm1');
    expect(labs.single.toJson()['lab_type'], 'ml_experiment');
  });

  test('parseStudents/Sessions/Attempts mapean sus endpoints', () {
    expect(parseStudents([{'id': 's1', 'display_name': 's1'}]).single.displayName, 's1');
    expect(
      parseSessions([
        {'id': 'x', 'lab_template_id': 'lab-ml', 'status': 'active'}
      ]).single.labTemplateId,
      'lab-ml',
    );
    expect(
      parseAttempts([
        {'id': 'a', 'answer': 'r', 'input': {'k': 1}}
      ]).single.answer,
      'r',
    );
  });
}
