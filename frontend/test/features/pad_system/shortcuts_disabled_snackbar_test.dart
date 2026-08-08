import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdj_studio_sample_pad/core/providers/core_providers.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/domain/entities/pad_entity.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/presentation/widgets/pad_grid_view.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/presentation/providers/pad_providers.dart';
import 'package:bdj_studio_sample_pad/features/settings/data/services/settings_service.dart';
import 'package:bdj_studio_sample_pad/features/settings/presentation/providers/settings_provider.dart';
import 'package:bdj_studio_sample_pad/features/desktop/data/key_binding_service.dart';
import 'package:bdj_studio_sample_pad/features/desktop/presentation/providers/desktop_providers.dart';

import '../../helpers/mock_audio_engine.dart';

/// Regresión para 2.5: con los atajos de teclado desactivados, el tile
/// "Asignar tecla" debe bloquear la asignación Y mostrar el aviso (el messenger
/// se captura antes del `safePop`, así el SnackBar no se pierde al cerrar el
/// bottom sheet). La acción "Activar" debe habilitar los atajos y entrar en
/// modo aprendizaje.
void main() {
  const pad = PadEntity(
    id: 'pad_0',
    index: 0,
    label: 'Kick',
    sampleId: 'kick.wav',
  );

  Future<(SharedPreferences, MockAudioEngine)> buildMocks({
    required bool enablePadShortcuts,
  }) async {
    SharedPreferences.setMockInitialValues({
      'enable_pad_shortcuts': enablePadShortcuts,
    });
    final prefs = await SharedPreferences.getInstance();
    return (prefs, MockAudioEngine());
  }

  Widget buildApp(SharedPreferences prefs, MockAudioEngine engine) {
    final settingsService = SettingsService.withPrefs(prefs);
    return ProviderScope(
      overrides: [
        audioEngineProvider.overrideWithValue(engine),
        settingsServiceProvider.overrideWithValue(settingsService),
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier(settingsService),
        ),
        keyBindingServiceProvider.overrideWithValue(
          KeyBindingService(prefs),
        ),
        padPageProvider.overrideWithBuild((ref, notifier) async => [pad]),
      ],
      child: MaterialApp(
        home: Scaffold(body: PadGridView(pageIndex: 0)),
      ),
    );
  }

  testWidgets(
      'desactivado: no asigna, muestra el aviso y su acción Activar habilita el aprendizaje',
      (tester) async {
    final (prefs, engine) = await buildMocks(enablePadShortcuts: false);

    await tester.pumpWidget(buildApp(prefs, engine));
    await tester.pumpAndSettle();

    // Long-press del pad abre el bottom sheet de acciones.
    await tester.longPress(find.text('Kick'));
    await tester.pumpAndSettle();

    final assignTile = find.text('Asignar tecla (teclado)');
    expect(assignTile, findsOneWidget);
    await tester.tap(assignTile);
    await tester.pumpAndSettle();

    // El aviso se muestra (regresión: antes se perdía con el desmontaje del sheet).
    expect(
      find.textContaining('Debes activar "Atajos de teclado en los pads"'),
      findsOneWidget,
    );

    // No hubo asignación: ningún pad en modo aprendizaje.
    final gridContext = tester.element(find.byType(PadGridView));
    final container = ProviderScope.containerOf(gridContext, listen: false);
    expect(container.read(keyLearnPadProvider), isNull);

    // La acción "Activar" enciende los atajos y arranca el aprendizaje.
    await tester.tap(find.text('Activar'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).enablePadShortcuts, isTrue);
    expect(container.read(keyLearnPadProvider), 'pad_0');
  });

  testWidgets('activado: asigna directamente sin aviso', (tester) async {
    final (prefs, engine) = await buildMocks(enablePadShortcuts: true);

    await tester.pumpWidget(buildApp(prefs, engine));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Kick'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Asignar tecla (teclado)'));
    await tester.pumpAndSettle();

    // Sin aviso de atajos desactivados y entrando directo al aprendizaje.
    expect(
      find.textContaining('Debes activar "Atajos de teclado en los pads"'),
      findsNothing,
    );
    final gridContext = tester.element(find.byType(PadGridView));
    final container = ProviderScope.containerOf(gridContext, listen: false);
    expect(container.read(keyLearnPadProvider), 'pad_0');
  });
}
