/// Reparto del espacio del grid de pads: cuantas columnas, con que proporcion
/// y con que espaciado se dibuja para un area disponible dada.
///
/// Es logica pura, sin dependencias de Flutter, precisamente porque este es el
/// punto donde escritorio y movil divergian: poder cubrirlo con tests evita que
/// una pantalla vuelva a quedarse con una sola columna sin que nadie se entere.
class PadGridLayout {
  const PadGridLayout({
    required this.columns,
    required this.aspectRatio,
    required this.padding,
    required this.spacing,
  });

  /// Numero de columnas del grid.
  final int columns;

  /// Proporcion ancho/alto de cada celda (`childAspectRatio` de Flutter).
  /// Mayor que 1 significa pads mas anchos que altos.
  final double aspectRatio;

  /// Margen exterior del grid.
  final double padding;

  /// Separacion entre celdas, en ambos ejes.
  final double spacing;

  /// Alto por debajo del cual se considera que la pantalla es "corta":
  /// un movil en horizontal, o una ventana muy achatada.
  static const double shortViewportHeight = 480;

  /// Filas que deben seguir viendose sin desplazar en una pantalla corta.
  /// En mitad de una actuacion, tener que hacer scroll para llegar a un pad es
  /// un fallo funcional, no estetico.
  static const int minVisibleRowsOnShortViewport = 2;

  /// Tope de deformacion: por muy corta que sea la pantalla, un pad no se
  /// convierte en una franja inservible.
  static const double maxAspectRatio = 3.0;

  /// Ajuste elegido por el DJ en Ajustes > Tamano de los pads.
  ///
  /// [target] es el ancho ideal del pad en pixeles logicos y es quien manda en
  /// pantallas grandes. [minColumns] es el suelo que hace que el ajuste siga
  /// significando algo en pantallas estrechas.
  ///
  /// Sin ese suelo, en un movil de 360 dp el nivel "Grande" daba UNA sola
  /// columna -- un pad ocupando la pantalla entera -- y "Mediano" era
  /// indistinguible de "Auto": los objetivos en pixeles estaban calculados para
  /// un monitor, asi que en un telefono los seis niveles colapsaban en cuatro,
  /// uno de ellos roto. Con el suelo, un movil recorre 2-3-4-5-6 columnas y el
  /// escritorio conserva exactamente el comportamiento que ya tenia.
  static const Map<int, _PadSizeLevel> _levels = <int, _PadSizeLevel>{
    1: _PadSizeLevel(target: 220, minColumns: 2, maxColumns: 8, gap: 12),
    2: _PadSizeLevel(target: 160, minColumns: 3, maxColumns: 12, gap: 8),
    3: _PadSizeLevel(target: 96, minColumns: 4, maxColumns: 16, gap: 6),
    4: _PadSizeLevel(target: 82, minColumns: 5, maxColumns: 20, gap: 5),
    5: _PadSizeLevel(target: 70, minColumns: 6, maxColumns: 26, gap: 4),
  };

  /// Calcula el reparto para un area de [width] x [height] pixeles logicos.
  ///
  /// [padSize] es el nivel guardado en Ajustes; `0` (o cualquier valor
  /// desconocido) significa automatico. Pasar `height <= 0` desactiva el ajuste
  /// por altura, util cuando el alto disponible aun no se conoce.
  static PadGridLayout resolve({
    required double width,
    required double height,
    required int padSize,
  }) {
    final safeWidth = width > 0 ? width : 1.0;

    final int columns;
    final double padding;
    final double spacing;
    double aspectRatio = 1.05;

    final level = _levels[padSize];
    if (level != null) {
      // El objetivo en pixeles decide en pantallas amplias; el suelo decide en
      // las estrechas. El que resulte mayor es el que gana.
      final byTarget = (safeWidth / level.target).floor();
      columns = byTarget.clamp(level.minColumns, level.maxColumns);
      padding = level.gap;
      spacing = level.gap;
    } else {
      padding = 10;
      spacing = 10;
      if (safeWidth < 320) {
        columns = 1;
        aspectRatio = 1.35;
      } else if (safeWidth < 500) {
        columns = 2;
        aspectRatio = 1.25;
      } else if (safeWidth < 750) {
        columns = 3;
        aspectRatio = 1.15;
      } else if (safeWidth < 1050) {
        columns = 4;
      } else if (safeWidth < 1400) {
        columns = 6;
      } else if (safeWidth < 1750) {
        columns = 8;
      } else {
        columns = 10;
      }
    }

    return PadGridLayout(
      columns: columns,
      aspectRatio: _fitRowsOnShortViewport(
        width: safeWidth,
        height: height,
        columns: columns,
        padding: padding,
        spacing: spacing,
        aspectRatio: aspectRatio,
      ),
      padding: padding,
      spacing: spacing,
    );
  }

  /// Ensancha las celdas cuando la pantalla es demasiado corta para mostrar el
  /// minimo de filas.
  ///
  /// Con pads casi cuadrados, un movil en horizontal dejaba visible poco mas de
  /// una fila y obligaba a desplazar el grid para alcanzar el resto. Las
  /// pantallas altas no se tocan: la proporcion se devuelve tal cual.
  static double _fitRowsOnShortViewport({
    required double width,
    required double height,
    required int columns,
    required double padding,
    required double spacing,
    required double aspectRatio,
  }) {
    if (height <= 0 || height >= shortViewportHeight) return aspectRatio;

    final cellWidth =
        (width - padding * 2 - spacing * (columns - 1)) / columns;
    final usableHeight = height -
        padding * 2 -
        spacing * (minVisibleRowsOnShortViewport - 1);
    final maxCellHeight = usableHeight / minVisibleRowsOnShortViewport;
    if (cellWidth <= 0 || maxCellHeight <= 0) return aspectRatio;

    final cellHeight = cellWidth / aspectRatio;
    if (cellHeight <= maxCellHeight) return aspectRatio;

    return (cellWidth / maxCellHeight).clamp(aspectRatio, maxAspectRatio);
  }
}

/// Parametros de un nivel de tamano de pad. Ver PadGridLayout._levels.
class _PadSizeLevel {
  const _PadSizeLevel({
    required this.target,
    required this.minColumns,
    required this.maxColumns,
    required this.gap,
  });

  /// Ancho ideal del pad en pixeles logicos.
  final double target;

  /// Columnas minimas, para que el nivel siga distinguiendose en pantallas
  /// estrechas.
  final int minColumns;

  /// Columnas maximas, para que el nivel no se disuelva en pantallas enormes.
  final int maxColumns;

  /// Margen y separacion del grid en este nivel.
  final double gap;
}
