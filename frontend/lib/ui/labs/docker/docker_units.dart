// Docker Academy: las 12 unidades del temario y sus misiones en el Learning
// Studio. Cada unidad es una entrada propia con su secuencia. D01/D02/D04/D07
// tienen su experimento propio; el resto usa DecisionScenarios (casos del
// servidor, `labs_docker.DECISION_UNITS`).
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
      'M08-D03-cli' => (widget: 'DecisionScenarios', title: 'Elige el comando'),
      'M08-D05-context' ||
      'M08-D06-network' ||
      'M08-D08-compose' ||
      'M08-D09-debug' ||
      'M08-D10-security' ||
      'M08-D11-deploy' =>
        (widget: 'DecisionScenarios', title: 'Decide en cada caso'),
      'M08-D12-capstone' => (widget: 'DecisionScenarios', title: 'Incidente integrador'),
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
      'Predice qué recursos existirán tras el paso señalado y compruébalo en la simulación.',
      requires: 'D01'),
  DockerUnit('M08-D03-cli', 'D03', 'Comandos de Docker (CLI)',
      'Elige el comando correcto para cada situación, sin adivinar flags.',
      requires: 'D02'),
  DockerUnit('M08-D04-dockerfile', 'D04', 'Dockerfile y capas',
      'Ordena las instrucciones para construir la app y conservar la caché al cambiar el código.',
      requires: 'D02'),
  DockerUnit('M08-D05-context', 'D05', 'Contexto de build y .dockerignore',
      'Decide qué ve COPY y qué no debe entrar en la imagen.',
      requires: 'D04'),
  DockerUnit('M08-D06-network', 'D06', 'Redes y puertos',
      'Conecta servicios sin confundir localhost con el nombre del servicio.',
      requires: 'D03'),
  DockerUnit('M08-D07-persistence', 'D07', 'Volúmenes y persistencia',
      'Predice qué archivos sobreviven con cada montaje.',
      requires: 'D02'),
  DockerUnit('M08-D08-compose', 'D08', 'Docker Compose',
      'Elige la clave de compose que resuelve cada necesidad del stack.',
      requires: 'D06'),
  DockerUnit('M08-D09-debug', 'D09', 'Depuración con evidencia',
      'Diagnostica cada fallo leyendo la evidencia antes de cambiar nada.',
      requires: 'D08'),
  DockerUnit('M08-D10-security', 'D10', 'Seguridad e imágenes mínimas',
      'Detecta el riesgo de cada decisión y elige la alternativa segura.',
      requires: 'D05'),
  DockerUnit('M08-D11-deploy', 'D11', 'Despliegue y rollback',
      'Decide cómo publicar, configurar y volver atrás sin perder datos.',
      requires: 'D09'),
  DockerUnit('M08-D12-capstone', 'D12', 'Reto final: decisiones de despliegue',
      'Resuelve y justifica cuatro decisiones de unidades distintas.',
      requires: 'D11'),
];

DockerUnit dockerUnitById(String? id) =>
    dockerUnits.firstWhere((u) => u.id == id, orElse: () => dockerUnits.first);

/// Estado del lab Docker completo a partir de sus unidades: `done` solo con las
/// 12; `active` si hay alguna hecha o una sesión abierta; null si nada empezó.
String? dockerLabStatus(Map unitStatus, String? sessionStatus) {
  final done = dockerUnits.where((u) => unitStatus[u.id] == 'done').length;
  if (done == dockerUnits.length) return 'done';
  if (done > 0 || (sessionStatus != null && sessionStatus != 'done')) return 'active';
  return null;
}

/// Unidades completadas (para «x/12» en la academia).
int dockerUnitsDone(Map unitStatus) =>
    dockerUnits.where((u) => unitStatus[u.id] == 'done').length;

/// Código de la unidad que falta completar para abrir [u] (null = disponible).
/// Espejo de backend `labs_docker.PREREQ`: el servidor rechaza intentos igual.
/// Una unidad ya empezada nunca se bloquea.
String? dockerLockedBy(DockerUnit u, Map status) {
  final req = u.requires;
  if (req == null || status[u.id] != null) return null;
  final reqId = dockerUnits.firstWhere((x) => x.code == req).id;
  return status[reqId] == 'done' ? null : req;
}

const dockerMissions = [
  Mission('aprender', 'Aprende el concepto',
      'Lee la idea central y el ejemplo resuelto. Después la pondrás a prueba con escenarios.',
      Icons.menu_book_outlined),
  Mission('experimentar', 'Experimenta y justifica',
      'Decide en el experimento y explica por qué ahí mismo: decisiones y razones son tu evidencia.',
      Icons.science_outlined),
  Mission('justificar', 'Revisa tu evaluación',
      'Lee qué hiciste bien y qué evidencia faltó; después el tutor elige un reto nuevo.',
      Icons.fact_check_outlined),
  Mission('nuevo', 'Resuelve un nuevo escenario',
      'El tutor eligió este reto a partir de tu evaluación. Resuélvelo en el área principal.',
      Icons.auto_awesome_outlined),
  Mission('dominio', 'Demuestra dominio',
      'Sin tutor ni pistas. Resuelve y justifica por tu cuenta.',
      Icons.verified_outlined),
];

const dkLearn = 0, dkExperiment = 1, dkJustify = 2, dkScenario = 3, dkMastery = 4;

// Cuatro niveles: orientar → mirar evidencia → contrastar → explicar con un
// ejemplo distinto. Mismo apoyo en práctica y reto; nunca durante la prueba.
const _dockerUnitHints = <String, List<String>>{
  'M08-D01-containers': [
    'Subraya el requisito que no puedes cambiar: compatibilidad del kernel, aislamiento o coste de arrancar muchas copias.',
    'Busca si el caso exige otro kernel o solo empaquetar y aislar una aplicación compatible con el host.',
    'Compara compartir el kernel del host con arrancar un sistema invitado. ¿Qué requisito cumple cada opción y qué coste añade?',
    'Ejemplo distinto: probar un parche del kernel en un sistema invitado requiere virtualizar ese sistema. Aislar un proceso Linux compatible puede hacerse compartiendo el kernel. Justifica con el requisito de tu caso, no con «es más rápido».',
  ],
  'M08-D02-lifecycle': [
    'Localiza el paso señalado. La pregunta pide qué recursos existen justo después de ese paso, no al final de toda la secuencia.',
    'Lleva dos registros separados: imagen y contenedor. Anota también si el contenedor está corriendo o detenido.',
    'Compara crear, detener, volver a iniciar y eliminar. Revisa si aparece --rm: cambia lo que ocurre al terminar el proceso.',
    'Ejemplo distinto: docker create a partir de una imagen local crea un contenedor detenido; ambos recursos existen. docker start inicia esa misma instancia. Estar detenido no significa haber sido eliminado. Aplica esa distinción a los comandos de tu secuencia.',
  ],
  'M08-D03-cli': [
    'Identifica la acción pedida: listar recursos, leer mensajes, inspeccionar configuración o abrir un proceso.',
    'Comprueba qué recurso recibe el comando: una imagen, un contenedor existente o un servicio.',
    'Compara observar un contenedor existente con crear otro. Un comando que arranca una instancia nueva no inspecciona la anterior.',
    'Ejemplo distinto: para copiar un informe del contenedor a tu equipo, docker cp mueve el archivo sin crear otro contenedor ni abrir una shell. Primero define la acción; después busca el comando que la realiza.',
  ],
  'M08-D04-dockerfile': [
    'Antes de mover bloques, identifica qué archivo o directorio necesita cada instrucción.',
    'Imagina que solo cambias un archivo de código: señala qué trabajo debería poder reutilizarse de la construcción anterior.',
    'Contrasta copiar todo antes de instalar dependencias con separar el archivo de dependencias del código. ¿Qué cambio invalida cada capa?',
    'Ejemplo distinto: en una app Go se pueden copiar go.mod y go.sum y descargar dependencias antes de copiar el código. Así un cambio del código no obliga a descargarlas otra vez. CMD describe el arranque; en este ejercicio se coloca al final como convención.',
  ],
  'M08-D05-context': [
    'Encuentra el último argumento de docker build: define el contexto local que se envía al constructor.',
    'Ubica el archivo solicitado dentro o fuera de ese contexto y revisa si .dockerignore lo excluye.',
    'Separa la ruta origen de COPY, relativa al contexto, de la ruta destino, dentro de la imagen. WORKDIR no amplía el contexto.',
    'Ejemplo distinto: con contexto ./web y WORKDIR /srv, COPY assets/ ./assets/ toma web/assets del host y lo deja en /srv/assets de la imagen. No puede recuperar una carpeta hermana fuera del contexto mediante ../.',
  ],
  'M08-D06-network': [
    'Ubica dónde se ejecuta el cliente: navegador, host o proceso dentro de un contenedor.',
    'Separa dirección de destino, puerto del host, puerto del contenedor y red compartida.',
    'Compara una petición entre contenedores con una petición desde tu navegador. No usan necesariamente la misma dirección.',
    'Ejemplo distinto: un worker y un broker en la misma red Compose pueden comunicarse por broker:5672. Un navegador fuera de esa red no conoce ese DNS interno y usa una URL publicada o un proxy. localhost apunta al entorno desde el que se hace la petición.',
  ],
  'M08-D07-persistence': [
    'Identifica dónde se escribe el archivo y qué se elimina exactamente al recrear el contenedor.',
    'Dibuja por separado contenedor, imagen y almacenamiento montado. Marca en cuál vive el archivo.',
    'Compara eliminar solo el contenedor con eliminar también su almacenamiento. El ejercicio reutiliza el mismo montaje al recrear.',
    'Ejemplo distinto: un informe escrito en /reports, montado desde una carpeta del host, sigue en esa carpeta aunque se elimine el contenedor. La capa escribible de ese contenedor sí se elimina. Un volumen y un bind mount conservan datos fuera de esa capa, aunque los administra alguien distinto.',
  ],
  'M08-D08-compose': [
    'Clasifica el requisito del caso: configurar la app, publicar un puerto, persistir datos o esperar disponibilidad.',
    'Busca qué componente consume la configuración y qué recurso debe existir o estar listo antes de usarlo.',
    'Distingue orden de creación, disponibilidad inicial y recuperación tras un fallo. Son necesidades diferentes.',
    'Ejemplo distinto: un proceso creado puede tardar en aceptar conexiones. Un chequeo de salud permite comprobar su disponibilidad; la dependencia debe usar ese chequeo para esperar al arranque. Después, la aplicación sigue necesitando manejar fallos de conexión.',
  ],
  'M08-D09-debug': [
    'Separa el síntoma que observaste de la causa que todavía estás suponiendo.',
    'Busca el dato que permitiría comprobarla: salida del proceso, estado de Docker, ruta de archivos o configuración de puertos.',
    'Compara leer evidencia con cambiar algo a ciegas. Un código de salida por sí solo no siempre identifica una causa única.',
    'Ejemplo distinto: un contenedor que termina con código 0 pudo completar correctamente una tarea corta; no demuestra que Docker falló. Contrasta qué debía hacer el proceso con sus logs y estado antes de reconstruir o borrar recursos.',
  ],
  'M08-D10-security': [
    'Identifica qué se intenta proteger: un secreto, los privilegios del proceso o el contenido de una imagen.',
    'Revisa quién puede leer ese dato o qué capacidad adicional recibe la aplicación.',
    'Compara una necesidad real de la app con un permiso o paquete añadido por comodidad. Distingue una etiqueta de una referencia a contenido exacto.',
    'Ejemplo distinto: un servicio que solo lee archivos no necesita permiso de escritura sobre todos los datos del host. Reducir ese permiso limita el daño si se compromete. Aplica el mismo criterio de mínima capacidad al riesgo concreto del caso.',
  ],
  'M08-D11-deploy': [
    'Separa los tres elementos del despliegue: imagen de la aplicación, configuración y datos persistentes.',
    'Identifica qué referencia permite recuperar la release y qué comprobación protege los datos.',
    'Compara volver a una imagen anterior con volver a un esquema de datos anterior. Una acción no garantiza la otra.',
    'Ejemplo distinto: una release antigua que no entiende una columna obligatoria nueva puede fallar aunque su imagen esté guardada. Un rollback exige comprobar compatibilidad; un respaldo exige verificar que puede restaurarse. Registrar un digest permite identificar el contenido exacto de la imagen.',
  ],
  'M08-D12-capstone': [
    'Trata cada caso por separado: escribe su requisito y una observación que permita comprobar la decisión.',
    'Clasifica cada decisión: comunicación, configuración, persistencia, diagnóstico, seguridad o despliegue.',
    'Comprueba si una opción arregla el síntoma a costa de perder datos, exponer un servicio o cambiar algo sin evidencia.',
    'Ejemplo distinto: reiniciar un servicio puede ocultar temporalmente un fallo sin explicar su causa. Conservar logs, comprobar dependencias y verificar el resultado permite defender la decisión. En cada caso justifica acción, mecanismo y comprobación; no basta con elegir una opción.',
  ],
};

List<String> dockerHintsFor(String? unit, String mission) {
  if (mission != 'experimentar' && mission != 'nuevo') return const [];
  return _dockerUnitHints[unit] ?? const [];
}

/// La ayuda sigue el ejercicio central. Varias unidades comparten widget
/// (DecisionScenarios, ConfigAudit, CommandComposer…), así que la unidad la da
/// el parámetro `unit` del servidor; sin él no se adivina cuál es.
String? dockerInterventionUnit(Map? intervention) {
  if (intervention == null) return null;
  final spec = intervention['widget_parameters'] as Map? ?? const {};
  final params = spec['parameters'] as Map? ?? const {};
  final widget = intervention['widget_type'];
  for (final candidate in [params['unit'], spec['learning_objective']]) {
    if (dockerUnits.any((u) => u.id == candidate)) return candidate as String;
  }
  final matches = dockerUnits.where((u) => dockerUnitWidget(u.id).widget == widget).toList();
  return matches.length == 1 ? matches.single.id : null;
}

String dockerCoach(String mission, {String? unitId, bool interacted = false, bool submitted = false}) =>
    switch (mission) {
      'aprender' => 'Fíjate en los errores comunes: el experimento los pone a prueba.',
      'experimentar' when interacted => 'Ya hay evidencia. Ahora explica abajo por qué decidiste así.',
      'experimentar' when unitId == 'M08-D02-lifecycle' => 'Elige una predicción para el paso señalado; después recorre la simulación y explica lo observado.',
      'experimentar' when unitId == 'M08-D04-dockerfile' => 'Reordena los bloques y explica qué trabajo se reutiliza si cambia solo el código.',
      'experimentar' when unitId == 'M08-D07-persistence' => 'Elige montaje, predice, escribe el archivo y recrea. Después compara y explica.',
      'experimentar' => 'Lee los requisitos de cada caso, decide y justifica con evidencia. Puedes pedir ayuda por niveles.',
      'justificar' when submitted =>
        'Contrasta las observaciones de la evaluación con tu respuesta; después explora el nuevo desafío.',
      'justificar' => 'Envía primero tus decisiones y tu justificación.',
      'nuevo' when unitId != null => 'Este reto trabaja «${dockerUnitById(unitId).title}». Las pistas corresponden a este ejercicio, aunque sea de otra unidad.',
      'nuevo' => 'Lee la consigna del reto y distingue qué decisión pide y con qué evidencia la comprobarías.',
      _ => 'Cuando empieces la prueba, el tutor se apaga.',
    };
