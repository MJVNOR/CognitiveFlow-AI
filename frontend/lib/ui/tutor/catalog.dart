// Catálogo GenUI cerrado (genui 0.10.4). Espejo exacto del backend
// (app/interventions.py CATALOG).
export 'widgets/events.dart';
export 'widgets/socratic.dart';
export 'widgets/data_widgets.dart';
export 'widgets/ml_widgets.dart';
export 'widgets/docker_widgets.dart';

import 'widgets/socratic.dart';
import 'widgets/data_widgets.dart';
import 'widgets/ml_widgets.dart';
import 'widgets/docker_widgets.dart';

/// Nombres que el backend puede pedir (= CATALOG en app/interventions.py).
const cognitiveFlowWidgets = {
  'SocraticQuestionCard',
  'EvidenceComparison',
  'HypothesisEditor',
  'DataTableExplorer',
  'DriftDistributionExplorer',
  'ChoiceReasoningWidget',
  'SqlQueryWorkbench',
  'LearningCurveSimulator',
  'ConceptMapBuilder',
  'PipelineDAGBuilder',
  'RubricFeedbackCard',
  'ReflectionSummary',
  'ContainerVsVmExplorer',
  'ImageContainerLifecycle',
  'DockerfileWorkbench',
  'PersistenceExperiment',
};

final cognitiveFlowCatalog = [
  socraticQuestionCard,
  evidenceComparison,
  hypothesisEditor,
  dataTableExplorer,
  driftDistributionExplorer,
  choiceReasoningWidget,
  sqlQueryWorkbench,
  learningCurveSimulator,
  conceptMapBuilder,
  pipelineDAGBuilder,
  rubricFeedbackCard,
  reflectionSummary,
  containerVsVmExplorer,
  imageContainerLifecycle,
  dockerfileWorkbench,
  persistenceExperiment,
];
