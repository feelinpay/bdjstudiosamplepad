import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdj_studio_sample_pad/core/providers/core_providers.dart';
import 'package:bdj_studio_sample_pad/features/macros/presentation/providers/macro_providers.dart';
import 'package:bdj_studio_sample_pad/features/macros/domain/entities/macro_entity.dart';
import 'package:bdj_studio_sample_pad/features/settings/data/services/settings_service.dart';
import 'package:bdj_studio_sample_pad/features/settings/presentation/providers/settings_provider.dart';

import '../../helpers/mock_audio_engine.dart';

/// Regresión para 3.6: las acciones de macro leen `params` con lecturas
/// defensivas. Un JSON importado con parámetros ausentes o de tipo incorrecto
/// (String donde se espera num, o faltante) no debe tumbar la ejecución con un
/// TypeError asíncrono no capturado (execute() se invoca sin `await`).
void main() {
  late ProviderContainer container;
  late MockAudioEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    engine = MockAudioEngine();
    container = ProviderContainer(
      overrides: [
        audioEngineProvider.overrideWithValue(engine),
        settingsServiceProvider.overrideWithValue(
          SettingsService.withPrefs(prefs),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  MacroExecutor buildExecutor() => container.read(macroExecutorProvider);

  test('params incompletos o de tipo incorrecto no tumban la ejecución', () async {
    final executor = buildExecutor();

    final macro = MacroEntity(
      id: 41,
      name: 'Params corruptos',
      actions: const [
        MacroAction(type: MacroActionType.setVolume, params: {}),
        MacroAction(type: MacroActionType.setVolume, params: {'volume': '0.5'}),
        MacroAction(
          type: MacroActionType.setLimiter,
          params: {'value': 123},
        ),
        MacroAction(
          type: MacroActionType.delay,
          params: {'milliseconds': '1'},
        ),
        MacroAction(
          type: MacroActionType.changeWorkspace,
          params: {'workspaceId': '3'},
        ),
        MacroAction(
          type: MacroActionType.triggerPad,
          params: {'targetPageIndex': '1'},
        ),
        MacroAction(
          type: MacroActionType.changePage,
          params: {'destinationType': 5, 'pageIndex': 'x'},
        ),
      ],
      createdAt: DateTime.now(),
    );

    await executor.execute(macro);
  });

  test('valores numéricos válidos se aplican aun viniendo de un JSON', () async {
    final executor = buildExecutor();

    final macro = MacroEntity(
      id: 42,
      name: 'Params válidos',
      actions: const [
        MacroAction(type: MacroActionType.setVolume, params: {'volume': 0.5}),
        MacroAction(
          type: MacroActionType.delay,
          params: {'milliseconds': 30},
        ),
      ],
      createdAt: DateTime.now(),
    );

    await executor.execute(macro);
    expect(engine.globalVolume, 0.5);
  });
}
