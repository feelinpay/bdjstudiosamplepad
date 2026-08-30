import 'package:flutter_test/flutter_test.dart';

import 'package:bdj_studio_sample_pad/features/pad_system/domain/pad_grid_layout.dart';

/// Anchos y altos utiles en pixeles logicos (dp), que es la unidad con la que
/// trabaja Flutter. Un movil ronda los 360 dp de ancho: el mismo numero con el
/// que un monitor apenas dibuja dos pads.
const _phonePortrait = (width: 360.0, height: 760.0);
const _phoneLandscape = (width: 780.0, height: 300.0);
const _tabletPortrait = (width: 800.0, height: 1100.0);
const _laptop = (width: 1440.0, height: 780.0);
const _desktop = (width: 1920.0, height: 1000.0);

const _autoSize = 0;
const _allSizes = <int>[1, 2, 3, 4, 5];

PadGridLayout _resolve(({double width, double height}) viewport, int padSize) =>
    PadGridLayout.resolve(
      width: viewport.width,
      height: viewport.height,
      padSize: padSize,
    );

void main() {
  group('Tamano de pad elegido por el usuario', () {
    test('cada nivel da un numero distinto de columnas en un movil', () {
      // Regresion: con los objetivos en pixeles pensados para monitor, en un
      // movil de 360 dp "Grande" daba 1 sola columna y "Mediano" coincidia con
      // "Auto". El ajuste existia pero no servia para nada en Android.
      final columns = <int>[
        for (final size in _allSizes) _resolve(_phonePortrait, size).columns,
      ];

      expect(columns, <int>[2, 3, 4, 5, 6]);
      expect(
        columns.toSet().length,
        columns.length,
        reason: 'cada nivel debe producir una densidad distinta',
      );
    });

    test('mas denso nunca significa menos columnas, en ningun tamano de pantalla', () {
      for (final viewport in [
        _phonePortrait,
        _phoneLandscape,
        _tabletPortrait,
        _laptop,
        _desktop,
      ]) {
        var previous = 0;
        for (final size in _allSizes) {
          final columns = _resolve(viewport, size).columns;
          expect(
            columns,
            greaterThanOrEqualTo(previous),
            reason: 'nivel $size en ${viewport.width}x${viewport.height} dp',
          );
          previous = columns;
        }
      }
    });

    test('ningun nivel deja una sola columna en un movil', () {
      // Un pad ocupando la pantalla entera no es "grande": es inutilizable.
      for (final size in [..._allSizes, _autoSize]) {
        expect(_resolve(_phonePortrait, size).columns, greaterThan(1));
      }
    });

    test('el escritorio conserva la densidad que ya tenia', () {
      // El suelo de columnas solo actua en pantallas estrechas; en un monitor
      // manda el objetivo en pixeles, exactamente igual que antes del cambio.
      expect(
        [for (final size in _allSizes) _resolve(_desktop, size).columns],
        <int>[8, 12, 16, 20, 26],
      );
      expect(
        [for (final size in _allSizes) _resolve(_laptop, size).columns],
        <int>[6, 9, 15, 17, 20],
      );
    });
  });

  group('Modo automatico', () {
    test('escala con el ancho disponible', () {
      expect(_resolve(_phonePortrait, _autoSize).columns, 2);
      expect(_resolve(_tabletPortrait, _autoSize).columns, 4);
      expect(_resolve(_laptop, _autoSize).columns, 8);
      expect(_resolve(_desktop, _autoSize).columns, 10);
    });

    test('nunca devuelve cero columnas por muy estrecha que sea la ventana', () {
      for (final width in <double>[0, 1, 50, 200, 319]) {
        final layout = PadGridLayout.resolve(
          width: width,
          height: 600,
          padSize: _autoSize,
        );
        expect(layout.columns, greaterThanOrEqualTo(1));
      }
    });
  });

  group('Pantallas cortas (movil en horizontal)', () {
    test('ensancha los pads para que quepan al menos dos filas', () {
      // Con pads casi cuadrados solo se veia una fila y media: en mitad de una
      // actuacion habia que desplazar el grid para alcanzar el resto.
      for (final size in [_autoSize, 1, 2]) {
        final layout = _resolve(_phoneLandscape, size);
        final cellWidth = (_phoneLandscape.width -
                layout.padding * 2 -
                layout.spacing * (layout.columns - 1)) /
            layout.columns;
        final cellHeight = cellWidth / layout.aspectRatio;
        final visibleRows =
            (_phoneLandscape.height - layout.padding * 2) / cellHeight;

        expect(
          visibleRows,
          greaterThanOrEqualTo(2.0),
          reason: 'nivel $size deberia mostrar 2 filas en horizontal',
        );
      }
    });

    test('no deforma los pads mas alla del tope', () {
      final layout = PadGridLayout.resolve(
        width: 1200,
        height: 120,
        padSize: 1,
      );
      expect(layout.aspectRatio, lessThanOrEqualTo(PadGridLayout.maxAspectRatio));
    });

    test('una pantalla alta conserva la proporcion sin tocar', () {
      for (final size in [..._allSizes, _autoSize]) {
        final tall = _resolve(_tabletPortrait, size);
        final unknownHeight = PadGridLayout.resolve(
          width: _tabletPortrait.width,
          height: 0,
          padSize: size,
        );
        expect(tall.aspectRatio, unknownHeight.aspectRatio);
      }
    });
  });
}
