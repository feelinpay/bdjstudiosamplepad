import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bdj_studio_sample_pad/features/workspace/presentation/providers/workspace_providers.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/presentation/providers/pad_providers.dart';
import 'package:bdj_studio_sample_pad/features/settings/data/services/settings_service.dart';
import 'package:bdj_studio_sample_pad/features/settings/presentation/providers/settings_provider.dart';

/// Regresión para MA2: al cambiar de workspace, la navegación (página actual
/// + backstack de carpetas) debe reiniciarse para no apuntar a índices de
/// página que pertenecen a otro workspace.
void main() {
  late SettingsService settingsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'last_workspace_id': 1});
    final prefs = await SharedPreferences.getInstance();
    settingsService = SettingsService.withPrefs(prefs);
  });

  testWidgets(
    'switchWorkspaceWithRequestId reinicia página y backstack de carpetas',
    (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWithValue(settingsService),
            currentWorkspaceIdProvider.overrideWith((ref) => 1),
            currentPageIndexProvider.overrideWith((ref) => 0),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      // Simular estar dentro de una carpeta profunda en Workspace 1
      SafeFolderNavigator.openFolder(widgetRef, 0, 2000);
      SafeFolderNavigator.openFolder(widgetRef, 2000, 2001);
      expect(widgetRef.read(currentPageIndexProvider), 2001);
      expect(widgetRef.read(folderBackStackProvider), equals([0, 2000]));

      // Cambiar al Workspace 2 usando el helper seguro
      await switchWorkspaceWithRequestId(widgetRef, 2);

      // La navegación debe reiniciarse en la raíz del nuevo workspace
      expect(widgetRef.read(currentWorkspaceIdProvider), 2);
      expect(widgetRef.read(currentPageIndexProvider), 0);
      expect(widgetRef.read(folderBackStackProvider), isEmpty);
    },
  );

  testWidgets(
    'switchWorkspaceWithRequestId con el MISMO id no toca el request-id '
    '(no rompe la carga en vuelo ni deja el workspace vacío)',
    (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsServiceProvider.overrideWithValue(settingsService),
            currentWorkspaceIdProvider.overrideWith((ref) => 1),
            currentPageIndexProvider.overrideWith((ref) => 0),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      // Simular estar dentro de una carpeta en Workspace 1
      SafeFolderNavigator.openFolder(widgetRef, 0, 2000);
      expect(widgetRef.read(currentPageIndexProvider), 2000);

      final requestIdBefore = widgetRef.read(
        currentWorkspaceRequestIdProvider,
      );

      // Conmutar al MISMO workspace (p.ej. doble switch tras borrar un
      // workspace): no debe clobberear el request-id de la carga en vuelo.
      await switchWorkspaceWithRequestId(widgetRef, 1);

      expect(
        widgetRef.read(currentWorkspaceRequestIdProvider),
        requestIdBefore,
      );
      expect(widgetRef.read(currentWorkspaceIdProvider), 1);
      // La navegación sí se reinicia (página raíz + backstack limpio)
      expect(widgetRef.read(currentPageIndexProvider), 0);
      expect(widgetRef.read(folderBackStackProvider), isEmpty);
    },
  );
}
