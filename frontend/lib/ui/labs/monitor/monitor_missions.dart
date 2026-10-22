// Misiones del lab de monitoreo de deriva. 1–3 son pasos locales previos al
// envío; 4 y 5 las habilita el servidor (ver studio_stages.dart).
import 'package:flutter/material.dart';

import '../workspace/mission_navigation.dart';

const monitorMissions = [
  Mission('observar', 'Observa y predice',
      'Mira la serie del sensor en producción. Antes de comparar distribuciones: ¿qué cambió, cuándo, y crees que el modelo empeoró?',
      Icons.visibility_outlined),
  Mission('comparar', 'Compara distribuciones',
      'Compara referencia y actual por feature, ubica el punto de cambio y marca la evidencia que sostiene tu diagnóstico.',
      Icons.stacked_bar_chart),
  Mission('decidir', 'Diagnostica y decide',
      'Explica qué tipo de cambio es y decide: monitorear, investigar o reentrenar. Distingue cambio en la entrada de caída de precisión.',
      Icons.rule),
  Mission('nuevo', 'Resuelve un nuevo escenario',
      'El tutor eligió este reto a partir de tu evaluación. Resuélvelo en el área principal.',
      Icons.auto_awesome_outlined),
  Mission('dominio', 'Demuestra dominio',
      'Una distribución nueva, sin tutor ni pistas. Diagnostica y decide por tu cuenta.',
      Icons.verified_outlined),
];

const monObserve = 0, monCompare = 1, monDecide = 2, monScenario = 3, monMastery = 4;

const monitorHints = <String, List<String>>{
  'observar': [
    'Busca un tramo donde la serie cambie de nivel y se quede ahí, no un pico aislado.',
    'Separa dos preguntas: ¿cambiaron los datos de entrada? ¿empeoró el modelo? Son distintas.',
    'Analogía: si cambia el clima, el termómetro marca distinto aunque funcione bien.',
  ],
  'comparar': [
    'Compara la forma y el centro de ambas distribuciones, no solo un bin.',
    'Revisa más de una feature: puede que solo una haya derivado.',
    'Mueve el punto de cambio hasta donde la serie se separa y guárdalo como evidencia.',
  ],
  'decidir': [
    'Sin etiquetas nuevas no puedes afirmar que la precisión cayó: dilo explícitamente.',
    'Justifica la acción con la evidencia: feature, magnitud del cambio y momento.',
    'Estructura útil: Qué cambió → Desde cuándo → Qué no sé aún → Qué haría y por qué.',
  ],
  'nuevo': [
    'Relee la pregunta del tutor: pide distinguir dos situaciones que se parecen.',
    'Apóyate en la feature y el punto de cambio que marcaste.',
  ],
};

String monitorCoach(String mission,
        {String? feature, int? changepoint, bool submitted = false}) =>
    switch (mission) {
      'observar' => 'Describe lo que ves en la serie antes de abrir los histogramas.',
      'comparar' when changepoint != null =>
        'Marcaste $feature desde t=$changepoint. ¿Las otras features cambian igual?',
      'comparar' => 'Elige una feature y compara referencia contra actual.',
      'decidir' when submitted =>
        'Lee qué hiciste bien y qué evidencia falta; después explora el nuevo desafío.',
      'decidir' => 'Decide una acción y di qué evidencia la justifica y qué no sabes aún.',
      'nuevo' => 'Este reto se eligió con tu evaluación: busca la distinción que faltó.',
      _ => 'Cuando empieces la prueba, el tutor se apaga.',
    };
