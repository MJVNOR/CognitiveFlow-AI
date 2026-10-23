// Figuras isométricas del "concepto en 1 minuto", una por objetivo.
// El PNG se genera en `figures/` (node figures/shoot.mjs); aquí solo se mapea
// objetivo -> figura, con su leyenda. Sin figura, ConceptPrimer no cambia.
import 'lab_figures_data.dart';

export 'lab_figures_data.dart';

const Map<String, LabFigure> labFigures = {
  // D01 · contenedor vs VM: mismo banco, distinto reparto del motor.
  'M08-D01-containers': LabFigure(
    title: 'Contenedores (izquierda) frente a máquinas virtuales (derecha)',
    variants: [
      LabFigureVariant(
        asset: 'assets/figures/d01-shared',
        caption: 'Contenedores: el motor es el kernel del host y los tres '
            'cabezales (contenedores) lo comparten. Ligeros y rápidos, pero si '
            'el kernel cambia o se para, cambian todos con él.',
        alt: 'Banco con tres cabezales de taladro colgados de un único eje, '
            'movido por un solo motor en el extremo.',
      ),
      LabFigureVariant(
        asset: 'assets/figures/d01-own',
        caption: 'Máquinas virtuales: cada cabezal lleva su propio motor '
            '(su propio kernel). Puede ser otro sistema operativo, pero carga '
            'con el coste de una máquina completa.',
        alt: 'Tres cabezales de taladro independientes, cada uno con su propio '
            'motor montado encima.',
      ),
    ],
  ),
  // D02 · imagen (molde reutilizable) frente a contenedor (pieza que se va).
  'M08-D02-lifecycle': LabFigure(
    title: 'El molde y la pieza',
    variants: [
      LabFigureVariant(
        asset: 'assets/figures/d02-mould',
        caption: 'El molde queda montado y se cierra igual en cada ciclo; la '
            'pieza sale, se usa y se descarta. La imagen es el molde, el '
            'contenedor es la pieza.',
        alt: 'Un molde de dos placas con su husillo montado en un banco, una '
            'pieza recién colada sobre la mesa y dos piezas más en una caja.',
      ),
    ],
  ),
  // D04 · capas reutilizadas y capa que se reconstruye.
  'M08-D04-dockerfile': LabFigure(
    title: 'Capas y caché',
    variants: [
      LabFigureVariant(
        asset: 'assets/figures/d04-layers',
        caption: 'Las capas de abajo ya están hechas y se reutilizan tal cual. '
            'Solo la capa que cambia se reconstruye: por eso el COPY del código '
            'va al final del Dockerfile.',
        alt: 'Una pila de placas bajo una brida: tres placas blancas debajo y '
            'una placa marcada arriba; a la derecha, las tres capas de abajo '
            'guardadas en una bandeja.',
      ),
    ],
  ),
  // D07 · qué sobrevive al recrear el contenedor.
  'M08-D07-persistence': LabFigure(
    title: 'Qué sobrevive al recrear',
    variants: [
      LabFigureVariant(
        asset: 'assets/figures/d07-persistence',
        caption: 'El depósito atornillado al banco (volumen nombrado) conserva '
            'su nivel aunque el contenedor se recree. La brida lleva el tubo '
            'fuera del banco (bind mount): depende de que esa ruta exista. La '
            'bandeja sin montar se queda seca.',
        alt: 'Un banco con una bandeja seca, un depósito atornillado con un tubo '
            'de nivel lleno hasta la mitad y una brida con un tubo recto que '
            'sale del banco.',
      ),
    ],
  ),
  // Data · qué hay que decidir antes de calcular.
  'M02-U02-cleaning': LabFigure(
    title: 'Línea de inspección',
    variants: [
      LabFigureVariant(
        asset: 'assets/figures/data-checkweigher',
        caption: 'La cinta trae seis puestos: dos llegan vacíos (faltan datos), '
            'uno trae la pieza repetida (duplicado) y uno trae una pieza que pega '
            'la aguja al tope (fuera de rango). Antes de calcular nada hay que '
            'decidir qué hacer con cada uno.',
        alt: 'Una cinta transportadora con seis puestos: dos vacíos, uno con dos '
            'piezas apiladas y uno con una pieza más ancha bajo un reloj '
            'comparador cuya aguja marca el tope.',
      ),
    ],
  ),
  // ML · sobreajuste: entrenamiento y validación se separan.
  'M03-U02-generalization': LabFigure(
    title: 'Dos plumas, dos curvas',
    variants: [
      LabFigureVariant(
        asset: 'assets/figures/ml-plotter',
        caption: 'Las dos plumas dibujan a la vez: la de entrenamiento baja y se '
            'aplana, la de validación baja un rato y vuelve a subir. Ese hueco '
            'final es el sobreajuste: el modelo se aprende los datos de memoria '
            'que ya vio.',
        alt: 'Un trazador plano sobre un banco con una brida de dos plumas y un '
            'mando estriado; en el papel, una curva que se aplana y otra que '
            'vuelve a subir al final.',
      ),
    ],
  ),
  // Monitoring · deriva frente a cambio de régimen.
  'M06-U04-drift': LabFigure(
    title: 'Dos plumas en la cinta',
    variants: [
      LabFigureVariant(
        asset: 'assets/figures/monitor-recorder',
        caption: 'Las dos plumas escriben sobre la misma cinta: una deriva '
            'despacio, sin que la métrica de negocio se mueva; la otra pega un '
            'escalón de golpe. Son dos problemas distintos.',
        alt: 'Un registrador de cinta con el rollo de papel detrás y una brida '
            'de dos plumas; en la cinta, una traza que baja despacio y otra que '
            'da un escalón y sigue plana.',
      ),
    ],
  ),
};
