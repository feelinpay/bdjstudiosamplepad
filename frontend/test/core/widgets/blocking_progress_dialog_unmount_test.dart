import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bdj_studio_sample_pad/core/widgets/blocking_progress_dialog.dart';

/// Regresión: al importar la primera carpeta en un workspace vacío, el botón
/// que abre el diálogo vive en el estado vacío del grid. En cuanto se crea el
/// primer pad ese widget se desmonta y el diálogo "Importando carpeta..." se
/// quedaba abierto para siempre porque su cierre dependía de `context.mounted`.
void main() {
  Widget host(
    ValueNotifier<bool> openerVisible,
    void Function(BuildContext ctx) onOpen,
  ) {
    return MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: openerVisible,
          builder: (_, visible, __) => visible
              ? Builder(
                  builder: (ctx) => TextButton(
                    onPressed: () => onOpen(ctx),
                    child: const Text('abrir'),
                  ),
                )
              : const Text('grid'),
        ),
      ),
    );
  }

  testWidgets('show(): el cierre funciona aunque el widget que lo abrió ya no exista',
      (tester) async {
    final openerVisible = ValueNotifier(true);
    late void Function() close;
    await tester.pumpWidget(host(openerVisible, (ctx) {
      close = BlockingProgressDialog.show(
        ctx,
        title: 'Importando carpeta...',
        controller: BlockingProgressController(),
      );
    }));

    await tester.tap(find.text('abrir'));
    await tester.pump();
    expect(find.text('Importando carpeta...'), findsOneWidget);

    openerVisible.value = false; // el estado vacío se reemplaza por el grid
    await tester.pump();

    close();
    close(); // idempotente: no debe cerrar ninguna otra ruta
    await tester.pumpAndSettle();

    expect(find.text('Importando carpeta...'), findsNothing);
    expect(find.text('grid'), findsOneWidget);
  });

  testWidgets('run(): el diálogo se cierra al terminar la tarea aunque el contexto se desmonte',
      (tester) async {
    final openerVisible = ValueNotifier(true);
    final task = Completer<void>();
    await tester.pumpWidget(host(openerVisible, (ctx) {
      BlockingProgressDialog.run<void>(
        ctx,
        title: 'Importando workspace...',
        task: (_) => task.future,
      );
    }));

    await tester.tap(find.text('abrir'));
    await tester.pump();
    expect(find.text('Importando workspace...'), findsOneWidget);

    openerVisible.value = false;
    await tester.pump();

    task.complete();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Importando workspace...'), findsNothing);
    expect(find.text('grid'), findsOneWidget);
  });
}
