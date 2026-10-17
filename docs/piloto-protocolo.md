# Piloto exploratorio — protocolo y registro (Sprint 5.5)

> N=4, exploratorio. Prohibido afirmar eficacia o generalización estadística.
> Las puntuaciones Jev NO son medición neuropsicológica ni un score es «dominio».

## 1. Participantes y consentimiento

- 4 estudiantes Data Science/ML + 1 instructor (solo lectura, sin calificar).
- Consentimiento informado previo (plantilla §2), voluntario, revocable, sin
  impacto en notas. Usuarios reales sustituyen a `s1-s4`/`i1` solo en el entorno
  del piloto; el export anonimiza a `STU-01…` automáticamente.
- Datos: respuestas, eventos, evaluaciones y repasos. Sin PII en CSV.
  Retención definida por el instructor; borrar a petición.

## 2. Plantilla de consentimiento (adaptar con el instructor)

> Participo voluntariamente en el piloto de CognitiveFlow AI. Sé que mis
> interacciones (respuestas, eventos, evaluaciones automáticas) se registran
> anonimizadas para investigación educativa, que puedo retirarme en cualquier
> momento sin consecuencias y que pediré el borrado de mis datos cuando quiera.
> Firma: __________  Fecha: __________

## 3. Guion de tareas (comparables entre los 4)

1. ML Experiment (M03-U02): predicción → experimento → justificación →
   intervención → postest variante nueva → reflexión.
2. Data Detective (M02-U02): clasificar + plan de limpieza → transferencia.
3. Model Monitoring (M06-U04): deriva vs performance → decisión → postest.
4. Cierre: reflexión por lab (automática) + repaso 1/3/7 (`/me/recall-due`).

## 4. Métricas a capturar (sin causalidad)

- Completitud por lab (inicial → postest → done).
- Intervenciones por estrategia y ayudas usadas (`assistance`).
- Errores corregidos (baseline vs postest por criterio).
- Pre/post/retención (incluye repaso 1/3/7).
- Calibración Jev vs revisión humana: usar `instructor_reviews` vía API está
  desactivado (readonly); hacerlo offline con el CSV anonimizado del export.

## 5. Registro de hallazgos (rellenar tras el piloto)

| Alumno | Lab | Completitud | Baseline→Postest | Intervenciones | Notas |
|---|---|---|---|---|---|
| STU-01 | | | | | |
| STU-02 | | | | | |
| STU-03 | | | | | |
| STU-04 | | | | | |

Hallazgos (descriptivo, N=4, sin generalizar): _(pendiente de ejecución)_

## 6. Criterios de cierre

Piloto válido si los 4 completan ≥1 lab con postest y reflexión, sin incidentes
de privacidad, y el registro §5 queda archivado con fecha y versión de rúbricas.
