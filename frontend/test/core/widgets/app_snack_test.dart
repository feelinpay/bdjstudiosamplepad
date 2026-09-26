import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/widgets/app_snack.dart';

void main() {
  group('AppSnack Widget & Unit Tests', () {
    test('Static architecture guard: No raw SnackBar() instantiation outside app_snack.dart', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final forbiddenDirectCalls = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normalizedPath = entity.path.replaceAll('\\', '/');
          if (normalizedPath.endsWith('core/widgets/app_snack.dart')) {
            continue;
          }

          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            // Ignore single-line comments
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) {
              continue;
            }
            if (line.contains('SnackBar(')) {
              forbiddenDirectCalls.add('$normalizedPath:${i + 1}: $trimmed');
            }
          }
        }
      }

      expect(
        forbiddenDirectCalls,
        isEmpty,
        reason:
            'All SnackBars must be shown via AppSnack.show(...) to guarantee persist: false, '
            'showCloseIcon: true, and proper contrast across Flutter 3.44+.\n'
            'Found direct SnackBar() instantiations:\n${forbiddenDirectCalls.join('\n')}',
      );
    });

    testWidgets('AppSnack.show configures persist: false and showCloseIcon: true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnack.show(
                    context,
                    'Operación exitosa',
                    action: SnackBarAction(
                      label: 'Deshacer',
                      onPressed: () {},
                    ),
                  );
                },
                child: const Text('Show Snack'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Snack'));
      await tester.pump(); // Start animation

      expect(find.byType(SnackBar), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));

      // Key checks for Flutter 3.44+ persist bug:
      expect(snackBar.persist, isFalse, reason: 'Must explicitly force persist: false even when action != null');
      expect(snackBar.showCloseIcon, isTrue, reason: 'Must show close icon for instant user dismissal');
      expect(find.text('Operación exitosa'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);
    });

    testWidgets('AppSnack.show clears previous snackbars before showing new one', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => AppSnack.show(context, 'Mensaje 1'),
                    child: const Text('Show 1'),
                  ),
                  ElevatedButton(
                    onPressed: () => AppSnack.show(context, 'Mensaje 2'),
                    child: const Text('Show 2'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show 1'));
      await tester.pump();
      expect(find.text('Mensaje 1'), findsOneWidget);

      await tester.tap(find.text('Show 2'));
      await tester.pump();
      expect(find.text('Mensaje 1'), findsNothing);
      expect(find.text('Mensaje 2'), findsOneWidget);
    });

    testWidgets('SnackBarDismissNavigatorObserver clears active snackbars on route change', (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final observer = SnackBarDismissNavigatorObserver(
        scaffoldMessengerKey: messengerKey,
      );

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messengerKey,
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  AppSnack.show(context, 'Alerta en pantalla 1');
                },
                child: const Text('Trigger Snack'),
              ),
            ),
          ),
        ),
      );

      // Trigger snackbar on Screen 1
      await tester.tap(find.text('Trigger Snack'));
      await tester.pump();
      expect(find.text('Alerta en pantalla 1'), findsOneWidget);

      // Push Screen 2
      final BuildContext currentContext = tester.element(find.text('Trigger Snack'));
      Navigator.of(currentContext).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(
            body: Text('Pantalla 2'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen 2 is visible and the snackbar was dismissed by the observer
      expect(find.text('Pantalla 2'), findsOneWidget);
      expect(find.text('Alerta en pantalla 1'), findsNothing);

      // Pop back to Screen 1
      Navigator.of(tester.element(find.text('Pantalla 2'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('Trigger Snack'), findsOneWidget);
      expect(find.text('Alerta en pantalla 1'), findsNothing);
    });

    testWidgets('SnackBar remains visible when a Dialog is dismissed (PopupRoute does not clear SnackBar)', (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final observer = SnackBarDismissNavigatorObserver(
        scaffoldMessengerKey: messengerKey,
      );

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messengerKey,
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  await showDialog<void>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Diálogo de Confirmación'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dCtx).pop(),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                  if (context.mounted) {
                    AppSnack.show(context, 'Operación completada con éxito');
                  }
                },
                child: const Text('Abrir Diálogo'),
              ),
            ),
          ),
        ),
      );

      // Abrir diálogo
      await tester.tap(find.text('Abrir Diálogo'));
      await tester.pumpAndSettle();
      expect(find.text('Diálogo de Confirmación'), findsOneWidget);

      // Cerrar diálogo (pop del DialogRoute)
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      // Verificar que el diálogo se cerró y el SnackBar sigue visible
      expect(find.text('Diálogo de Confirmación'), findsNothing);
      expect(find.text('Operación completada con éxito'), findsOneWidget);
    });

    testWidgets('SnackBar shown before Dialog dismiss stays visible after Dialog pop', (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final observer = SnackBarDismissNavigatorObserver(
        scaffoldMessengerKey: messengerKey,
      );

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messengerKey,
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Procesando'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            AppSnack.show(dCtx, 'Éxito en proceso');
                            Navigator.of(dCtx).pop();
                          },
                          child: const Text('Terminar'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Procesar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Procesar'));
      await tester.pumpAndSettle();
      expect(find.text('Procesando'), findsOneWidget);

      await tester.tap(find.text('Terminar'));
      await tester.pumpAndSettle();

      expect(find.text('Procesando'), findsNothing);
      expect(find.text('Éxito en proceso'), findsOneWidget);
    });
  });
}
