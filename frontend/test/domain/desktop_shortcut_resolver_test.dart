import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/features/desktop/domain/desktop_shortcut_resolver.dart';

void main() {
  group('DesktopShortcutResolver.resolve (solo controles universales)', () {
    test('Esc = detener todo', () {
      expect(
        DesktopShortcutResolver.resolve(LogicalKeyboardKey.escape),
        DesktopAction.stopAll,
      );
    });
    test('flechas izq/der = navegar paginas', () {
      expect(
        DesktopShortcutResolver.resolve(LogicalKeyboardKey.arrowLeft),
        DesktopAction.prevPage,
      );
      expect(
        DesktopShortcutResolver.resolve(LogicalKeyboardKey.arrowRight),
        DesktopAction.nextPage,
      );
    });
    test('teclas de letras/numeros NO tienen accion por defecto', () {
      expect(
        DesktopShortcutResolver.resolve(LogicalKeyboardKey.digit1),
        DesktopAction.none,
      );
      expect(
        DesktopShortcutResolver.resolve(LogicalKeyboardKey.keyA),
        DesktopAction.none,
      );
      expect(
        DesktopShortcutResolver.resolve(LogicalKeyboardKey.space),
        DesktopAction.none,
      );
    });

    test('una tecla maestra PERSONALIZADA desactiva su tecla por defecto', () {
      // muteAll guardado en ESPACIO: la M por defecto ya no silencia.
      final bindingsMute = {
        LogicalKeyboardKey.space.keyId.toString():
            DesktopShortcutResolver.keyMuteAll,
      };
      expect(
        DesktopShortcutResolver.resolve(
          LogicalKeyboardKey.keyM,
          customBindings: bindingsMute,
        ),
        DesktopAction.none,
      );
      expect(
        DesktopShortcutResolver.resolve(
          LogicalKeyboardKey.space,
          customBindings: bindingsMute,
        ),
        DesktopAction.muteAll,
      );

      // stopAll guardado en Q: el ESC por defecto ya no detiene.
      final bindingsStop = {
        '113': DesktopShortcutResolver.keyStopAll,
      };
      expect(
        DesktopShortcutResolver.resolve(
          LogicalKeyboardKey.escape,
          customBindings: bindingsStop,
        ),
        DesktopAction.none,
      );
      expect(
        DesktopShortcutResolver.resolve(
          LogicalKeyboardKey.keyQ,
          customBindings: bindingsStop,
        ),
        DesktopAction.stopAll,
      );
    });

    test('sin atajos guardados las teclas por defecto siguen activas', () {
      expect(
        DesktopShortcutResolver.resolve(
          LogicalKeyboardKey.escape,
          customBindings: const {},
        ),
        DesktopAction.stopAll,
      );
      expect(
        DesktopShortcutResolver.resolve(
          LogicalKeyboardKey.keyM,
          customBindings: const {},
        ),
        DesktopAction.muteAll,
      );
    });
  });

  group('computePageIndex', () {
    test('next avanza y se acota al maximo', () {
      expect(
        DesktopShortcutResolver.computePageIndex(DesktopAction.nextPage, 0, 3),
        1,
      );
      expect(
        DesktopShortcutResolver.computePageIndex(DesktopAction.nextPage, 2, 3),
        2,
      );
    });
    test('prev no baja de 0', () {
      expect(
        DesktopShortcutResolver.computePageIndex(DesktopAction.prevPage, 0, 3),
        0,
      );
    });
  });
}
