import 'package:flutter_test/flutter_test.dart';
import 'package:cognitiveflow/ui/labs/docker/docker_units.dart';

void main() {
  test('las 12 unidades tienen ayuda gradual hasta un ejemplo distinto', () {
    for (final unit in dockerUnits) {
      final hints = dockerHintsFor(unit.id, 'experimentar');
      expect(hints.length, 4, reason: unit.code);
      expect(hints.toSet().length, 4, reason: unit.code);
      expect(hints.last, startsWith('Ejemplo distinto:'), reason: unit.code);
      expect(dockerHintsFor(unit.id, 'nuevo'), hints);
      for (final phase in ['aprender', 'justificar', 'dominio']) {
        expect(dockerHintsFor(unit.id, phase), isEmpty, reason: '${unit.code}: $phase');
      }
    }
    expect(dockerHintsFor(null, 'nuevo'), isEmpty);
    expect(dockerHintsFor('unidad-inventada', 'experimentar'), isEmpty);
  });

  test('D02 orienta hacia el paso preguntado; D06 hacia el lugar de la petición', () {
    final lifecycle = dockerHintsFor('M08-D02-lifecycle', 'experimentar');
    expect(lifecycle.first, contains('paso señalado'));
    expect(lifecycle[1], contains('corriendo o detenido'));
    expect(lifecycle.last, contains('docker create'));
    expect(dockerHintsFor('M08-D06-network', 'experimentar').first, contains('navegador'));
    expect(dockerCoach('nuevo', unitId: 'M08-D02-lifecycle'), contains('Imagen, contenedor'));
    expect(dockerCoach('nuevo', unitId: 'M08-D02-lifecycle'), isNot(contains('faltó')));
  });

  test('el reto usa su unidad explícita; un widget compartido sin unidad no se adivina', () {
    expect(dockerInterventionUnit({
      'widget_type': 'DecisionScenarios',
      'widget_parameters': {'parameters': {'unit': 'M08-D05-context'}},
    }), 'M08-D05-context');
    expect(dockerInterventionUnit({'widget_type': 'DecisionScenarios'}), isNull);
    expect(dockerInterventionUnit({'widget_type': 'DockerfileWorkbench'}), 'M08-D04-dockerfile');
    expect(dockerInterventionUnit(null), isNull);
  });
}
