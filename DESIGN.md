# CognitiveFlow AI — DESIGN.md

> **Estado:** especificación de diseño v1.0 · **Fecha:** 15 de octubre de 2026  
> **Destinatario:** agente de programación OpenCode y equipo de CognitiveFlow.  
> **Ámbito:** Flutter Web, Flutter GenUI/A2UI, tutor socrático con Gemini, evaluación Jev, SQLite y laboratorios de Data Science.  
> **Propósito:** crear una interfaz atractiva, accesible y consistente que apoye la atención, la comprensión y el razonamiento **sin afirmar que un color por sí solo mejora el aprendizaje**.

## 1. Tesis del diseño

**CognitiveFlow no es un chatbot decorado. Es un laboratorio cognitivo:** el estudiante predice, manipula, observa, argumenta, recibe retroalimentación y vuelve a intentarlo. El diseño debe reducir el esfuerzo dedicado a entender la interfaz y mantener el esfuerzo intelectual necesario para aprender.

**Principios no negociables**

1. El aprendizaje activo tiene prioridad sobre los efectos visuales.
2. El color sirve para **señalar relaciones, estados e interacciones**; no determina inteligencia, creatividad ni calificaciones.
3. Cada laboratorio mantiene un código de color semántico constante, con etiquetas, símbolos y patrones redundantes.
4. Una sola acción principal por vista o fase. No saturar con paneles simultáneos.
5. Las calificaciones Jev son evidencia orientativa; no mostrar su confianza como porcentaje de dominio cognitivo.
6. Las decisiones visuales deben comprobarse mediante accesibilidad y pruebas con los cuatro estudiantes.
7. No reemplazar ni reinicializar pantallas, tokens, widgets ni flujos ya implementados sin auditar el repositorio y sus avances.

## 2. Evidencia académica y límites

| Fuente | Hallazgo sustentado | Consecuencia en CognitiveFlow | Lo que **no** demuestra |
|---|---|---|---|
| Mehta & Zhu (2009), *Science*, DOI `10.1126/science.1169144` | En condiciones experimentales, rojo/azul tuvieron efectos distintos según tareas de atención al detalle o creatividad. | No asignar un único color para todo el aprendizaje; reservar acentos según función. | Que azul siempre mejora la creatividad o rojo siempre mejora la memoria en nuestra app. |
| Elliot & Maier (2014), *Annual Review of Psychology*, DOI `10.1146/annurev-psych-010213-115035` | Los efectos psicológicos del color dependen del contexto y existen límites de generalización. | Formular los significados de color como **hipótesis de diseño**, no como efectos garantizados. | Una paleta pedagógica universal. |
| Richter, Scheiter & Eitel (2016), *Educational Research Review*, DOI `10.1016/j.edurev.2015.12.003` | Metaanálisis sobre señalización de relaciones texto-imagen: efecto positivo pequeño a mediano (r≈0.17), especialmente para participantes con menor conocimiento previo. | Colorear consistentemente correspondencias entre instrucciones y gráficos. | Que usar más colores siempre resulte mejor. |
| *The more total cognitive load is reduced by cues...* (2017), metaanálisis, PMC5576760 | Las señales de atención (incluyendo codificación por color) se asocian con mejor retención y transferencia en los estudios analizados. | Acentos puntuales, resaltado contextual y leyendas vinculadas. | Que la decoración cromática sin intención pedagógica ayude. |
| Ozcelik et al. (2009), *Computers & Education*, DOI `10.1016/j.compedu.2009.03.002` | En un estudio con 52 participantes, la codificación cromática ayudó a localizar correspondencias entre ilustración y texto y mejoró resultados de retención/transferencia. | Igual color + etiqueta en curva, interpretación y tarjeta explicativa relacionada. | Una superioridad global de una combinación concreta de tonos. |
| *Impacts of Color Coding on Programming Learning* (2021), *Frontiers in Psychology*, DOI `10.3389/fpsyg.2021.773328` | Estudio de 42 universitarios encontró beneficios de material codificado por color respecto a escala de grises para aprendizaje de programación en su contexto. | Aplicar color semántico a fragmentos de código, errores y datos relacionados. | Que colorear todo el código o la interfaz beneficie a cualquier estudiante. |
| Cromley & Chen (2025), *Educational Research Review*, DOI `10.1016/j.edurev.2025.100730` | Metaanálisis: resultados varían por contexto y las intervenciones de aprendizaje activo tienen efectos especialmente importantes frente a cambios meramente de diseño. | Priorizar experimentos, predicción, justificación y postest por encima del tema visual. | Que cambiar la paleta sustituya la enseñanza activa. |
| W3C WCAG 2.2 | Texto normal 4.5:1, texto grande 3:1, controles/objetos gráficos relevantes 3:1; el color no debe ser el único medio para comunicar información. | Validar contraste, etiquetas y estados de toda UI, incluyendo gráficos generados. | Una preferencia pedagógica por algún tono. |

**Lectura metodológica:** los papers respaldan sobre todo *codificación por color*, *señalización* y *reducción de carga cognitiva extrínseca*, no una 'trifecta' universal. **Nuestra tríada es una decisión de diseño basada en funciones y accesibilidad**, pendiente de evaluación empírica con los alumnos.

## 3. Trifecta de marca: AZUL + VERDE AZULADO + ÁMBAR

Son tres **colores primarios de marca**, no los colores primarios de teoría del color (RGB/RYB). No usar tres colores saturados al mismo tiempo. Neutros, estados de error y colores de gráficas complementarios están permitidos.

| Token | Hex | Nombre | Rol de diseño | Uso correcto |
|---|---|---|---|---|
| `brand.blue` | `#2457C5` | Cognitive Blue | navegación, estructura, acciones principales | botón principal, pestaña activa, foco y enlaces |
| `brand.teal` | `#0F766E` | Discovery Teal | exploración, experimentación, actividad práctica | modo laboratorio, parámetros/controles, evidencia contextual |
| `brand.amber` | `#A65B00` | Reflection Amber | reflexión y atención localizada | pregunta socrática, revisión de hipótesis, llamada a reconsiderar |

**Significado no universal:** estos roles son convenciones consistentes del producto, **no afirmaciones psicológicas causales**. El ámbar es una señal de atención pedagógica, **no equivale a error**.

### Paleta visual

| Muestra | Color | Hex |
|---|---|---|
| 🟦 | Cognitive Blue | `#2457C5` |
| 🟩 | Discovery Teal | `#0F766E` |
| 🟧 | Reflection Amber | `#A65B00` |

> El icono emoji es ilustrativo y no reproduce exactamente el HEX. Los hexadecimales son la fuente de verdad.

### Distribución de uso propuesta (heurística, no regla científica)

- 70–80% superficies neutras (blanco, blanco grisáceo, gris tinta).
- Aproximadamente 10–15% azul para navegación y acciones.
- Aproximadamente 5–10% verde azulado para herramientas de laboratorio.
- Aproximadamente 2–5% ámbar para preguntas, reflexión y señales puntuales.
- Esta proporción **no debe imponerse como cuota exacta**: medir claridad y no superficie cromática.

### Colores neutros y soporte (tema claro, base del MVP)

```yaml
background: '#F8FAFC'
surface: '#FFFFFF'
surface_muted: '#F1F5F9'
ink_primary: '#0F172A'
ink_secondary: '#475569'
border: '#CBD5E1'
brand_blue: '#2457C5'
brand_blue_soft: '#E8EEFF'
brand_teal: '#0F766E'
brand_teal_soft: '#E4F4F0'
brand_amber: '#A65B00'
brand_amber_soft: '#FFF3D6'
semantic_error: '#B42318'
semantic_error_soft: '#FEECEB'
semantic_success: '#166534'
semantic_success_soft: '#DCFCE7'
focus: '#2457C5'
```

**Pares contrastados calculados con fórmula WCAG (tema claro):**

| Par | Contraste aprox. | Aplicación |
|---|---:|---|
| Blanco / Blue `#2457C5` | 6.47:1 | texto blanco en botón azul: AA normal |
| Blanco / Teal `#0F766E` | 5.47:1 | texto blanco en botón teal: AA normal |
| Blanco / Amber `#A65B00` | 5.10:1 | texto blanco en botón ámbar oscuro: AA normal |
| Tinta `#0F172A` / blanco | 17.85:1 | texto principal |
| Gris texto `#475569` / blanco | 7.58:1 | texto secundario |
| Blue / fondo `#F8FAFC` | 6.19:1 | enlaces sobre fondo |
| Teal / fondo `#F8FAFC` | 5.23:1 | etiquetas informativas |
| Amber / fondo `#F8FAFC` | 4.87:1 | títulos/íconos |

**Prohibido:** texto blanco sobre ámbar brillante `#F4B544` (≈1.82:1). Ese amarillo claro solo puede ser fondo con tinta oscura. Los fondos suaves no son automáticamente válidos como borde o indicador de selección: comprobar contraste con colores adyacentes.

### Dark mode (fase posterior, no bloquear MVP)

- Preparar `ColorScheme` con tokens semánticos y soporte light/dark.
- No invertir colores mecánicamente: recalcular contraste para nuevas superficies y textos.
- Antes de lanzar dark mode, ejecutar auditoría WCAG sobre botones, trazos de gráficas, estado activo y pistas.

## 4. Reglas semánticas de color

| Situación | Color | Elemento adicional obligatorio |
|---|---|---|
| Acción principal / navegar | Blue | texto de botón inequívoco, foco de teclado |
| Experimento / manipulación | Teal | icono laboratorio, etiqueta de parámetro |
| Solicitud de justificación / reflexión | Amber | icono pregunta o foco, instrucción escrita |
| Respuesta incorrecta / error | `semantic_error` | texto de error y símbolo; nunca solo rojo |
| Meta lograda y verificada | `semantic_success` | texto y check; sin inflar mérito |
| Pendiente / incierto | neutral + opcional amber | texto «Pendiente» o «Requiere revisión» |
| Evaluación Jev | neutral + chips semánticos | criterios, versión y explicación transparente |

**Importante:** azul/teal/amber describen funciones de la UI, no valores ordinales de puntuación. No usar ámbar para todas las respuestas incorrectas porque confundiría reflexión con fallo.

## 5. Color en visualizaciones de laboratorios

### ML Experiment Lab

- Curva de entrenamiento: **azul** `#2457C5`, **línea continua**, marcador circular, etiqueta `Training loss`.
- Curva de validación: **ámbar** `#A65B00`, **línea discontinua**, marcador cuadrado, etiqueta `Validation loss`.
- Parámetros manipulables: **teal** con controles accesibles.
- La pregunta socrática usa panel claro ámbar y encabezado «¿Qué evidencia respalda tu hipótesis?».
- Leyenda visible siempre, tooltip con valores y alternativa tabular accesible.
- Al citar una curva en la explicación, mostrar un chip del mismo tono **y el nombre textual**.

### Data Detective

- Resaltar una columna referida en una pregunta usando teal + nombre en encabezado + indicador no cromático.
- Faltantes: símbolo `—` y etiqueta «valor ausente», no solo fondo de color.
- Outliers: contorno/forma distinta + explicación del criterio, no marcar automáticamente como error.
- Data leakage: advertencia textual y acceso a justificación; no dar la respuesta antes del intento.

### Model Monitoring Lab

- Distribución de referencia: azul sólido / línea continua.
- Distribución actual: teal / línea punteada y patrones para distinguir barras.
- Umbral/revisión: ámbar + línea de referencia + valor.
- Drift no implica necesariamente degradación: comunicar métricas y limitaciones explícitas.
- Gráficas de múltiples series pueden requerir más de tres colores; usar paleta accesible por serie, trazos y etiquetas, no forzar tres tonos.

### Legibilidad de gráficos

1. Contraste de trazos e indicadores importantes ≥3:1 frente al fondo cuando son esenciales para interpretar la gráfica.
2. Line width recomendado inicial 2.5–3 px (comprobar en diferentes escalas).
3. Escalas, unidades y leyenda persistentes; no alterar eje Y de manera engañosa.
4. No usar únicamente rojo/verde para comparaciones; complementar con símbolos/patrones.
5. Tooltips accesibles mediante teclado y/o tabla de datos.

## 6. Tipografía, composición y movimiento

### Tipografía

- Familia de texto: **Inter** o **Roboto** de fuente autorizada (usar fuente del sistema si falta; no redistribuir fuentes de terceros).
- Código, SQL y terminal: **JetBrains Mono** o monospace del sistema.
- Escala orientativa escritorio: título pantalla 28–32sp, secciones 20–24sp, cuerpo 16sp, secundario 14sp, captions 12–13sp solo información no crítica.
- Altura de línea del cuerpo ~1.45–1.6; evitar párrafos extensos dentro de tarjetas estrechas.
- Preferir sentence case; evitar mayúsculas sostenidas para instrucciones largas.

### Layout

- Desktop: navegación lateral compacta (224–256 px), contenido central máx. 960–1120 px; panel derecho solo si aporta información contextual sin desplazar el problema.
- Pantallas pequeñas: una sola columna, navegación adaptada y evaluación en panel plegable.
- Escala de espacio de 8 px (4, 8, 12, 16, 24, 32, 48).
- Bordes 12–16 px para tarjetas y 8–12 px para inputs.
- Padding tarjeta 16–24 px; botones con objetivo táctil recomendado ≥44×44 px.
- Nunca usar solo sombra para definir interacción; borde o superficie contrastante.

### Movimiento y motivación

- Animaciones discretas (aprox. 120–220 ms) para cambios de estado, **sin bloquear tareas**.
- Respetar «reducir movimiento» del sistema.
- Gradiente de meta: `Desafío 2 de 4` refleja actividades reales completadas; no significa «50% aprendido».
- Efecto pico-fin: resumen final personalizado que reporte hechos observables, no halagos automáticos.
- No añadir retrasos ficticios para crear ilusión de labor; si Jev procesa, mostrar el estado auténtico.

## 7. Patrones de pantallas

### Academia (`/academy`)

- Header con objetivo actual y acceso al progreso.
- Módulos ordenados por prerrequisitos, no saturar pantalla con todas las actividades.
- Tarjeta de módulo: título, cursos externos, prerequisitos, laboratorio asociado, progreso real.
- CTA azul «Continuar laboratorio»; acciones secundarias como enlaces discretos.

### Laboratorio (`/labs/:id`)

**Orden pedagógico fijo:**

1. **Objetivo + predicción** (estado actual y pregunta clara).
2. **Herramienta interactiva** (teal; gráfico/tabla/simulador).
3. **Justificación** (campo de texto prominente).
4. **Evaluación** (rúbrica, Jev, estado verificado/pending).
5. **Intervención socrática** (amber; cuestionamiento o nuevo experimento).
6. **Postest sin ayuda** (tema visual neutro, sin pistas ni evaluación inmediata).
7. **Reflexión final** (progreso basado en evidencias).

En escritorio, los puntos 1–3 deben dominar el área central. La evaluación no debe mostrarse antes de responder para evitar anclaje indebido. No animar resultados como si Jev fuese una verdad absoluta.

### Tutor socrático (`/tutor`)

- Chat con contexto de tema, pero priorizar widgets de actividad cuando el objetivo es experimentar.
- Color azul para acciones generales, ámbar solo para la pregunta esencial, teal para la herramienta.
- No más de una pregunta socrática principal por intervención.
- Si el estudiante lo solicita, permitir ayuda escalonada y eventualmente explicación.

### Progreso e instructor

- Separar **avance de curso** de **evidencia de dominio** (resultados sin ayuda).
- Mostrar incertidumbre y casos pendientes de revisión con texto, no solo semáforo.
- Gráficas comparativas incluyen rango temporal, tamaño de muestra y leyendas.
- Permitir al instructor corregir evaluaciones Jev.

## 8. GenUI: reglas visuales del catálogo

Los widgets generados **no pueden seleccionar libremente HEX**. El agente Gemini define intención educativa; Flutter decide apariencia según tokens cerrados.

**Modelo de contrato recomendado (conceptual, NO payload A2UI oficial):**

```json
{
  "component": "LearningCurveSimulator",
  "props": {
    "title": "Explora el sobreajuste",
    "learningObjective": "Distinguir generalización de memorización",
    "datasets": ["training_loss", "validation_loss"],
    "requiresJustification": true
  },
  "visualRole": "experiment",
  "emphasis": "normal"
}
```

`visualRole` limitado a `navigation | experiment | reflection | neutral | warning | success`; la app mapea cada rol a tokens. Validar esquema, textos, rangos, tamaño de datos y URLs. No aceptar Dart, HTML, JS o CSS generado arbitrariamente. El backend audita la elección y Flutter renderiza catálogo autorizado según API GenUI/A2UI **de la versión instalada**.

**Componentes MVP y roles:**

| Widget | Rol |
|---|---|
| `SocraticQuestionCard` | reflection |
| `HypothesisEditor` | neutral |
| `ChoiceReasoningWidget` | neutral |
| `LearningCurveSimulator` | experiment |
| `EvidenceComparison` | reflection |
| `RubricFeedbackCard` | neutral |
| `ReflectionSummary` | success/neutral según evidencia |
| `DataTableExplorer` | experiment |
| `DriftDistributionExplorer` | experiment |

## 9. Tokens Flutter — punto de partida

Aplicar sobre el ThemeData **existente**, sin reemplazar estilos ya implementados ciegamente.

```dart
import 'package:flutter/material.dart';

abstract final class CognitiveColors {
  static const blue = Color(0xFF2457C5);
  static const teal = Color(0xFF0F766E);
  static const amber = Color(0xFFA65B00);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9);
  static const ink = Color(0xFF0F172A);
  static const inkSecondary = Color(0xFF475569);
  static const border = Color(0xFFCBD5E1);
  static const error = Color(0xFFB42318);
  static const success = Color(0xFF166534);
}

ThemeData buildCognitiveLightTheme() {
  const scheme = ColorScheme.light(
    primary: CognitiveColors.blue,
    onPrimary: Colors.white,
    secondary: CognitiveColors.teal,
    onSecondary: Colors.white,
    tertiary: CognitiveColors.amber,
    onTertiary: Colors.white,
    surface: CognitiveColors.surface,
    onSurface: CognitiveColors.ink,
    error: CognitiveColors.error,
    onError: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: CognitiveColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: CognitiveColors.surface,
      foregroundColor: CognitiveColors.ink,
    ),
  );
}
```

**Advertencia:** `ThemeData` de arriba es un snippet de referencia para un tema claro, **no una orden de sobreescribir** la configuración existente ni una garantía automática de que todos los widgets GenUI cumplen WCAG. El agente debe integrar `ThemeExtension`/tokens semánticos existentes, si ya existen, y probar contraste en los componentes finales.

## 10. Auditoría visual obligatoria

- [ ] Todo texto normal relevante supera 4.5:1 contra el fondo real.
- [ ] Texto grande supera 3:1, según los umbrales WCAG.
- [ ] Inputs, selección, foco, iconos relevantes y gráficas esenciales superan 3:1 donde corresponde.
- [ ] No hay información transmitida únicamente por tono.
- [ ] Se conservan leyendas, títulos, unidades, etiquetas y alternativa tabular para gráficos.
- [ ] El foco de teclado es visible; navegación íntegra sin ratón.
- [ ] El zoom de navegador y tamaños de texto no ocultan botones ni justificaciones.
- [ ] Estados loading, error, pendiente, evaluado, revisado por instructor y mock son distinguibles por texto.
- [ ] La pantalla del postest no muestra pistas, feedback o solución antes de entregar.
- [ ] Un widget GenUI nuevo no introduce colores arbitrarios ni rompe la jerarquía.
- [ ] Revisar contraste en pantallas generadas dinámicamente y en todas las variantes de gráficas.
- [ ] Capturas antes/después para comprobar que el rediseño no rompe pantallas ya funcionales.

## 11. Validación con los cuatro estudiantes

**Diseño exploratorio, no ensayo causal** (n=4):

1. Baseline: observación de tarea corta con la UI existente y un problema representativo.
2. Aplicar tokens + señalización a un laboratorio de ML, manteniendo datos/actividad equivalentes.
3. Medir **tiempo para localizar información, errores de interpretación de leyendas, finalización de tareas, ayuda solicitada y satisfacción**.
4. Postest sin ayuda para observar la calidad de justificación; evaluación humana ciega cuando sea viable.
5. Preguntar qué colores y estados les causaron confusión, incluyendo pruebas de baja saturación o escala de grises.
6. Registrar resultados individuales y comentarios; no afirmar significancia ni mejora generalizable.

**Criterios propuestos para aceptación interna (objetivos de diseño, no evidencia científica):** cero fallos WCAG AA conocidos en flujos centrales; todos los participantes identifican la acción principal y distinguen las series de las gráficas mediante etiquetas/estilos; no se producen regresiones en completar una actividad. Revisar si alguno falla.

## 12. Plan de implementación para OpenCode (incremental)

### Fase A — Auditoría (sin modificar todavía)

- [ ] Leer `COGNITIVEFLOW_PLAN_CON_AVANCES_ACTUALIZADO.md` o el plan vigente y verificar casillas reales con el repo.
- [ ] Localizar `ThemeData`, widgets compartidos, `GenUI` catalog y gráficas.
- [ ] Ejecutar `flutter analyze`, `flutter test` y pruebas backend existentes; anotar baseline.
- [ ] Capturar estado visual de Academia, ML Experiment Lab, tutor y panel instructor.
- [ ] Identificar qué funcionalidades ya están completas y **no recrearlas**.

### Fase B — Tokens + layout

- [ ] Añadir `CognitiveColors` y mapeo semántico `ColorScheme` respetando la arquitectura actual.
- [ ] Refactorizar colores hardcodeados de componentes clave sin cambiar lógica de negocio.
- [ ] Actualizar CTA, foco, inputs, tarjetas, estados y sidebar.
- [ ] Revisar tema claro con contraste; dejar dark mode documentado.

### Fase C — Laboratorio ML

- [ ] Blue para training, amber para validation, teal para controles, con etiquetas/patrones.
- [ ] Vincular resaltados de instrucciones a elementos de gráfica.
- [ ] Separar hipótesis, experimento, justificación y evaluación posterior.
- [ ] Mantener gráficas deterministas si todavía no hay entrenamiento real; etiquetarlas como simuladas.
- [ ] Widget tests y capturas sobre los estados del laboratorio.

### Fase D — GenUI y resto de la app

- [ ] Integrar tokens por rol en el catálogo permitido y validar `visualRole`.
- [ ] Aplicar progresivamente a Data Detective y Model Monitoring al implementarlos.
- [ ] Implementar tarjetas de feedback Jev / pregunta Gemini sin sugerir certeza falsa.
- [ ] Mantener estados mock vs real visualmente distinguibles.

### Fase E — Pruebas y entrega

- [ ] Auditoría accesibilidad y responsive.
- [ ] Piloto con cuatro alumnos.
- [ ] Comparar antes/después con evidencias reproducibles.
- [ ] Agregar capturas, decisiones de diseño y bibliografía al pitch y documentación CHARAL.

## 13. Instrucción para el agente (copiar como tarea)

> Lee `DESIGN.md` junto con el plan maestro con avances de CognitiveFlow. Primero audita el estado del repositorio, las pantallas actuales y las pruebas. Implementa incrementalmente una trifecta visual azul `#2457C5`, teal `#0F766E` y ámbar oscuro `#A65B00`, con neutros y colores semánticos según el documento. Conserva la lógica Flutter, GenUI, FastAPI, SQLite, Gemini y Jev ya existente; no reinicialices el proyecto ni marques tareas como hechas sin verificarlas. Empieza por tema claro y ML Experiment Lab. Sigue WCAG 2.2 AA, prueba contraste y accesibilidad, registra capturas y ejecuta tests antes de continuar. No utilices nano; usa vim si es necesario editar desde terminal. Documenta toda desviación y muestra el resumen de archivos modificados.

## 14. Bibliografía y URLs para verificar

1. Mehta, R., & Zhu, R. J. (2009). *Blue or red? Exploring the effect of color on cognitive task performances.* Science. https://doi.org/10.1126/science.1169144
2. Elliot, A. J., & Maier, M. A. (2014). *Color psychology: Effects of perceiving color on psychological functioning in humans.* Annual Review of Psychology. https://doi.org/10.1146/annurev-psych-010213-115035
3. Richter, J., Scheiter, K., & Eitel, A. (2016). *Signaling text-picture relations in multimedia learning: A comprehensive meta-analysis.* Educational Research Review. https://doi.org/10.1016/j.edurev.2015.12.003
4. *The more total cognitive load is reduced by cues, the better retention and transfer of multimedia learning: A meta-analysis and two meta-regression analyses* (2017). https://pmc.ncbi.nlm.nih.gov/articles/PMC5576760/
5. Ozcelik, E., Karakus, T., Kursun, E., & Cagiltay, K. (2009). *An eye-tracking study of how color coding affects multimedia learning.* Computers & Education. https://doi.org/10.1016/j.compedu.2009.03.002
6. *Impacts of Color Coding on Programming Learning in Multimedia Learning: Moving Toward a Multimodal Methodology* (2021). Frontiers in Psychology. https://doi.org/10.3389/fpsyg.2021.773328
7. Cromley, J. G., & Chen, R. (2025). *A meta-analysis of Richard Mayer's multimedia learning research: Searching for boundary conditions of design principles across multiple media types.* Educational Research Review. https://doi.org/10.1016/j.edurev.2025.100730
8. W3C. *WCAG 2.2 — Contrast (Minimum).* https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
9. W3C. *WCAG 2.2 — Non-text Contrast.* https://www.w3.org/WAI/WCAG22/understanding/non-text-contrast.html
10. W3C. *WCAG 2.2 — Use of Color.* https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html

---

**Regla final:** la estética debe servir al razonamiento. Si una decisión de diseño hace la app más vistosa pero dificulta distinguir evidencia, manipular un experimento o justificar una hipótesis, debe descartarse.
