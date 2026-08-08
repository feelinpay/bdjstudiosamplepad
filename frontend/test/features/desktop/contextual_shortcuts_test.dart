import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdj_studio_sample_pad/features/desktop/data/key_binding_service.dart';
import 'package:bdj_studio_sample_pad/features/desktop/domain/desktop_shortcut_resolver.dart';
import 'package:bdj_studio_sample_pad/features/desktop/presentation/providers/desktop_providers.dart';

void main() {
  late KeyBindingService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = KeyBindingService(await SharedPreferences.getInstance());
  });

  group('Atajos aislados por workspace y vista', () {
    test(
      'la misma tecla se puede reutilizar en raíces de workspaces distintos',
      () async {
        final notifier = KeyBindingsNotifier(service);

        await notifier.bind('49', 'pad_workspace_a', workspaceId: 10);
        await notifier.bind('49', 'pad_workspace_b', workspaceId: 20);

        expect(
          notifier.padForKey(workspaceId: 10, pageIndex: 0, keyId: '49'),
          'pad_workspace_a',
        );
        expect(
          notifier.padForKey(workspaceId: 20, pageIndex: 0, keyId: '49'),
          'pad_workspace_b',
        );
      },
    );

    test('la misma tecla se puede reutilizar en carpetas diferentes', () async {
      final notifier = KeyBindingsNotifier(service);

      await notifier.bind('49', 'pad_raiz', workspaceId: 10);
      await notifier.bind(
        '49',
        'pad_halloween',
        workspaceId: 10,
        pageIndex: 1000,
      );

      expect(
        notifier.padForKey(workspaceId: 10, pageIndex: 0, keyId: '49'),
        'pad_raiz',
      );
      expect(
        notifier.padForKey(workspaceId: 10, pageIndex: 1000, keyId: '49'),
        'pad_halloween',
      );
    });

    test(
      'una tecla de pad no se filtra desde el formato legado sin ámbito',
      () async {
        // Simula una asignación de una versión anterior que no tenía workspace.
        await service.save({'49': 'pad_antiguo'});
        final reloaded = KeyBindingsNotifier(service);

        expect(
          reloaded.padForKey(workspaceId: 10, pageIndex: 0, keyId: '49'),
          isNull,
        );
      },
    );

    test('reasignar dentro de la misma vista sustituye solo ese pad', () async {
      final notifier = KeyBindingsNotifier(service);
      await notifier.bind('81', 'pad_a', workspaceId: 10, pageIndex: 1000);
      await notifier.bind('81', 'pad_b', workspaceId: 10, pageIndex: 1000);

      expect(
        notifier.padForKey(workspaceId: 10, pageIndex: 1000, keyId: '81'),
        'pad_b',
      );
      expect(
        notifier.hasBinding('pad_a', workspaceId: 10, pageIndex: 1000),
        isFalse,
      );
    });

    test('Panic Stop y Mute All son globales', () async {
      final notifier = KeyBindingsNotifier(service);
      final stopKey = LogicalKeyboardKey.keyQ.keyId.toString();
      final muteKey = LogicalKeyboardKey.keyW.keyId.toString();
      await notifier.bind(
        stopKey,
        DesktopShortcutResolver.keyStopAll,
        workspaceId: 10,
      );
      await notifier.bind(
        muteKey,
        DesktopShortcutResolver.keyMuteAll,
        workspaceId: 20,
      );

      expect(notifier.state[stopKey], DesktopShortcutResolver.keyStopAll);
      expect(notifier.state[muteKey], DesktopShortcutResolver.keyMuteAll);
      expect(
        DesktopShortcutResolver.resolve(
          LogicalKeyboardKey.keyQ,
          customBindings: notifier.state,
        ),
        DesktopAction.stopAll,
      );
      expect(
        DesktopShortcutResolver.resolve(
          LogicalKeyboardKey.keyW,
          customBindings: notifier.state,
        ),
        DesktopAction.muteAll,
      );
    });

    test(
      'una acción global libera esa tecla de todos los workspaces',
      () async {
        final notifier = KeyBindingsNotifier(service);
        await notifier.bind('113', 'pad_a', workspaceId: 10);
        await notifier.bind('113', 'pad_b', workspaceId: 20);

        await notifier.bind(
          '113',
          DesktopShortcutResolver.keyStopAll,
          workspaceId: 10,
        );

        expect(notifier.state['113'], DesktopShortcutResolver.keyStopAll);
        expect(
          notifier.padForKey(workspaceId: 10, pageIndex: 0, keyId: '113'),
          isNull,
        );
        expect(
          notifier.padForKey(workspaceId: 20, pageIndex: 0, keyId: '113'),
          isNull,
        );
      },
    );

    test(
      'una tecla ya asignada a una acción global no se roba desde un pad',
      () async {
        final notifier = KeyBindingsNotifier(service);
        await notifier.bind(
          '113',
          DesktopShortcutResolver.keyMuteAll,
          workspaceId: 10,
        );

        final result = await notifier.bind('113', 'pad_a', workspaceId: 20);
        expect(result, isFalse);
        expect(notifier.state['113'], DesktopShortcutResolver.keyMuteAll);
      },
    );

    test('las teclas reservadas no se asignan a pads', () async {
      final notifier = KeyBindingsNotifier(service);
      final result = await notifier.bind(
        LogicalKeyboardKey.escape.keyId.toString(),
        'pad_a',
        workspaceId: 10,
      );
      expect(result, isFalse);
    });
  });
}
