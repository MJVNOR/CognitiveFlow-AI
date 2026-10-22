/// Tipos de las figuras del concepto. Separado de `lab_figures.dart` para que
/// el widget no dependa del mapa de contenido.
library;

/// Una imagen de la figura, con su leyenda y su descripción para lectores de
/// pantalla. El PNG no contiene texto: todo lo legible es texto de Flutter.
class LabFigureVariant {
  /// Ruta sin tema ni extensión: `assets/figures/d01-shared`.
  final String asset;
  final String caption;
  final String alt;
  const LabFigureVariant({required this.asset, required this.caption, required this.alt});
}

/// Una figura del concepto: un título y una o varias variantes comparables.
class LabFigure {
  final String title;
  final List<LabFigureVariant> variants;
  const LabFigure({required this.title, required this.variants});
}
