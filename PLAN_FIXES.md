# Plan de corrección — BDJ Studio Sample Pad

Estado inicial: `flutter analyze` limpio · **211 tests pasan, 11 fallan**.
Los 11 fallos NO son tests mal escritos: cada uno reproduce un bug real ya confirmado
ejecutándolo. Los tests se escribieron primero para no arreglar a ciegas.

**Estado actual (sesión 3):** `flutter analyze` limpio · **241 tests pasan, 0 fallan**.
Todas las fases 1–4 están aplicadas y validadas, incluidos los tests de Fase 4 que
faltaban: PANIC/ESC con feedback MIDI (2.1), audio ausente (2.2) y el ida y vuelta
export→import de punta a punta (1.1). Criterio de cierre cumplido.

Sesión 3 — atajos maestros + snackbars (fuera del plan original):
- Regla nueva en `desktop_shortcut_resolver.dart`: si el mapa guardado tiene una tecla
  personalizada para `stopAll`/`muteAll`, el default correspondiente (ESC/M) queda
  desactivado; solo responde la tecla guardada.
- `resetMasterHotkeys()` en `KeyBindingsNotifier` restablece los defaults y persiste;
  botón "Restablecer a las teclas por defecto" en `settings_screen.dart`.
- Crash `StateError: Using "ref" when a widget is about to...` en `_MasterHotkeyTile`:
  los notifiers se capturan antes de `showSnackBar` (ya no se usa `ref` tras el
  desmontaje). Mismo guarda previo en `_retry`/`_selectAudioOutput` (acción "Reintentar").
- ~80 SnackBars sin `duration` ahora llevan `Duration(seconds: 2)` (sin acción) o
  `Duration(seconds: 4)` (con acción) para que no se encolen ni se sientan pegados.

Leyenda: 🔴 pérdida de datos · 🟠 rompe el uso en vivo · 🟡 robustez/limpieza
✅ = ya probado con un test que falla hoy y debe pasar después.

---

## FASE 1 — Pérdida de datos (bloqueante)

### 1.1 🔴 El export de workspace genera un archivo VACÍO ✅
`frontend/lib/core/utils/zip_utils.dart:16`

`zipDirectoryInIsolate` es `void` y no espera ninguna de las tres llamadas
asíncronas de `archive 4.0.9` (`addFile`, `addDirectory`, `close` devuelven
`Future<void>`). `compute()` retorna antes de que se escriba nada.

Comprobado: el `.sppworkspace` se crea, pero al decodificarlo tiene **0 entradas**
— sin `metadata.json` y sin un solo audio. Todo export hecho hasta hoy es irrecuperable.

- Convertir a `Future<void> zipDirectoryInIsolate(...) async` y `await` en las tres.
- `WorkspaceExporter.exportWorkspace` ya hace `await compute(...)`: sin cambios.
- Verificar el `.sppworkspace` resultante reabriéndolo con el importador.

### 1.2 🔴 La limpieza de huérfanos borra audios en uso ✅
`frontend/lib/core/services/local_audio_storage_service.dart:270`

`cleanUnusedAudioFiles` construye el set de "activos" filtrando **solo** las rutas
con prefijo `app_local://`. Los pads de versiones anteriores guardan ruta absoluta:
sus audios no entran al set, se ven como huérfanos y se borran con el pad usándolos.
`autoCleanOrphans` se ejecuta tras **cada borrado de pad**, así que dispara solo.

- Normalizar toda ruta activa a relativa contra `mediaDirectory()` antes de comparar
  (aceptar tanto la URI como la ruta absoluta), no descartar las que no tienen prefijo.

### 1.3 🔴 Renombrar un workspace deja los pads mudos en Windows ✅
`frontend/lib/core/services/local_audio_storage_service.dart:381`

Hay **dos formatos** de `samplePath` conviviendo:
- `importAudioFile` / `importAudioBytes` usan `p.join` → `app_local://Set A\kick.wav` (Windows)
- `WorkspaceImporter` lo arma a mano → `app_local://Set A/kick.wav`

`migrateWorkspaceSamplePaths` busca por `app_local://<ws>/` y **no encuentra** los del
primer grupo: devuelve 0 migrados. La carpeta física se renombra, el pad sigue
apuntando al nombre viejo → se queda sin sonido. Tus propios logs lo muestran:
`...\media\Elementos/Aguila.wav` (separadores mezclados).

- Normalizar a `/` en `_resolveUniqueFilePath` (fuente única del formato).
- Migración de datos existentes: reescribir `\`→`/` en los `samplePath` al abrir la DB.
- `resolvePath` ya tolera ambos (`p.join` normaliza), así que la migración es segura.

---

## FASE 2 — Lo que reportaste que se rompe en vivo

### 2.1 🟠 Presiono ESC y el pad sigue encendido ✅ (tu reporte)
`desktop_shortcuts.dart:129` · `live_control_bar.dart:95` · `soloud_audio_engine.dart:711`

Raíz: `stopAll()` y `stop()` **nunca emiten `onSoundFinished`**. El parámetro
`stop(id, {bool notify = true})` está declarado, se pasa desde 4 sitios… y el cuerpo
del método **no lo usa jamás**. Como `PadPageNotifier` solo vuelve a `idle` al escuchar
ese stream, el pad se queda iluminado hasta que algo más lo toque.

- Hacer que `stop()` emita `_soundFinishedController.add(id)` cuando `notify == true`.
- `stopAll()` debe notificar cada id detenido.
- Cuidado: `pad_settings_dialog` y `onPadDown` pasan `notify: false` a propósito
  (preescucha y retrigger de oneShot) — ese camino debe seguir silencioso.
- Añadir `forceStopAll()` en el notifier para que el PANIC limpie también
  `padVelocityProvider` y el feedback MIDI.

### 2.2 🟠 El pad queda encendido si el audio no existe
`soloud_audio_engine.dart:571`

Cuando `play()` no encuentra la fuente en caché hace `return` **sin** emitir
`onSoundFinished`, a diferencia de los otros dos caminos de error que sí lo hacen.
`onPadDown` ya puso el pad en `playing` → se queda encendido para siempre.
En tus logs: `play: SOURCE NOT FOUND in cache for id=410` justo tras un doble clic.

- Emitir `onSoundFinished` en ese `return` (igualar a los otros caminos de error).
- Causa secundaria: `loadAudio` retorna de inmediato si el id ya está en vuelo
  (`_loadingIds`), así que el `await` de `onPadDown` no espera de verdad. Hacer que
  las llamadas concurrentes compartan el mismo `Future` en lugar de salir en falso.

### 2.3 🟠 Demasiados logs (tu reporte) ✅
`soloud_audio_engine.dart` (~25 `debugPrint`) · `pad_providers.dart`

Hay `debugPrint` en las rutas más calientes: uno por pad en `isLoaded`, `loadAudio`,
`play`, `stop`, `onEvict` y **uno cada 25 ms** en el polling. Con 500+ pads eso son
miles de líneas por carpeta abierta, y `debugPrint` serializa en el hilo de UI:
además de ruido, cuesta latencia en vivo.

- Introducir `AudioLog.verbose` (const `bool.fromEnvironment('BDJ_AUDIO_VERBOSE')`)
  y envolver todos los `debugPrint` del motor y de `onPadDown`.
- Dejar sin condición solo los eventos de ciclo de vida: init, cambio de dispositivo,
  errores reales de carga.
- Corregir de paso el typo `[SoLoom]` → `[SoLoud]`.

### 2.4 🟠 Preescucha del editor sincronizada con la canción (tu reporte) ✅
`pad_settings_dialog.dart` · `waveform_editor_widget.dart`

Objetivo: al mover INICIO/FIN y pulsar "Escuchar edición", el DJ debe oír exactamente
la región recortada y ver el cursor recorrerla en tiempo real.

- El cursor se mueve con `_previewPositionTimer`; ligarlo a `getPosition(_previewSoundId)`
  del motor en vez de a un contador propio, para que no derive.
- En modo Loop la preescucha usa `Timer.periodic(loopDuration)` **junto con**
  `setLooping(true)`: dos relojes distintos que se desfasan. Usar solo el reseteo por
  `seek` del timer, o solo el loop nativo con `setLoopPoint`.
- Reiniciar la preescucha al soltar cualquier handle (ya existe `_restartWaveformPreview`,
  falta engancharlo a los botones `-50/-10/+10/+50`).
- Garantizar que "Cancelar" no persista nada y detenga la preescucha (hoy `dispose`
  lo hace, confirmar que el botón también).

### 2.5 🟡 Mensaje al asignar atajo con la opción desactivada (tu reporte) ✅
`pad_grid_view.dart:545`

El mensaje **ya está escrito** y el `return` que impide asignar es correcto. El problema
es que no llega a verse: `ConcurrencyShield.safePop(ctx)` cierra el bottom sheet en la
línea anterior y el `ScaffoldMessenger` que lo recibe se desmonta con él.

- Capturar `ScaffoldMessenger.of(context)` **antes** del `safePop`, o mostrar el aviso
  con el messenger raíz.
- Mejor aún: ofrecer acción directa — SnackBar con botón "Activar" que ponga
  `setEnablePadShortcuts(true)` y siga con el aprendizaje de tecla.
- Mismo tratamiento en `settings_screen.dart` ("CAMBIAR TECLA").

---

## FASE 3 — Robustez del motor

### 3.1 🟠 Dos `initialize()` concurrentes cuelgan la app ✅
`soloud_audio_engine.dart:82`

```dart
if (_initCompleter?.isCompleted == true) return _initCompleter!.future;
```
La condición está **invertida**. Debe reutilizarse el future cuando la inicialización
está *en vuelo* (no completada). Tal como está, el segundo llamador crea un
`Completer` nuevo y pisa `_initCompleter`; cuando el primer `_doInitialize` termina,
completa el completer **nuevo** — y el original **nunca se completa**.

Comprobado: `Future.wait([engine.initialize(), engine.initialize()])` no resuelve nunca
(timeout a los 5 s). El arranque se queda en la pantalla de carga.

- Invertir a `if (_initCompleter != null && !_initCompleter!.isCompleted)`.
- `_doInitialize` recrea `_loadedSounds` en cada intento sin liberar el anterior:
  liberar las fuentes antes de reasignar (fuga en cada reintento).

### 3.2 🟡 `selectOutputDevice` con un dispositivo desconectado ✅
`soloud_audio_engine.dart:353` — `devices.firstWhere((d) => d.id == deviceId)` sin
`orElse` lanza `StateError`; el `finally` limpia `_isChangingDevice` pero
`_engineState` **queda atascado en `changingDevice`**.

- Añadir `orElse` → caer al dispositivo por defecto y devolver el aviso al usuario.

### 3.3 🟡 Fuga de `AudioSource` nativo en `LruCache.remove` ✅
`lru_cache.dart:52` — `remove()` es el único camino que saca una entrada **sin** llamar
`onEvict`, que es justo quien libera el recurso nativo. `loadAudio` lo usa en el camino
de colisión de caché (hoy compensa liberando a mano; frágil).

- Llamar `onEvict` en `remove()` y quitar la liberación manual duplicada.

### 3.4 🟡 Limpieza de `dispose()`
`soloud_audio_engine.dart:985`
- `_loadedSounds.clear()` dispara `onEvict` → `_scheduleDisposeSource` → **reprograma
  un Timer que se acababa de cancelar**, que corre 100 ms después de `deinit()`.
- `play()` puede llamar `_soundFinishedController.add()` sobre un controller ya cerrado.
- `play()` toca `_loadedSounds` (campo `late`) antes del `try` → `LateInitializationError`
  si llega un golpe de pad o una nota MIDI antes de terminar el arranque.

### 3.5 🟡 Código muerto ✅
- `_changeDeviceInternal` y `_changeDeviceSync` son **idénticos** carácter por carácter.
- `license_manager.dart:285`: `if (data.getUint8(1) != 1)` es inalcanzable, ya cubierto
  por la condición de la línea 280. El mensaje "pertenece a otro producto" nunca sale.
- `_activateOffline` es un envoltorio de una sola línea sobre `_activateOfflineV2`.

### 3.6 🟡 Macros: casts sin protección ✅
`macro_providers.dart:260,288,299` — `as num`, `as String`, `as int` sobre `params`
lanzan si la macro fue importada con un JSON incompleto. `execute()` se invoca
**sin `await`** desde `onPadDown`, así que la excepción queda como error asíncrono no
capturado. `importMacros` tampoco valida el archivo.

- Lecturas defensivas con valor por defecto + `try/catch` por acción.
- Validar el JSON en `importMacros` y reportar cuántas macros se descartaron.

---

## FASE 4 — Cobertura de tests ("todo tipo de escenarios")

Ya escrito (5 archivos, 66 tests nuevos):

| Archivo | Cubre |
|---|---|
| `test/core/utils/zip_utils_test.dart` | Integridad del export: existe, contiene metadata + audios, bytes intactos, media vacío |
| `test/core/utils/lru_cache_test.dart` | Desalojo LRU, renovación por uso, `onEvict` en cada camino, resize, clear/remove |
| `test/core/utils/concurrency_shield_test.dart` | Mutex, liberación ante excepción, throttle, ráfaga de clics, navegación, request-ids |
| `test/core/services/sample_path_consistency_test.dart` | Formato de `samplePath`, duplicados, migración al renombrar, limpieza de huérfanos |
| `test/features/audio_engine/soloud_engine_lifecycle_test.dart` | Init idempotente y concurrente, API antes de inicializar, dispose |

Pendiente de añadir, en paralelo a cada fase: *(nada — los tres ya están escritos y en verde)*

Ya cubierto (nuevos en esta sesión):

| Test | Cubre |
|---|---|
| `test/features/pad_system/panic_stop_all_test.dart` | 2.1: PANIC y ESC devuelven los pads `playing` a `idle` y apagan el feedback MIDI (velocity + nota de apagado) |
| `test/features/pad_system/missing_audio_test.dart` | 2.2: pad sin sample no se enciende; sample inexistente vuelve a `idle` |
| `test/workspace_export_import_roundtrip_test.dart` | 1.1: export→import de un workspace con carpetas anidadas reproduce la misma jerarquía y los audios en disco |
| `test/features/macros/macro_params_robustness_test.dart` | 3.6: `params` incompletos o de tipo incorrecto no tumban `execute()`; valores válidos se aplican |
| `test/features/pad_system/shortcuts_disabled_snackbar_test.dart` | 2.5: con atajos desactivados no asigna, muestra el aviso y "Activar" habilita + aprendizaje; activado asigna directo |
| `test/audio/audio_engine_port_test.dart` (nuevo caso) | 2.1: contrato `stop(notify: true)` emite, `notify: false` no |
| `test/features/audio_engine/audio_engine_recovery_test.dart` (ya existía) | 3.2: `selectOutputDevice` con id inexistente cae al default sin `StateError` |
| `test/features/pad_system/preview_playback_test.dart` (ya existía) | 2.4: el cursor sigue a `getPosition` (no a un reloj propio) y la región recortada hace wrap correcto |

Criterio de cierre: `flutter analyze` limpio y **la suite entera en verde**.

---

## Orden de ejecución sugerido

1. **Fase 1** entera — cada día que pasa se pueden estar borrando audios (1.2).
2. **3.1** — el cuelgue de arranque afecta a todos los usuarios.
3. **Fase 2** — tus cuatro reportes; 2.1 y 2.3 son los de mayor impacto percibido.
4. **Fase 3** restante y **Fase 4**.

Las fases 1 y 2 son independientes entre sí y se pueden repartir. La 2.1 y la 2.2
tocan el mismo método (`stop`/`play`), conviene hacerlas juntas.
