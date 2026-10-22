// Misiones del lab de curvas de aprendizaje (ML). 1–3 son pasos locales
// previos al envío; 4 y 5 las habilita el servidor (ver studio_stages.dart).
import 'package:flutter/material.dart';

import '../workspace/mission_navigation.dart';

const mlMissions = [
  Mission('predecir', 'Predice antes de experimentar',
      'Antes de mover nada: ¿qué crees que pasará con el error de validación si el modelo se vuelve más complejo? Escribe tu predicción.',
      Icons.lightbulb_outline),
  Mission('experimentar', 'Experimenta con las curvas',
      'Mueve complejidad y ruido, guarda una corrida para comparar y marca la época donde la validación se despega del entrenamiento.',
      Icons.science_outlined),
  Mission('justificar', 'Justifica con evidencia',
      'Contrasta tu predicción con lo que observaste y explica la causa citando las dos curvas.',
      Icons.edit_note),
  Mission('nuevo', 'Resuelve un nuevo escenario',
      'El tutor eligió este reto a partir de tu evaluación. Resuélvelo en el área principal.',
      Icons.auto_awesome_outlined),
  Mission('dominio', 'Demuestra dominio',
      'Curvas nuevas que no has visto, sin tutor ni pistas. Diagnostica y justifica por tu cuenta.',
      Icons.verified_outlined),
];

const mlPredict = 0, mlExperiment = 1, mlJustify = 2, mlScenario = 3, mlMastery = 4;

/// Pistas graduadas: estrategia → evidencia señalada → analogía. Ninguna da la respuesta.
const mlHints = <String, List<String>>{
  'predecir': [
    'Piensa en dos errores: el que el modelo comete con lo que ya vio y el que comete con datos nuevos.',
    'Un modelo con más parámetros puede ajustarse a detalles que no se repiten fuera del entrenamiento.',
    'Analogía: memorizar las respuestas de un examen de práctica no garantiza aprobar uno distinto.',
  ],
  'experimentar': [
    'Cambia un solo control a la vez y guarda la corrida para compararla con la siguiente.',
    'Mira en qué época la curva de validación deja de bajar mientras la de entrenamiento sigue bajando.',
    'Sube el ruido y repite: ¿la separación aparece antes o después?',
  ],
  'justificar': [
    'Cita las dos curvas: qué hace cada una y desde qué época.',
    'Di si tu predicción se confirmó, cambió o faltó algo.',
    'Estructura útil: Predije → Observé (época, curvas) → Causa → Qué haría.',
  ],
  'nuevo': [
    'Relee la pregunta del tutor: pide una evidencia distinta a la que usaste.',
    'Apóyate en la época que marcaste y en la corrida guardada.',
  ],
};

/// Voz del tutor «en este paso»: reacciona a lo que el estudiante hace.
String mlCoach(String mission, {int? markedEpoch, bool savedRun = false, bool submitted = false}) =>
    switch (mission) {
      'predecir' => 'Todavía no mires las curvas: una predicción vale más si la escribes antes.',
      'experimentar' when markedEpoch != null =>
        'Marcaste la época $markedEpoch. ¿Se mantiene si cambias el ruido?',
      'experimentar' when savedRun =>
        'Tienes una corrida guardada: compara su validación con la actual.',
      'experimentar' => 'Sube la complejidad poco a poco y observa cuándo se separan las curvas.',
      'justificar' when submitted =>
        'Lee qué hiciste bien y qué evidencia falta; después explora el nuevo desafío.',
      'justificar' => 'Tu explicación debe convencer a alguien que no vio las curvas.',
      'nuevo' => 'Este reto se eligió con tu evaluación: busca la evidencia que antes faltó.',
      _ => 'Cuando empieces la prueba, el tutor se apaga.',
    };
