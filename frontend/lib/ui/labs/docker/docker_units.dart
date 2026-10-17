// Unidad → widget GenUI + título (espejo de backend DOCKER_WIDGETS).
// Extraído de features/docker_lab_page.dart sin cambios; lo usa el test.
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
