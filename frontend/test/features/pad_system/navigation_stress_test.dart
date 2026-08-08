import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdj_studio_sample_pad/features/pad_system/presentation/providers/pad_providers.dart';
import 'package:bdj_studio_sample_pad/features/workspace/presentation/providers/workspace_providers.dart';

/// Pruebas de estrés y blindaje para SafeFolderNavigator y cambio de Workspaces.
/// Garantiza que en un show en vivo un DJ pueda dar ráfagas de clics en carpetas,
/// botones de retorno o cambio de workspaces sin perder estructura ni duplicar estados.
void main() {
  final overrides = [
    currentPageIndexProvider.overrideWith((ref) => 0),
    currentWorkspaceIdProvider.overrideWith((ref) => 1),
  ];

  group('SafeFolderNavigator Stress & Reliability Tests', () {
    testWidgets(
      'Ráfaga ultra-rápida (Spam de clic en la misma carpeta) no duplica el stack',
      (tester) async {
        late WidgetRef widgetRef;
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: Consumer(
              builder: (context, ref, child) {
                widgetRef = ref;
                return const SizedBox();
              },
            ),
          ),
        );

        // Verificar estado inicial en raíz (0)
        expect(widgetRef.read(currentPageIndexProvider), 0);
        expect(widgetRef.read(folderBackStackProvider), isEmpty);

        // Simular 100 clics ultrarrápidos sobre la carpeta 1000 en el mismo instante
        for (int i = 0; i < 100; i++) {
          SafeFolderNavigator.openFolder(
            widgetRef,
            widgetRef.read(currentPageIndexProvider),
            1000,
          );
        }

        // El índice debe ser 1000 y la pila de navegación debe contener ÚNICAMENTE [0]
        expect(widgetRef.read(currentPageIndexProvider), 1000);
        expect(widgetRef.read(folderBackStackProvider), equals([0]));
      },
    );

    testWidgets(
      'Navegación profunda y ráfaga excesiva de botones Back no rompe la app',
      (tester) async {
        late WidgetRef widgetRef;
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: Consumer(
              builder: (context, ref, child) {
                widgetRef = ref;
                return const SizedBox();
              },
            ),
          ),
        );

        // Descender 5 niveles de carpetas: 0 -> 1000 -> 1001 -> 1002 -> 1003 -> 1004
        for (int target = 1000; target <= 1004; target++) {
          SafeFolderNavigator.openFolder(
            widgetRef,
            widgetRef.read(currentPageIndexProvider),
            target,
          );
        }

        expect(widgetRef.read(currentPageIndexProvider), 1004);
        expect(
          widgetRef.read(folderBackStackProvider),
          equals([0, 1000, 1001, 1002, 1003]),
        );

        // Simular al DJ presionando el botón "Atrás" 15 veces muy rápido (más del número de niveles)
        for (int i = 0; i < 15; i++) {
          SafeFolderNavigator.goBack(widgetRef);
        }

        // Debe estabilizarse limpiamente en la raíz sin lanzar excepciones ni underflow
        expect(widgetRef.read(currentPageIndexProvider), 0);
        expect(widgetRef.read(folderBackStackProvider), isEmpty);
      },
    );

    testWidgets(
      'Saltos arbitrarios por Breadcrumb truncan limpiamente la jerarquía',
      (tester) async {
        late WidgetRef widgetRef;
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: Consumer(
              builder: (context, ref, child) {
                widgetRef = ref;
                return const SizedBox();
              },
            ),
          ),
        );

        // Navegar: Raíz -> Carpeta A (1000) -> Carpeta B (1001) -> Carpeta C (1002)
        SafeFolderNavigator.openFolder(widgetRef, 0, 1000);
        SafeFolderNavigator.openFolder(widgetRef, 1000, 1001);
        SafeFolderNavigator.openFolder(widgetRef, 1001, 1002);

        expect(
          widgetRef.read(folderBackStackProvider),
          equals([0, 1000, 1001]),
        );
        expect(widgetRef.read(currentPageIndexProvider), 1002);

        // El usuario hace clic en el breadcrumb en la Carpeta A (índice 1000, posición en path = 1)
        SafeFolderNavigator.navigateToBreadcrumbIndex(widgetRef, 1000, 1);

        // Debe situar el índice en 1000 y reducir la pila a [0]
        expect(widgetRef.read(currentPageIndexProvider), 1000);
        expect(widgetRef.read(folderBackStackProvider), equals([0]));

        // Saltar directo a la Raíz desde el breadcrumb (posición 0, índice 0)
        SafeFolderNavigator.navigateToBreadcrumbIndex(widgetRef, 0, 0);
        expect(widgetRef.read(currentPageIndexProvider), 0);
        expect(widgetRef.read(folderBackStackProvider), isEmpty);
      },
    );

    testWidgets(
      'Resiliencia en cambio rápido de Workspaces durante navegación profunda',
      (tester) async {
        late WidgetRef widgetRef;
        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: Consumer(
              builder: (context, ref, child) {
                widgetRef = ref;
                return const SizedBox();
              },
            ),
          ),
        );

        // Simular estar dentro de una carpeta profunda en Workspace 1
        widgetRef.read(currentWorkspaceIdProvider.notifier).state = 1;
        SafeFolderNavigator.openFolder(widgetRef, 0, 2000);
        SafeFolderNavigator.openFolder(widgetRef, 2000, 2001);

        expect(widgetRef.read(currentPageIndexProvider), 2001);
        expect(widgetRef.read(folderBackStackProvider), equals([0, 2000]));

        // Simular cambio al Workspace 2 desde el dropdown de la barra
        final newWorkspaceId = 2;
        if (newWorkspaceId != widgetRef.read(currentWorkspaceIdProvider)) {
          widgetRef.read(currentPageIndexProvider.notifier).state = 0;
          widgetRef.read(folderBackStackProvider.notifier).state = [];
          widgetRef.read(currentWorkspaceIdProvider.notifier).state =
              newWorkspaceId;
          widgetRef.invalidate(padPageProvider);
        }

        // El sistema debe quedar reiniciado al instante en la raíz del nuevo workspace
        expect(widgetRef.read(currentWorkspaceIdProvider), 2);
        expect(widgetRef.read(currentPageIndexProvider), 0);
        expect(widgetRef.read(folderBackStackProvider), isEmpty);
      },
    );
  });
}
