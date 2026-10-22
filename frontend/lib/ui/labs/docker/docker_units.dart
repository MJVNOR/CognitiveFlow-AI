// Docker Academy: unidades implementadas (temario) y sus misiones en el
// Learning Studio. Cada unidad es una entrada propia del temario con su
// secuencia; D03, D05, D06 y D08–D12 siguen en backlog (sin lab interactivo).
import 'package:flutter/material.dart';

import '../workspace/mission_navigation.dart';

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

class DockerUnit {
  final String id;
  final String code;
  final String title;
  final String prompt;

  /// Unidad que conviene dominar antes (orientativo: el servidor aún no
  /// registra dominio por unidad).
  final String? requires;
  const DockerUnit(this.id, this.code, this.title, this.prompt, {this.requires});
}

const dockerUnits = [
  DockerUnit('M08-D01-containers', 'D01', 'Contenedor vs máquina virtual',
      'Tres escenarios: ¿contenedor o VM? Justifica cada uno.'),
  DockerUnit('M08-D02-lifecycle', 'D02', 'Imagen, contenedor y ciclo de vida',
      'Avanza el ciclo y predice qué sobrevive a cada paso.',
      requires: 'D01'),
  DockerUnit('M08-D04-dockerfile', 'D04', 'Dockerfile y capas',
      'Ordena las instrucciones y predice qué invalida la caché.',
      requires: 'D02'),
  DockerUnit('M08-D07-persistence', 'D07', 'Volúmenes y persistencia',
      'Predice qué archivos sobreviven con cada montaje.',
      requires: 'D02'),
];

DockerUnit dockerUnitById(String? id) =>
    dockerUnits.firstWhere((u) => u.id == id, orElse: () => dockerUnits.first);

const dockerMissions = [
  Mission('aprender', 'Aprende el concepto',
      'Lee la idea central y el ejemplo resuelto. Después la pondrás a prueba con escenarios.',
      Icons.menu_book_outlined),
  Mission('experimentar', 'Experimenta',
      'Manipula el experimento de la unidad. Tus decisiones quedan como evidencia.',
      Icons.science_outlined),
  Mission('justificar', 'Justifica tu decisión',
      'Explica lo que observaste y por qué: la evaluación mira tu razonamiento, no solo el resultado.',
      Icons.edit_note),
  Mission('nuevo', 'Resuelve un nuevo escenario',
      'El tutor eligió este reto a partir de tu evaluación. Resuélvelo en el área principal.',
      Icons.auto_awesome_outlined),
  Mission('dominio', 'Demuestra dominio',
      'Sin tutor ni pistas. Resuelve y justifica por tu cuenta.',
      Icons.verified_outlined),
];

const dkLearn = 0, dkExperiment = 1, dkJustify = 2, dkScenario = 3, dkMastery = 4;

const dockerHints = <String, List<String>>{
  'experimentar': [
    'Antes de decidir, pregúntate qué necesita compartir o aislar cada caso.',
    'Revisa el ejemplo resuelto de «Aprende el concepto»: ¿a cuál se parece este caso?',
    'Analogía: departamentos de un edificio (contenedores) frente a casas separadas (VMs).',
  ],
  'justificar': [
    'Cita lo que hiciste en el experimento: qué elegiste y qué pasó.',
    'Nombra el mecanismo: kernel, capa, volumen o ciclo de vida, según la unidad.',
    'Estructura útil: Hice → Observé → Porque → En otro caso haría…',
  ],
  'nuevo': [
    'Relee la pregunta del tutor: pide la distinción que antes faltó.',
  ],
};

String dockerCoach(String mission, {bool interacted = false, bool submitted = false}) =>
    switch (mission) {
      'aprender' => 'Fíjate en los errores comunes: el experimento los pone a prueba.',
      'experimentar' when interacted => 'Ya hay evidencia registrada. ¿Puedes explicar por qué funcionó así?',
      'experimentar' => 'Empieza por el caso que te parezca más claro y deja el dudoso para el final.',
      'justificar' when submitted =>
        'Lee qué hiciste bien y qué evidencia falta; después explora el nuevo desafío.',
      'justificar' => 'Explica el mecanismo, no solo la respuesta.',
      'nuevo' => 'Este reto se eligió con tu evaluación: busca la distinción que faltó.',
      _ => 'Cuando empieces la prueba, el tutor se apaga.',
    };
