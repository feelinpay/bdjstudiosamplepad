# Auditoría de rendimiento y arranque: BDJ Studio Sample Pad

## Alcance y método

- **Código auditado:** el último commit de `main` en GitHub (`a40a74a`). El `lib/main.dart` local tiene el mismo tamaño, así que el código coincide con lo que hay en la máquina.
- **Método:** análisis estático completo del flujo de arranque, los servicios, el motor de audio (incluido el C++ de `third_party/flutter_soloud`), la base de datos Isar y la UI.
- **Qué no se pudo medir:** no hay Flutter ni dispositivos en el entorno, así que **no hay tiempos medidos**. Las cifras en ms/MB salen del coste de cada operación, no de un profiler. La sección H dice qué medir para confirmarlas.
- **Qué no se pudo leer:** `bdj_license_core` es un repositorio privado. No se revisó `Spp3Token.verify` por dentro.

---

## A. Resumen ejecutivo

**Estado general:** la arquitectura de arranque por fases con presupuestos de tiempo está bien planteada (fallos visibles, reintento, diagnóstico). El problema es **qué** se hace dentro de esas fases y **en qué hilo**.

**Severidad del congelamiento: crítica.** Hay tres causas raíz independientes que se suman:

1. **La fase "Abriendo biblioteca…" es una reconciliación completa del disco.** No es solo abrir Isar. `openAppDatabase()` recorre recursivamente toda la carpeta de audio, comprueba cada pad contra el disco y hace inserciones en transacciones individuales. Además reescribe todas las páginas de cada workspace. Todo eso ocurre antes de pintar la UI. **El coste crece con el tamaño de la biblioteca**: por eso la app abre bien al principio y cada vez peor con el uso.
2. **El motor de audio bloquea el hilo de UI con llamadas FFI síncronas.** Enumerar dispositivos crea y destruye un contexto de audio completo cada vez, y se hace 3–4 veces al arrancar. Luego se abre el dispositivo y, en escritorio, se reabre sin necesidad.
   - En Android, el watchdog nativo espera hasta 5 s por intento en el hilo de UI, y hay 3 intentos. Son hasta 15 s con la animación congelada.
   - Los `.timeout()` de Dart **no pueden dispararse** mientras el hilo está bloqueado.
3. **Justo después de mostrar los pads llega una ráfaga de cargas de audio sin límite.** Cada pad de la página lanza un isolate que decodifica el archivo entero a PCM float en RAM, todos a la vez. CPU al 100 % y pico de memoria: "abre y se congela".

**Riesgos críticos adicionales:**

- **Windows:** se lanzan dos procesos PowerShell/WMI en cada arranque, uno para la GPU y otro para la huella de licencia. El de licencia va sin timeout propio. Si WMI está lento o roto, un usuario con licencia acaba en la pantalla de activación.
- **Memoria:** la caché de sonidos limita por **número**, no por **bytes**. En escritorio siempre es "high" (100 sonidos). Una pista de 4 min en memoria ocupa ≈ 85 MB, así que el consumo puede llegar a varios GB.
- **Detección de GPU:** marca como "GPU heredada" a la mayoría de las Intel HD/UHD modernas (520, 620, 630), a las GeForce 9xxM y a cualquier portátil con doble GPU.
- **Mezclador:** el volumen master y los efectos guardados **no se aplican al arrancar**. Solo se aplican al abrir el panel del mezclador (bug funcional).

---

## B. Mapa completo del arranque

```
main()                                                    [hilo UI]
 ├─ WidgetsFlutterBinding.ensureInitialized()
 ├─ await CrashLogService.initialize()      ← ANTES de runApp: la ventana de Windows
 │     getApplicationSupportDirectory, mkdir Logs,        solo se muestra con el
 │     exists/length/rename del log                       primer frame (flutter_window.cpp:30)
 └─ runApp(_BootstrapApp) → primer frame: _StartupScreen
       └─ Image.asset(logo.png 1254×1254, 1,36 MB) a 104 px, sin cacheWidth

_BootstrapApp._initialize()   (secuencial entre fases)
 ├─ Fase 1  Future.wait (timeout 10 s solo para storage)
 │    ├─ AppStorageService.initialize(): migraciones + 16 mkdir -p
 │    ├─ SharedPreferences.getInstance()
 │    └─ DeviceTierDetector.detect()
 │         Windows: Process.run('powershell' Get-CimInstance …) timeout 3 s
 │                  (el proceso NO se mata al vencer el timeout)
 │         Android: device_info + /proc/meminfo
 ├─ Fase 2  applyPendingRestore (5 s) ‖ limpieza Keychain 1.ª instalación (6 s)
 ├─ Fase 2.5 openAppDatabase()  timeout 40 s (+40 s si hay rollback)
 │    ├─ Isar.open (8 esquemas)
 │    ├─ finalizePendingRestore        (lee TODOS los pads y samples si hay restore)
 │    ├─ normalizeLegacySamplePaths    (escaneo sin índice de todos los pads)
 │    ├─ FilesystemSyncService.reconcileOnStartup   ◄── CAUSA RAÍZ #1
 │    │     recorrido recursivo de Assets/Audio
 │    │     por carpeta: query página (link sin índice), pads.load()
 │    │     por pad de audio: resolvePath() ⇒ mkdir -p  + File.exists()
 │    │     por archivo nuevo: 1 writeTxn (1 commit a disco) por archivo
 │    ├─ reconcileAllPageIndexIntegrity  (reescribe TODAS las páginas, cambien o no)
 │    └─ startLiveWatcher (escritorio)
 ├─ Fase 3  SoLoudAudioEngine          timeout Dart 30 s (inefectivo, ver abajo)
 │    ├─ listPlaybackDevices()  FFI síncrono: ma_context_init+enum+uninit ◄── CAUSA RAÍZ #2
 │    ├─ initEngine()           FFI síncrono (Android: espera hasta 5 s × 3 intentos)
 │    ├─ listPlaybackDevices()  otra vez
 │    └─ Escritorio: _changeDevice() → listPlaybackDevices() + changeDevice()
 │                 (reabre el MISMO dispositivo por defecto en cada arranque)
 └─ Fase 4  SystemChrome (móvil)

ProviderScope → SamplePadProApp
 ├─ licenseProvider._checkLicense()  (empieza AQUÍ, no en paralelo) → spinner 2
 │    ├─ secure storage: varias lecturas + escrituras en cada validación
 │    ├─ Windows: 2.º Process.run('powershell' ×3 Get-CimInstance) SIN timeout propio
 │    └─ Spp3Token.verify (cripto en el isolate de UI; no auditado)
 ├─ StoragePermissionGate (Android)
 └─ MainPadPage → PadGridView → padPageProvider(n)
       └─ Future.microtask: loadAudio() de TODOS los pads de la página ◄── CAUSA RAÍZ #3
             cada uno: compute() (isolate nuevo) + decodificación completa a float
```

**Peor caso antes de ver un error:** 10 + 6 + 40 (+40) + 30 ≈ **86–126 s** de splash, más 12 s de licencia. Para el usuario eso es "la app está colgada".

---

## C. Hallazgos técnicos

| ID | Archivo y ubicación | Problema | Causa raíz | Impacto | Severidad | Evidencia | Solución propuesta |
|---|---|---|---|---|---|---|---|
| **F01** | `core/providers/database_provider.dart:100-109`, `core/services/filesystem_sync_service.dart:28-146, 218-444` | La reconciliación completa del disco va dentro de la apertura de la BD, en el camino crítico del arranque | Se mezcla "abrir la dependencia dura" con "sincronizar la biblioteca". El coste es O(archivos + pads) con varias E/S por elemento y consultas N+1 | Arranque proporcional al tamaño de la biblioteca; puede agotar los 40 s y caer en la pantalla de error | **Crítica**: bloquea el acceso a la app y empeora con el uso | Ya en el código: `reconcileOnStartup` se espera (`await`) dentro de `openAppDatabase`, y esta dentro de la Fase 2.5 | Sacar `reconcileOnStartup`, `reconcileAllPageIndexIntegrity` y `startLiveWatcher` de `openAppDatabase`. Lanzarlos **después del primer frame interactivo** desde un `LibrarySyncService` con progreso discreto en la barra, y refrescar los providers al terminar |
| **F02** | `filesystem_sync_service.dart:363-374` | Una `writeTxn` por cada archivo nuevo | Inserciones sin agrupar | Cada commit de Isar hace un fsync. Con 1.000 archivos copiados desde el Explorador son 1.000 commits: segundos en SSD, decenas en HDD o eMMC | **Alta** | `await isar.writeTxn(...)` dentro del `for (final child in children)` | Acumular los `PadModel` nuevos por página y hacer un único `putAll` por página (o por lotes de 500) |
| **F03** | `local_audio_storage_service.dart:112, 231-238` → `app_storage_service.dart:81-86` | `resolvePath()` hace `Directory.create(recursive: true)` en **cada** llamada | `_directory()` crea la carpeta siempre, no solo la primera vez | En la reconciliación: 2 `resolvePath` + 1 `exists` por pad, es decir ~3 syscalls asíncronas por pad. Lo mismo en cada `loadAudio` | **Alta** (multiplicador de F01 y F07) | `_getAudiosDir() => AppStorageService.mediaDirectory()` → `_directory('Assets','Audio')` → `create(recursive: true)` | Cachear el `Directory` resuelto (`_mediaDirCache ??=`) tras `initialize()`. `resolvePath` pasa a ser puramente síncrono (`String resolvePathSync`) |
| **F04** | `isar_workspace_repository.dart:455-458` | `reconcilePageIndexIntegrity` reescribe todas las páginas de todos los workspaces en cada arranque | `put` incondicional aunque `pageIndexMap` esté vacío | Escrituras y commits innecesarios en cada arranque (desgaste de flash en Android) | **Media** | `for (final p in pages) { await isar.pageModels.put(p); }` fuera del `if (pageIndexMap.isNotEmpty)` | Escribir solo las páginas cuyo índice cambió; si no cambia nada, no abrir `writeTxn` |
| **F05** | `workspace/data/models/page_model.dart` (sin `@Index` en `pageIndex`), `filesystem_sync_service.dart:226-230, 471-477`, `pad_providers.dart:191-203` | Consultas por link sin índice | `filter().workspace(...)` y `filter().page(...)` recorren la colección completa en Isar 3 | O(N·M) en la reconciliación; cada cambio de página recorre todos los pads | **Media** | Sin `@Index` en `PageModel.pageIndex` ni en `PadModel` para la página | Añadir `@Index(composite: [CompositeIndex('workspaceId')])` con un `workspaceId` desnormalizado en `PageModel` y un `pageId` indexado en `PadModel` (migración de esquema con `build_runner`) |
| **F06** | `soloud_audio_engine.dart:171, 337, 363, 531`; nativo `flutter_soloud/src/player.cpp:281-295` | `listPlaybackDevices()` se llama 3–4 veces al arrancar, síncrono en el hilo de UI, y cada llamada hace `ma_context_init` + enumeración + `uninit` | Una API de consulta con coste de inicialización de backend, invocada sin caché | UI congelada. En Windows, el sondeo de WASAPI/DirectSound es sensible a drivers, Bluetooth y cables virtuales | **Crítica** en Windows con muchos dispositivos, **Alta** en general | Llamadas encadenadas en `_doInitialize` → `initializeAndRestoreDevice` → `_changeDevice` | Enumerar **una sola vez** por arranque y reutilizar la lista; volver a enumerar solo al pedir "refrescar dispositivos" |
| **F07** | `soloud_audio_engine.dart:408-417, 537` | En escritorio se reabre el dispositivo por defecto en cada arranque | `needsDeviceSwitch` es siempre `true` fuera de móvil, aunque el destino sea el que ya se abrió | Segundo open/close del stream en el hilo de UI | **Alta** | `!(Platform.isAndroid \|\| Platform.isIOS) \|\| targetDeviceId != defaultDevice.id` | Abrir directamente con `init(device: target)` y no llamar a `changeDevice` si `target == default` |
| **F08** | `flutter_soloud/lib/src/soloud.dart:432`; `soloud_miniaudio.cpp:155, 358, 601-640`; `soloud_audio_engine.dart:187-232` | En Android, el "watchdog" bloquea el hilo de UI hasta 5 s por intento (3 intentos) y 1,5 s más en `android_wait_for_pending_init` | El open corre en un hilo nativo, pero el llamador (el isolate de UI) espera con `wait_until`. `.timeout(8 s)` no puede dispararse porque el hilo está bloqueado | Mínimo 5 s de UI totalmente congelada si el HAL se atasca; hasta ~15–16 s si el worker termina entre intentos y el siguiente vuelve a esperar. Si sigue ocupado, los intentos 2 y 3 fallan rápido | **Crítica** en Android gama baja | `gAndroidInitCv.wait_until(...)` en el hilo llamador; `initEngine` es FFI síncrono | Hacer el open **asíncrono de verdad**: `initEngine` lanza el worker y devuelve `pending`, y el resultado vuelve por `NativeCallable.listener`/`SendPort`. Alternativa de menor alcance: llamar `initEngine` desde `Isolate.run` y registrar los callbacks en el isolate principal después (hay que validarlo en dispositivo) |
| **F09** | `main.dart:236-237` | El audio se inicializa en serie después de la BD y antes de mostrar la UI | Fase 3 dentro del bootstrap | Suma latencia al primer frame útil | **Alta** | `final audioInitResult = await _initAudioSafe(...)` antes de `return _AppServices` | Mostrar `MainPadPage` en cuanto BD y licencia estén listas. El audio arranca después, con el overlay existente `_AudioNotReadyOverlay` ("Iniciando audio…"), que ya bloquea los pads. Requiere F08 para que ese overlay no se congele |
| **F10** | `pad_providers.dart:230-237`; `soloud_audio_engine.dart:614-690`; `flutter_soloud/soloud.dart:681-714`; `player.cpp:435-439` | Ráfaga sin límite de `loadAudio` al abrir cada página | `for (pad in entities) loadAudio(...)` sin cola. Cada carga es `compute()` (isolate nuevo) + `SoLoud::Wav::load` (decodificación completa a float) | CPU saturada y pico de RAM justo después de abrir: jank y "congelado". En gama baja, riesgo de que el sistema mate la app | **Alta** | Código citado; `LoadMode.memory` es el valor por defecto | `AudioLoadScheduler` con concurrencia limitada por perfil (1/2/min(4, núcleos−1)), prioridad a los pads visibles, cancelación al cambiar de página y deduplicación (ya existe `_loadingIds`) |
| **F11** | `soloud_audio_engine.dart:155-161`; `device_tier.dart:64-68` | La caché de sonidos limita por número, no por memoria | `LruCache(capacity)` cuenta entradas; escritorio siempre es `high` → 100 | Wav en memoria = muestras × canales × 4 B. 4 min estéreo ≈ 85 MB; 100 entradas pueden pasar de varios GB | **Alta** | `DeviceTier.high => 100`; Windows y macOS devuelven `high` siempre (`device_tier.dart:94-100`) | LRU **por bytes** (presupuesto según RAM total/disponible y perfil). Para archivos largos (> N s, configurable), `LoadMode.disk` (`WavStream`), sin tocar la calidad |
| **F12** | `device_tier.dart:94-100` | En escritorio el perfil es siempre `high` | No se consulta RAM, núcleos ni memoria disponible | Un portátil de 4 GB y 2 núcleos recibe caché de 100, polling de 25 ms y visualización activa | **Alta** | `if (Platform.isWindows) { … return DeviceTier.high; }` | Perfil por puntuación: RAM total, RAM libre, núcleos lógicos (`Platform.numberOfProcessors`), SO, GPU y override manual en Ajustes (sección 6) |
| **F13** | `device_tier.dart:116-158` | La detección de GPU heredada marca GPUs modernas | La regex `hd graphics(\s+\d+)?` con `gen < 4000` coincide con "UHD Graphics 620" y "HD Graphics 520". `'geforce 9'` coincide con "GeForce 940MX". Con doble GPU, la salida de CIM junta ambas | Efectos visuales degradados sin motivo en la mayoría de los portátiles Intel | **Media** (visual, no bloquea) | Verificado con la misma regex: UHD 620 → legacy, HD 520 → legacy, 940MX → legacy, UHD 630 + RTX 3060 → legacy | Lista explícita de generaciones (`HD Graphics` sin número, 2000, 2500, 3000) y comprobar **cada** adaptador por separado, marcando legacy solo si **todos** lo son |
| **F14** | `device_tier.dart:118-125` | PowerShell + WMI en cada arranque de Windows, en la Fase 1 | Arranque en frío de PowerShell de 0,5–3 s (más con antivirus). El `timeout` no mata el proceso | Hasta 3 s en el camino crítico y un proceso huérfano | **Alta** en PCs de gama baja | `Process.run('powershell', …).timeout(3 s)` | Cachear el resultado en `SharedPreferences` (clave: versión de la app + build de Windows) y revalidarlo en segundo plano. Mejor aún: `EnumDisplayDevicesW` en el runner C++ vía MethodChannel, sin procesos externos |
| **F15** | `device_fingerprint.dart:190-200`; `license_providers.dart:82-101`; `license_manager.dart:139-236` | La huella de licencia en Windows lanza **otro** PowerShell (3 consultas CIM) sin timeout propio, en cada arranque. La comprobación de licencia empieza solo cuando el bootstrap ha terminado | Serialización y un proceso externo en el camino crítico | Segundo spinner. Si WMI tarda más de 12 s, el usuario con licencia ve la pantalla de activación | **Alta** | `generate()` llama siempre a `generateResult()`; el valor persistido solo se compara después | (1) Lanzar `validateLicense()` **en paralelo** con la Fase 1. (2) Usar la huella persistida como camino rápido y revalidar el HWID en segundo plano. (3) Poner timeout propio y matar el proceso (`Process.start` + `kill`). (4) Si vence el timeout con una licencia persistida válida, no degradar a "sin licencia" |
| **F16** | `license_providers.dart:178-186`, `main.dart:515-518` | Revalidación completa en cada `resumed` | `sync()` = `validateLicense()`, que escribe en el almacén seguro 4–5 veces | E/S cifrada (DPAPI/Keystore) cada vez que el usuario vuelve a la app | **Baja** | `_saveActivationData` + `lastLicenseCheckUtc` en cada validación | Aplicar un intervalo mínimo entre revalidaciones y no reescribir valores que no cambiaron |
| **F17** | `main.dart:165-237` | Los `.timeout()` no cancelan el trabajo subyacente | Un `Future.timeout` solo deja de esperar | Tras un timeout, la migración de carpetas o la reconciliación siguen corriendo mientras se reintenta. Si Isar ya abrió, `openAppDatabase()` devuelve la instancia al instante con la reconciliación a medias. `rollbackFailedRestore()` puede intentar renombrar el archivo de una BD abierta | **Media** (condiciones de carrera en el reintento) | `openAppDatabase` idempotente por `Isar.instanceNames` y el `catch` genérico que llama a `rollbackFailedRestore` | Separar "abrir" de "sincronizar" (F01). Distinguir `TimeoutException` de un fallo real y no hacer rollback con la instancia abierta. Reintento con un `Completer` único y en vuelo |
| **F18** | `main.dart:37-41`; `windows/runner/flutter_window.cpp:30-31` | `CrashLogService.initialize()` se espera antes de `runApp` | E/S de disco antes del primer frame; en Windows la ventana no aparece hasta ese frame | Ventana invisible más tiempo del necesario al hacer doble clic | **Media** | `await CrashLogService.initialize(); runApp(...)` | Instalar los handlers de forma síncrona, llamar a `runApp` y resolver el archivo de log en segundo plano (el búfer en memoria ya existe) |
| **F19** | `main.dart:345-356`; `assets/icon/logo.png` | Logo de 1254×1254 px (1,36 MB) decodificado a tamaño completo para 104 px | Sin `cacheWidth`/`cacheHeight` | ~6 MB RGBA y decodificación extra en el splash (gama baja) | **Baja** | `Image.asset(..., width: 104, height: 104)` | Añadir `cacheWidth: (104 * dpr).round()` o un asset de splash de 256 px |
| **F20** | `soloud_audio_engine.dart:242`; `device_tier.dart:78` | La visualización del motor está activa por defecto en gama media y alta | Solo el panel del mezclador la consume | El hilo de audio calcula datos de visualización por cada búfer aunque nadie los lea | **Baja–Media** | `setVisualizationEnabled(enableVisualizationByDefault)`; el único consumidor es `master_mixer_panel.dart:113` | Activarla al abrir el panel y desactivarla al cerrarlo (`initState`/`dispose` del panel) |
| **F21** | `master_mixer_panel.dart:34-66` | Volumen master y efectos se restauran **solo al abrir el mezclador** | La carga de preferencias vive en el `initState` de un `endDrawer` | Bug funcional: tras reiniciar, el audio suena con volumen 1.0 y sin efectos hasta abrir el panel | **Media** (funcional) | Único lector de `mixer_*` en `_loadSavedMixerSettings` | Mover la restauración a un `MixerSettingsService` que se aplique cuando el motor quede `ready` |
| **F22** | `pad_providers.dart:1376-1386`; `pad_grid_view.dart:77-80, 115-120`; `pad_button.dart:26-45` | Cada cambio de estado de un pad reemplaza la lista y reconstruye **todos** los pads visibles | El estado de reproducción vive dentro de la lista de entidades de la página | En escritorio (hasta 26 columnas), cada toque reconstruye decenas o cientos de `PadButton` con 6 `watch` cada uno | **Media** | `state = AsyncData(newStateList)` en `_setPadState` | Estado runtime por pad en un `padRuntimeStateProvider.family(id)` o `select((pads) => pads[i].state)`; la lista solo cambia con cambios estructurales |
| **F23** | `filesystem_sync_service.dart:482-527` | El watcher dispara una reconciliación **completa** ante cualquier evento | No se usa la ruta del evento para acotar el trabajo | Copiar 1 archivo hace un recorrido completo. Riesgo de carrera con los importadores internos (pads duplicados si la reconciliación ve archivos antes de que el importador registre sus pads) | **Media** | `Timer(debounce, () => reconcileOnStartup(isar))` | Reconciliación incremental por el subárbol afectado y una pausa del watcher (`suspend`/`resume`) durante las importaciones internas |
| **F24** | `config_backup_service.dart:215-241`; `folder_transfer_service.dart:254-264`; `project_importer.dart`, `workspace_zip_importer.dart` | Las importaciones cargan el ZIP entero en RAM y lo copian al isolate | `withData: true`, `readAsBytes()` y `compute(decode, bytes)`: el archivo ocupa memoria 2–3 veces | Riesgo de cierre por memoria (OOM) en Android con respaldos grandes | **Alta** (RAM, fuera del arranque) | Citas directas | Decodificar en streaming desde la ruta (`InputFileStream` del paquete `archive`, ya es dependencia) dentro del isolate, pasando solo la ruta |
| **F25** | `local_audio_storage_service.dart:102`; `workspace_importer.dart:144, 287`; `project_importer.dart:178`; `zip_utils.dart:26` | E/S síncrona (`existsSync`, `listSync`) en el isolate de UI | Llamadas `*Sync` dentro de flujos de importación | Micro-bloqueos durante las importaciones | **Baja** | `grep` de `Sync(` | Sustituir por las variantes asíncronas o hacerlo dentro del isolate de trabajo |
| **F26** | `crash_log_service.dart:110-122` | Cada línea de log abre, añade y cierra el archivo, sin orden garantizado | `writeAsString(mode: append)` sin await por línea | Líneas desordenadas y E/S por línea en las ráfagas de errores | **Baja** | Código citado | `IOSink` único con `flush` periódico, o cola en serie |

---

## D. Análisis por recurso

**CPU**

- F10: decodificaciones en paralelo sin límite, una por pad.
- F01/F05: consultas O(N·M) y recorridos completos del árbol.
- F20: visualización calculada sin consumidor.
- F22: reconstrucciones masivas del grid.
- El polling de 25 ms (`_startPolling`) sale enseguida si no hay voces activas: coste despreciable, se mantiene.

**RAM**

- F11/F12: caché por número con decodificación completa a float y perfil `high` fijo en escritorio. Es el mayor riesgo en sesiones largas.
- F24: ZIP completo 2–3 veces en memoria.
- F19: logo sin redimensionar.
- No se encontraron fugas claras de listeners: `_sub` se cancela en `ref.onDispose`, el watcher se para en `dispose` y las fuentes desalojadas se liberan con disposición diferida.

**GPU**

- F13: la falsa detección de "GPU heredada" degrada efectos sin necesidad; no es un problema de rendimiento.
- `PadGridView` usa `GridView.builder` con `addRepaintBoundaries: true`, así que el grid está virtualizado (correcto).
- Las sombras con `blurRadius` escalado por velocidad solo cuestan mientras el pad está activo. Se mantiene, con la vía plana para el perfil bajo.
- La IA/ONNX de la plantilla de auditoría no aplica: el proyecto no la usa.

**Disco**

- F01/F02/F03/F04: miles de syscalls y commits en cada arranque.
- F26: log por línea.
- F14/F15: procesos externos que tocan WMI.

**Red**

- No hay red en el arranque: la licencia SPP3 es criptográfica y offline (`license_manager.dart`). El inicio sin conexión no debería degradar nada. Hay que verificar que `bdj_license_core` no haga peticiones, porque no se pudo auditar.

**UI y renderizado**

- El primer frame llega pronto (el splash es ligero), pero la UI **útil** llega tarde (F01, F09, F15).
- La animación del splash se congela durante F06/F07/F08.
- Hay jank después de abrir (F10, F22).

**Concurrencia**

- Hay trabajo sin límite (F10), timeouts que no cancelan (F14, F17), carreras en el reintento (F17) y entre el watcher y los importadores (F23).
- `_ensureInitialized` del motor ya comparte el `Completer` en vuelo (corregido antes). Se mantiene.

---

## E. Análisis por plataforma

**Windows**

- F14 y F15 (dos PowerShell por arranque), F06 y F07 (enumeración y reapertura de WASAPI en el hilo de UI), F18 (ventana invisible hasta el primer frame), F13 (Intel UHD marcada como legacy) y F12 (siempre `high`).
- El watcher recursivo (`Directory.watch(recursive: true)`) es nativo y eficiente en Windows.

**macOS**

- El perfil también es siempre `high` (F12).
- El watcher recursivo usa FSEvents (correcto).
- No hay PowerShell: la huella usa `device_info_plus`.
- F01, F06 y F10 aplican igual.
- Apple Silicon con 8 GB y memoria unificada se ve especialmente afectado por F11.

**Android**

- F08 (de 5 a ~16 s de UI congelada en gama baja), F10 (ráfaga de isolates en móviles de 2–3 GB, con riesgo de que el sistema mate el proceso) y F24 (OOM al importar).
- F01 afecta sobre todo en eMMC lenta.
- Sin watcher en móvil (correcto).
- Pendiente del historial del proyecto: `POST_NOTIFICATIONS` no se solicita en tiempo de ejecución (Android 13+) para la notificación del servicio en primer plano.

---

## F. Arquitectura actual vs recomendada

| Elemento | Decisión | Motivo |
|---|---|---|
| Bootstrap por fases con presupuestos y `_StartupScreen` con reintento | **Mantener** | Buen diseño: los fallos son visibles |
| Abrir la BD en el bootstrap (dependencia dura) | **Mantener** | Pero *solo* abrir |
| Reconciliación, integridad y watcher dentro de `openAppDatabase` | **Mover** | A un `LibrarySyncService` que arranca tras el primer frame interactivo, incremental y por lotes |
| Audio dentro del bootstrap | **Mover** | Después de mostrar la UI, con el overlay existente |
| Init nativo de audio síncrono con espera bloqueante | **Refactorizar** | Open asíncrono con callback (F08) y enumeración única (F06) |
| Carga de audio `for → loadAudio` | **Refactorizar** | `AudioLoadScheduler` con límite, prioridad y cancelación |
| `LruCache` por número | **Refactorizar** | Presupuesto en bytes y `WavStream` para archivos largos |
| `DeviceTier` enum fijo por plataforma | **Refactorizar** | `DeviceProfile` con puntuación y valores ajustables (presupuesto de RAM, concurrencia de carga, visualización, efectos) y override manual en Ajustes |
| PowerShell para GPU y HWID | **Refactorizar** | Caché + revalidación en segundo plano; para la GPU, API nativa en el runner |
| Validación de licencia tras el bootstrap | **Paralelizar** | Arranca a la vez que la Fase 1 |
| Restauración del mezclador en el widget | **Mover** | A un servicio aplicado al quedar `ready` el motor |
| Estado runtime del pad dentro de la lista | **Refactorizar** | Provider por pad |
| `third_party/isar_flutter_libs`, `pubspec.yaml.bak`, asset `app_icon.png` | **Eliminar** | Sección J |

No se proponen capas nuevas fuera de estos puntos: ni Clean Architecture completa ni un bus de eventos. Los tres servicios nuevos (`LibrarySyncService`, `AudioLoadScheduler`, `DeviceProfile`) sustituyen responsabilidades que hoy están mal ubicadas; no añaden capas.

---

## G. Plan de implementación priorizado

**Fase 1: bloqueos críticos** (orden por impacto en el usuario y dependencias)

1. **F01 + F03 + F04:** sacar la sincronización de `openAppDatabase`, cachear `mediaDirectory` y escribir solo las páginas que cambian. *Riesgo bajo, impacto máximo.*
2. **F06 + F07:** enumerar una sola vez y no reabrir el dispositivo por defecto. *Riesgo bajo, solo Dart.*
3. **F15 (paralelizar) + F14 (caché de GPU):** la licencia arranca en paralelo con la Fase 1 y la GPU sale de caché. *Riesgo bajo.*
4. **F10:** `AudioLoadScheduler` con límite de concurrencia. *Riesgo medio; necesita pruebas de latencia al primer toque.*
5. **F09:** audio después de la UI, con el overlay. *Depende de 2; con F08 pendiente, el overlay aún puede congelarse en Android.*
6. **F08:** init asíncrono nativo en Android. *Riesgo alto: C++ del plugin vendorizado; hay que validarlo en gama baja real.*
7. **F17 + F18:** reintento seguro y `runApp` sin esperar al log.

**Fase 2: estructural**

F02 (lotes), F05 (índices y migración de esquema), F23 (watcher incremental y pausa durante importaciones), F21 (mezclador), F22 (estado por pad), F24 (ZIP en streaming), F16.

**Fase 3: adaptación al hardware**

F12 (`DeviceProfile` por puntuación) y F11 (LRU por bytes y `WavStream` para archivos largos), F13 (GPU), F20 (visualización bajo demanda).

**Fase 4: avanzada**

F19, F25, F26, precarga inteligente de la página siguiente según el perfil, telemetría local de arranque por fase (a `CrashLogService`).

---

## H. Criterios de aceptación

Hay que medir en **release/profile**, nunca en debug. La instrumentación es un `Stopwatch` por fase registrado en `CrashLogService`, más DevTools (Timeline / Memory) y `adb shell dumpsys meminfo`.

| Problema | Métrica | Objetivo |
|---|---|---|
| Arranque general | Tiempo hasta el primer frame | < 500 ms escritorio, < 1 s Android gama media |
| Arranque general | Tiempo hasta la UI interactiva (grid visible y tocable) | < 2 s escritorio medio, < 3 s Android gama baja, **independiente del tamaño de la biblioteca** (probar con 50 y con 5.000 pads) |
| F06/F07/F08 | Frame más largo del hilo UI durante el arranque | < 100 ms (hoy, hasta segundos) |
| F01/F02 | Reconciliación con 1.000 archivos nuevos | Fuera del camino crítico; ≤ 1 commit por página |
| F04 | Escrituras de Isar en un arranque sin cambios | 0 transacciones de escritura |
| F10 | CPU tras abrir una página de 64 pads | Sin frames > 32 ms; concurrencia de decodificación ≤ límite del perfil |
| F11 | RAM tras 30 min recorriendo páginas | Estable (±10 %) y ≤ presupuesto del perfil |
| F14/F15 | Procesos PowerShell por arranque de Windows | 0 en el camino crítico |
| F15 | Licencia válida con WMI lento o roto | Nunca la pantalla de activación |
| F13 | UHD 620 / Iris Xe / UHD 630 + RTX | `reducedGpu = false` (test unitario de la regex) |
| F21 | Volumen y efectos tras reiniciar | Iguales a los guardados sin abrir el mezclador |
| F24 | Importar un respaldo de 1 GB en Android con 3 GB | Sin cierre por memoria; pico de RAM < 150 MB sobre la base |

**Escenarios mínimos:**

- Hardware: escritorio bajo (4 GB, 2 núcleos, HDD), medio y alto; Android económico (2–3 GB, API 29), medio y alto (Galaxy S25, páginas de 16 KB).
- Bibliotecas: vacía y grande.
- Ejecuciones: primera y posteriores; tras una actualización (con restauración pendiente); sin red.
- Carga: 1.000 archivos copiados desde el Explorador con la app cerrada.
- Uso: sesión de 30 min; cancelación de una importación a la mitad.

---

## I. Archivos que deben modificarse

| Archivo | Motivo | Cambio esperado | Riesgo | Depende de |
|---|---|---|---|---|
| `lib/core/providers/database_provider.dart` | F01 | `openAppDatabase` solo abre, finaliza el restore y normaliza | Bajo | — |
| `lib/core/services/filesystem_sync_service.dart` | F01, F02, F23 | Servicio de sincronización post-arranque, por lotes e incremental | Medio | database_provider |
| `lib/core/services/app_storage_service.dart` | F03 | Caché de directorios resueltos | Bajo | — |
| `lib/core/services/local_audio_storage_service.dart` | F03, F25 | `resolvePath` síncrono sobre la caché; quitar `existsSync` | Bajo | app_storage_service |
| `lib/features/workspace/data/repositories/isar_workspace_repository.dart` | F04 | Escribir solo lo que cambió | Bajo | — |
| `lib/main.dart` | F09, F15, F17, F18 | `runApp` inmediato; licencia en paralelo; audio post-UI; reintento seguro | Medio | F06/F07 |
| `lib/features/audio_engine/data/soloud_audio_engine.dart` | F06, F07, F10, F11, F20 | Enumeración única, sin reapertura, scheduler, LRU por bytes | Medio | device_tier |
| `third_party/flutter_soloud/src/soloud/src/backend/miniaudio/soloud_miniaudio.cpp` + bindings | F08 | Open asíncrono con callback | **Alto** | Pruebas en dispositivo |
| `lib/core/platform/device_tier.dart` | F12, F13, F14 | `DeviceProfile` por puntuación; regex corregida; caché | Medio | settings_service (override) |
| `lib/core/security/device_fingerprint.dart`, `lib/core/licensing/license_manager.dart`, `license_providers.dart` | F15, F16 | Camino rápido persistido, timeout y kill, menos escrituras | Medio (seguridad de licencia) | — |
| `lib/features/pad_system/presentation/providers/pad_providers.dart` | F10, F22 | Encolar cargas; estado runtime por pad | Medio | soloud_audio_engine |
| `lib/features/pad_system/presentation/widgets/pad_grid_view.dart`, `pad_button.dart` | F22 | Suscripción por pad | Bajo | pad_providers |
| `lib/features/pad_system/presentation/widgets/master_mixer_panel.dart` + servicio nuevo | F21, F20 | Restauración al arrancar; visualización bajo demanda | Bajo | — |
| `lib/features/workspace/data/models/page_model.dart`, `pad_model.dart` | F05 | Índices + campos desnormalizados (`build_runner`) | Medio (migración) | — |
| `lib/features/settings/data/services/config_backup_service.dart`, `folder_transfer_service.dart`, importadores | F24 | ZIP en streaming desde la ruta | Medio | — |
| `lib/core/services/crash_log_service.dart` | F18, F26 | Init no bloqueante; `IOSink` único | Bajo | main.dart |

---

## J. Archivos que deben eliminarse o consolidarse

| Archivo | Evidencia | Acción |
|---|---|---|
| `frontend/third_party/isar_flutter_libs/` | Ya no se referencia en `pubspec.yaml` desde la migración a `isar_community` | Eliminar |
| `frontend/pubspec.yaml.bak` | Copia de respaldo versionada en el repo | Eliminar |
| `assets/icon/app_icon.png` (entrada en `pubspec.yaml`) | Idéntico a `logo.png` (mismo MD5); ningún `.dart` lo referencia; suma 1,36 MB al bundle | Quitar del bloque `assets:` y borrar el archivo si ningún script externo lo usa |
| `_isarNativeLibPath()` duplicado en 6 tests | Mismo helper copiado en `test/` | Consolidar en `test/helpers/` |
