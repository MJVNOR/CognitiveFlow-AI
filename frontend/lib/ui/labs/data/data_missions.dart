// Misiones de Data Detective y su estado. Las misiones 1–4 son pasos locales
// previos al envío (no autorizan nada); 5 existe solo si el servidor emitió
// una intervención y 6 solo si el servidor declara `can_enter_posttest`.
import 'package:flutter/material.dart';

import '../view_models/lab_session.dart';
import '../workspace/mission_navigation.dart';
import '../workspace/studio_stages.dart';

export '../workspace/studio_stages.dart' show inPosttestPhase;

const dataMissions = [
  Mission('explorar', 'Explora los datos',
      'Recorre la línea de inspección: toca sensores y piezas para ver de dónde sale cada columna. Luego escribe qué problemas sospechas.',
      Icons.travel_explore),
  Mission('detectar', 'Detecta anomalías',
      'Abre las filas sospechosas y di qué tipo de problema ves. Si una fila está bien, déjala sin marcar.',
      Icons.flag_outlined),
  Mission('explicar', 'Explica tu decisión',
      'Revisa tu evidencia y explica por qué cada fila es un problema y qué lo causó.',
      Icons.edit_note),
  Mission('limpiar', 'Limpia y verifica',
      'Elige qué hacer con cada fila marcada y comprueba cómo queda la tabla antes de entrenar.',
      Icons.cleaning_services_outlined),
  Mission('nuevo', 'Resuelve un nuevo escenario',
      'El tutor eligió este reto a partir de tu evaluación. Resuélvelo en el área principal.',
      Icons.auto_awesome_outlined),
  Mission('dominio', 'Demuestra dominio',
      'Tabla nueva, sin tutor ni pistas. Detecta, clasifica y justifica por tu cuenta.',
      Icons.verified_outlined),
];

const missionExplore = 0,
    missionDetect = 1,
    missionExplain = 2,
    missionClean = 3,
    missionScenario = 4,
    missionMastery = 5;

List<MissionView> dataMissionViews(
  LabSession lab, {
  required int localMax,
  required bool scenarioDone,
  required int selected,
}) =>
    studioMissionViews(dataMissions, lab,
        localMax: localMax, scenarioDone: scenarioDone, selected: selected);

int dataDefaultMission(LabSession lab, int localMax) =>
    studioDefaultMission(dataMissions, lab, localMax);

/// Pistas graduadas por misión: estrategia → evidencia señalada → analogía.
/// Ninguna nombra filas concretas (no resuelven la tarea).
const dataHints = <String, List<String>>{
  'explorar': [
    'Toca el sensor de temperatura y observa qué columnas se iluminan: una lectura necesita un valor y su unidad.',
    'Ordena una columna numérica tocando su encabezado: los valores extremos quedan arriba o abajo.',
    'Analogía: en un registro de básculas, un peso negativo no es «poco peso», es un fallo de medición.',
  ],
  'detectar': [
    'Hay más de un tipo de problema y no todos están en la misma columna.',
    'Compara filas que se parecen demasiado entre sí y revisa la columna de unidad.',
    'Analogía: dos tickets con la misma hora, monto y caja suelen ser el mismo ticket registrado dos veces.',
  ],
  'explicar': [
    'Cita filas concretas: «la fila N muestra… por eso…».',
    'Para cada tipo, explica la causa probable: sensor, registro o conversión.',
    'Estructura útil: Observo → Causa probable → Qué haría → Qué no haría.',
  ],
  'limpiar': [
    'No toda anomalía se elimina: algunas se reparan sin perder la fila.',
    'Pregúntate si el valor original se puede recuperar con otra columna de la misma fila.',
    'Analogía: un precio en dólares mezclado con pesos se convierte; un precio vacío se imputa o se revisa.',
  ],
  'nuevo': [
    'Relee la pregunta del tutor: pide distinguir dos causas distintas.',
    'Apóyate en filas que ya inspeccionaste: cita su valor y su unidad.',
  ],
};

/// Tipos de anomalía (claves del backend `_true_row_type`).
const anomalyTypeLabels = {
  'sin_anomalia': 'Sin anomalía',
  'missing': 'Faltante',
  'duplicate': 'Duplicado',
  'unit': 'Unidad mezclada',
  'outlier': 'Imposible físico',
  'leak': 'Fuga de futuro',
};

const cleaningActionLabels = {
  'revisar': 'Revisar',
  'imputar': 'Imputar media',
  'convertir': 'Convertir a °C',
  'eliminar': 'Eliminar fila',
};

/// Sentido físico de cada columna (tooltips + inspector + escena).
const columnInfo = {
  'id': 'Número de pieza inspeccionada (orden de paso por la línea).',
  'temp': 'Temperatura medida por el sensor T1. Su unidad está en la columna unit.',
  'unit': 'Unidad con la que T1 registró la temperatura (C o F).',
  'pressure': 'Presión del sensor P1 en kPa. Rango normal de la línea: 100–110.',
  'line': 'Línea de producción por la que pasó la pieza (A o B).',
};

/// Sensor de la escena ↔ columnas de la tabla.
const sensorColumns = {
  'temp': ['temp', 'unit'],
  'pressure': ['pressure'],
};

String? sensorForColumn(String col) => switch (col) {
      'temp' || 'unit' => 'temp',
      'pressure' => 'pressure',
      _ => null,
    };

/// Voz del tutor «en este paso»: reacciona a lo que el estudiante está
/// mirando, sin repetir el objetivo de la misión ni dar la respuesta.
String dataCoach(
  String mission, {
  int? selectedRow,
  String? focusSensor,
  int flagged = 0,
  bool submitted = false,
}) =>
    switch (mission) {
      'explorar' when selectedRow != null =>
        'Estás viendo la pieza $selectedRow. Compara sus lecturas con la mediana: ¿qué te llama la atención?',
      'explorar' when focusSensor != null =>
        'El sensor ${focusSensor == 'temp' ? 'T1 alimenta temp y unit' : 'P1 alimenta pressure'}. '
            'Ordena esa columna para ver sus extremos.',
      'explorar' =>
        'Empieza por un sensor: tócalo y mira qué columnas del registro se iluminan.',
      'detectar' when flagged == 0 =>
        'Abre una fila sospechosa y elige el tipo de problema. Una fila puede verse rara y aun así estar bien.',
      'detectar' =>
        '$flagged ${flagged == 1 ? 'fila marcada' : 'filas marcadas'}. ¿Hay algún tipo de problema que todavía no buscaste?',
      'explicar' =>
        'Tu explicación debe convencer a alguien que no vio la tabla: cita filas y causas.',
      'limpiar' when submitted =>
        'Lee qué hiciste bien y qué evidencia falta; después explora el nuevo desafío.',
      'limpiar' => 'Decide qué hacer con cada fila. Eliminar es una opción, no la única.',
      'nuevo' =>
        'Este reto se eligió con tu evaluación: busca la diferencia que antes se te escapó.',
      _ => 'Cuando empieces la prueba, el tutor se apaga.',
    };
