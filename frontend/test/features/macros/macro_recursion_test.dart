import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bdj_studio_sample_pad/features/macros/presentation/providers/macro_providers.dart';
import 'package:bdj_studio_sample_pad/features/macros/domain/entities/macro_entity.dart';

/// Regresión para MA1: una macro en ejecución no debe re-ejecutarse (ni a sí
/// misma ni a través de cadenas que la vuelvan a invocar), evitando recursión
/// infinita que congelaría la UI.
void main() {
  MacroExecutor buildExecutor() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(macroExecutorProvider);
  }

  test('no re-ejecuta una macro que ya está en ejecución', () async {
    final executor = buildExecutor();

    // Macro con acción delay (300ms): mientras la primera ejecución está en
    // curso, una segunda invocación de la misma macro debe descartarse.
    final macro = MacroEntity(
      id: 7,
      name: 'Loop infinito',
      actions: const [
        MacroAction(
          type: MacroActionType.delay,
          params: {'milliseconds': 500},
        ),
      ],
      createdAt: DateTime.now(),
    );

    final first = executor.execute(macro);
    final second = executor.execute(macro);

    final sw = Stopwatch()..start();
    await second;
    // La segunda llamada debe retornar casi al instante (guard activo). 
    // Ampliado a 300ms para entornos CI muy lentos (macOS).
    expect(sw.elapsedMilliseconds, lessThan(300));

    // La primera debe completarse después (espera de la acción delay).
    final firstSw = Stopwatch()..start();
    await first;
    expect(firstSw.elapsedMilliseconds, greaterThanOrEqualTo(200));
  });

  test('una macro terminada puede volver a ejecutarse', () async {
    final executor = buildExecutor();

    final macro = MacroEntity(
      id: 8,
      name: 'Reutilizable',
      actions: const [
        MacroAction(
          type: MacroActionType.delay,
          params: {'milliseconds': 10},
        ),
      ],
      createdAt: DateTime.now(),
    );

    await executor.execute(macro);
    // Tras terminar, el guard se libera y la ejecución siguiente es válida.
    await executor.execute(macro);
  });
}
