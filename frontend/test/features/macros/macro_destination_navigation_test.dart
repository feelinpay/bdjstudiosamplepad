import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdj_studio_sample_pad/core/providers/core_providers.dart';
import 'package:bdj_studio_sample_pad/features/macros/presentation/providers/macro_providers.dart';
import 'package:bdj_studio_sample_pad/features/macros/domain/entities/macro_entity.dart';
import 'package:bdj_studio_sample_pad/features/settings/data/services/settings_service.dart';
import 'package:bdj_studio_sample_pad/features/settings/presentation/providers/settings_provider.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/presentation/providers/pad_providers.dart';
import 'package:bdj_studio_sample_pad/features/workspace/presentation/providers/workspace_providers.dart';

import '../../helpers/mock_audio_engine.dart';

/// Navegación por destino exacto (tipo explorador de archivos):
/// changePage guarda workspace + página, cambia de workspace si hace falta y
/// mantiene/limpia la pila de carpetas como la navegación de la app.
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

  MacroEntity macroWith(List<MacroAction> actions, {int id = 50}) =>
      MacroEntity(
        id: id,
        name: 'nav',
        actions: actions,
        createdAt: DateTime.now(),
      );

  test('changePage con workspaceId cambia de workspace y navega al destino',
      () async {
    final executor = buildExecutor();
    await executor.execute(
      macroWith(const [
        MacroAction(
          type: MacroActionType.changePage,
          params: {'workspaceId': 7, 'pageIndex': 3},
        ),
      ]),
    );
    expect(container.read(currentWorkspaceIdProvider), 7);
    expect(container.read(currentPageIndexProvider), 3);
  });

  test('changePage al workspace actual no cambia workspace', () async {
    container.read(currentWorkspaceIdProvider.notifier).state = 3;
    final executor = buildExecutor();
    await executor.execute(
      macroWith(const [
        MacroAction(
          type: MacroActionType.changePage,
          params: {'workspaceId': 3, 'pageIndex': 4},
        ),
      ]),
    );
    expect(container.read(currentWorkspaceIdProvider), 3);
    expect(container.read(currentPageIndexProvider), 4);
  });

  test('changePage a una carpeta (pageIndex >= 1000) empuja la pila', () async {
    final executor = buildExecutor();
    await executor.execute(
      macroWith(const [
        MacroAction(
          type: MacroActionType.changePage,
          params: {'pageIndex': 1001},
        ),
      ]),
    );
    expect(container.read(folderBackStackProvider), [0]);
    expect(container.read(currentPageIndexProvider), 1001);
  });

  test('changePage a una página raíz limpia la pila de carpetas', () async {
    container.read(folderBackStackProvider.notifier).state = [0, 1001];
    container.read(currentPageIndexProvider.notifier).state = 1001;
    final executor = buildExecutor();
    await executor.execute(
      macroWith(const [
        MacroAction(
          type: MacroActionType.changePage,
          params: {'pageIndex': 2},
        ),
      ]),
    );
    expect(container.read(folderBackStackProvider), isEmpty);
    expect(container.read(currentPageIndexProvider), 2);
  });

  test('triggerPad a una carpeta empuja la pila y navega', () async {
    final executor = buildExecutor();
    await executor.execute(
      macroWith(const [
        MacroAction(
          type: MacroActionType.triggerPad,
          params: {'targetPageIndex': 1002},
        ),
      ]),
    );
    expect(container.read(folderBackStackProvider), [0]);
    expect(container.read(currentPageIndexProvider), 1002);
  });

  test('triggerPad a una página raíz limpia la pila', () async {
    container.read(folderBackStackProvider.notifier).state = [0, 1001];
    container.read(currentPageIndexProvider.notifier).state = 1001;
    final executor = buildExecutor();
    await executor.execute(
      macroWith(const [
        MacroAction(
          type: MacroActionType.triggerPad,
          params: {'targetPageIndex': 1},
        ),
      ]),
    );
    expect(container.read(folderBackStackProvider), isEmpty);
    expect(container.read(currentPageIndexProvider), 1);
  });
}
