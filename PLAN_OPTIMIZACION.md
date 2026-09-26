# Plan de optimización: arranque, fluidez y recursos

Plan de implementación del diagnóstico de `docs/AUDITORIA_RENDIMIENTO.md`. Los IDs `Fxx` remiten a los hallazgos de ese documento.

---

## Cómo usar este plan

- **Una tarea = una rama o commit.** Así cada regresión se puede aislar con `git bisect`.
- **Medir antes y después.** La tarea T0 va primero, porque sin ella no hay forma de demostrar la mejora.
  - Mide siempre en `--profile` o `--release`, nunca en debug.
- **Orden obligatorio:** T0 → Fase 1 (T1…T9) → Fase 2 → Fase 3 → Fase 4. Dentro de cada fase, el orden ya tiene en cuenta las dependencias.
- **Tras cada tarea:**
  1. `flutter analyze`
  2. `flutter test`
  3. Arranque manual en Windows y en un Android.
  4. Si tocaste modelos `@collection`: `dart run build_runner build`.
- **Reglas fijas:**
  - No cambiar la calidad del audio.
  - No quitar funciones.
  - Sin dependencias nuevas.
  - Sin `Future.delayed` para "arreglar" tiempos.
  - Sin `catch (_) {}` nuevos que oculten errores.

---

## T0: Instrumentación de arranque (requisito previo)

**Objetivo:** tener números reales por fase y detectar los frames largos del hilo de UI.

**Nuevo:** `lib/core/diagnostics/startup_timeline.dart`

```dart
import 'dart:ui' show FrameTiming;
import 'package:flutter/scheduler.dart';
import '../services/crash_log_service.dart';

/// Marca hitos del arranque y registra frames lentos en el log de diagnóstico.
class StartupTimeline {
  StartupTimeline._();
  static final Stopwatch _clock = Stopwatch()..start();

  static void mark(String name) =>
      CrashLogService.log('[Startup] $name +${_clock.elapsedMilliseconds} ms');

  /// Registra cualquier frame cuyo build o raster supere [threshold].
  static void watchSlowFrames({Duration threshold = const Duration(milliseconds: 100)}) {
    SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
      for (final t in timings) {
        if (t.buildDuration > threshold || t.rasterDuration > threshold) {
          CrashLogService.log('[Frame] build=${t.buildDuration.inMilliseconds} ms '
              'raster=${t.rasterDuration.inMilliseconds} ms');
        }
      }
    });
  }
}
```

**Dónde marcar:**

- `main()`: antes de `runApp` → `mark('runApp')`.
- `_initialize()`: al terminar cada fase (`phase1`, `phase2`, `database`, `audio`).
- `SamplePadProApp.initState` → `addPostFrameCallback((_) => mark('firstAppFrame'))`.
- Cuando el grid pinta por primera vez con datos → `mark('interactive')`.

**Nota:** los frames de UI congelados por FFI síncrono no aparecen como frame lento, porque no se produce ningún frame. Para detectarlos, marca antes y después de cada llamada al motor de audio.

**Tabla base a rellenar antes de tocar nada:**

| Escenario | runApp | phase1 | database | audio | firstAppFrame | interactive |
|---|---|---|---|---|---|---|
| Windows, biblioteca pequeña | | | | | | |
| Windows, biblioteca grande (≥ 3.000 pads) | | | | | | |
| Android gama baja | | | | | | |
| Android gama alta | | | | | | |

- [ ] Hecho: el log de "Copiar diagnóstico" muestra la línea de tiempo completa.

---

# FASE 1: Bloqueos críticos

## T1: Separar "abrir la BD" de "sincronizar la biblioteca" (F01)

**Archivos:**

- `lib/core/providers/database_provider.dart`
- `lib/core/services/filesystem_sync_service.dart`
- `lib/main.dart`
- Nuevo: `lib/core/providers/library_sync_provider.dart`

**Pasos:**

1. **En `openAppDatabase()`,** eliminar las líneas 105–109 (`reconcileOnStartup`, `reconcileAllPageIndexIntegrity`, `startLiveWatcher`). Se quedan:
   - `Isar.open`
   - `finalizePendingRestore`
   - `normalizeLegacySamplePaths`

   Son correcciones de datos que deben ocurrir antes de leer.

2. **Crear el provider que orquesta la sincronización diferida:**

   ```dart
   /// Sincronización disco↔BD que corre DESPUÉS de mostrar la UI.
   /// Devuelve cuántos elementos cambió para decidir si refrescar la vista.
   final librarySyncProvider = FutureProvider<int>((ref) async {
     final isar = await ref.read(isarProvider.future);
     final changed = await FilesystemSyncService.reconcileOnStartup(isar);
     await IsarWorkspaceRepository(Future.value(isar)).reconcileAllPageIndexIntegrity();
     FilesystemSyncService.startLiveWatcher(
       isar,
       onChangesDetected: () => _refreshLibraryViews(ref),
     );
     return changed;
   });

   /// Indica a la UI que hay una sincronización en curso (bloquea el modo edición).
   final librarySyncInProgressProvider = Provider<bool>(
     (ref) => ref.watch(librarySyncProvider).isLoading,
   );
   ```

   `_refreshLibraryViews` invalida `workspaceListProvider`, `currentWorkspaceProvider` y `padPageProvider` (invalidar la family completa las refresca todas).

3. **En `_SamplePadProAppState.initState`,** dentro de `addPostFrameCallback`:

   ```dart
   ref.read(librarySyncProvider.future).then((changed) {
     if (changed > 0 && mounted) _refreshLibraryViews(ref);
   });
   ```

4. **Evitar colisiones de `padId`.** Mientras `librarySyncInProgressProvider` sea `true`, deshabilita la entrada al modo edición y las acciones que crean o mueven pads. La reproducción sigue permitida.
   - Motivo: `_syncFolderRecursive` calcula `maxPadId` sobre una foto de la página. Si el usuario crea un pad a la vez, se duplicaría el `padId`.
   - Indicador discreto en el AppBar: icono de sincronización con tooltip "Sincronizando biblioteca…".

5. **Actualizar el comentario de `isarProvider` y la doc de `openAppDatabase`.**

**Tests:**

- Ajustar `test/core/services/filesystem_sync_service_test.dart` si depende de que `openAppDatabase` reconcilie.
- Nuevo test: `openAppDatabase` no crea pads para archivos sueltos en `Assets/Audio`; `librarySyncProvider` sí.

**Aceptación:**

- La fase `database` de T0 no depende del tamaño de la biblioteca (misma cifra con 50 y con 5.000 pads).
- Un archivo copiado con la app cerrada aparece en su carpeta segundos después de abrir, sin reiniciar.

**Riesgo:** medio. Verificar que ninguna pantalla asume que la reconciliación ya terminó al primer frame.

- [ ] Hecho

---

## T2: Cachear directorios y hacer `resolvePath` síncrono (F03)

**Archivos:**

- `lib/core/services/app_storage_service.dart`
- `lib/core/services/local_audio_storage_service.dart`
- `lib/core/services/filesystem_sync_service.dart`

**Pasos:**

1. **En `AppStorageService`:**

   ```dart
   static final Map<String, Future<Directory>> _dirCache = {};
   static String? _mediaPath; // disponible tras initialize()

   static Future<Directory> _directory([String? first, String? second, bool cache = true]) async {
     final support = await _supportDirectory();
     final path = p.joinAll([support.path, if (first != null) first, if (second != null) second]);
     if (!cache) return Directory(path).create(recursive: true);
     return _dirCache[path] ??= Directory(path).create(recursive: true);
   }

   /// Ruta de la carpeta de audio sin E/S. Lanza StateError si se usa antes de initialize().
   static String get mediaPathSync => _mediaPath ??
       (throw StateError('AppStorageService.initialize() no se ha ejecutado'));
   ```

   - En `initialize()`: `_mediaPath = (await mediaDirectory()).path;`
   - `workDirectory()` debe llamar a `_directory(..., cache: false)`, porque genera nombres únicos y la caché crecería sin límite.
   - `clearPersistentData()` y `resetCacheForTesting()` deben vaciar `_dirCache` y `_mediaPath`.

2. **En `LocalAudioStorageService`:**

   ```dart
   static String resolvePathSync(String pathOrUri) => pathOrUri.startsWith(prefix)
       ? p.join(AppStorageService.mediaPathSync, pathOrUri.substring(prefix.length))
       : pathOrUri;

   static Future<String> resolvePath(String pathOrUri) async => resolvePathSync(pathOrUri);
   ```

   Mantener la firma asíncrona para no tocar los 11 llamadores. Migrar a la versión síncrona solo los de los bucles calientes: `filesystem_sync_service.dart` (3 sitios) y `soloud_audio_engine.dart:664`.

3. **Sin cambios en las importaciones:** ya hacen `Directory(p.dirname(newPath)).create(recursive: true)` antes de escribir (línea 181), así que siguen funcionando aunque el usuario borre la carpeta a mano.

**Tests:** `resolvePathSync` con prefijo, sin prefijo y antes de `initialize()` (debe lanzar `StateError`).

**Aceptación:** con 3.000 pads, `reconcileOnStartup` al menos 2 veces más rápido (T0). Cero `create(recursive: true)` por pad.

- [ ] Hecho

---

## T3: Escribir solo las páginas que cambian (F04)

**Archivo:** `lib/features/workspace/data/repositories/isar_workspace_repository.dart:406-494`

**Pasos:**

1. En los dos bucles (`roots` y `folders`), acumular las páginas cuyo índice cambió: `if (oldIdx != idx) changedPages.add(p);`
2. Antes de `writeTxn`: `if (changedPages.isEmpty) return;`
3. Dentro de la transacción: `await isar.pageModels.putAll(changedPages);`. El remapeo de pads y macros queda igual, porque ya está condicionado a `pageIndexMap.isNotEmpty`.

**Tests:** en `workspace_repository_test`:

- Un workspace íntegro no produce escrituras. Comprueba que `lastModified` no cambia o cuenta con un spy.
- Uno con duplicados se corrige igual que antes.

**Aceptación:** un arranque sin cambios hace 0 transacciones de escritura.

- [ ] Hecho

---

## T4: Motor de audio: una enumeración, sin reapertura (F06, F07)

**Archivo:** `lib/features/audio_engine/data/soloud_audio_engine.dart`

**Pasos:**

1. **Nuevos campos:**

   ```dart
   List<PlaybackDevice>? _deviceSnapshot; // enumeración del arranque actual
   int? _preferredDeviceId;               // pedido por initializeAndRestoreDevice
   int? _openedDeviceId;                  // con qué dispositivo se abrió realmente
   ```

2. **En `_doInitialize()`:**
   - `final devices = _deviceSnapshot = _safeListDevices();`. Es la **única** enumeración del arranque.
   - Resolver el destino:

     ```dart
     final preferred = devices.where((d) => d.id == _preferredDeviceId).firstOrNull;
     final target = preferred ?? devices.firstWhere((d) => d.isDefault, orElse: () => devices.first);
     ```

   - En escritorio, abrir directamente con `_soloud!.init(device: target, ...)`. En Android e iOS seguir pasando `device: null`, como ahora.
   - Tras abrir: `_openedDeviceId = target.id`.

3. **En `initializeAndRestoreDevice(savedDeviceId)`:**
   - Poner `_preferredDeviceId = savedDeviceId;` **antes** de `await _ensureInitialized()`.
   - Usar `final devices = _deviceSnapshot ?? _safeListDevices();` en lugar de volver a enumerar (línea 363).
   - `needsDeviceSwitch = targetDeviceId != _openedDeviceId;` sustituye a la condición por plataforma de la línea 408.

4. **`_changeDevice(int deviceId, {List<PlaybackDevice>? devices})`:** usar la lista recibida y enumerar solo si llega `null`. Es el caso de `selectOutputDevice`, que lo pide el usuario y es legítimo.

5. **En `retryAudioInitialization`:** poner `_deviceSnapshot = null` para forzar una enumeración nueva. El usuario pudo haber conectado un dispositivo.

**Aceptación:**

- Por arranque: 1 llamada a `listPlaybackDevices` y 1 apertura de dispositivo (añade marcas de T0 alrededor de cada una).
- Un dispositivo guardado que ya no existe → cae al por defecto con el aviso actual.
- Uno que sí existe → se abre directamente, sin cambio posterior.

- [ ] Hecho

---

## T5: Licencia en paralelo, huella rápida y procesos con timeout real (F15, F14 parcial)

**Archivos:**

- Nuevo: `lib/core/platform/process_runner.dart`
- `lib/core/security/device_fingerprint.dart`
- `lib/core/platform/device_tier.dart`
- `lib/features/licensing/presentation/providers/license_providers.dart`
- `lib/main.dart`

**Pasos:**

1. **`process_runner.dart`**, compartido por la GPU y la huella (evita duplicar código):

   ```dart
   /// Ejecuta un proceso con límite de tiempo REAL: si vence, lo mata.
   /// Devuelve null en timeout o si el ejecutable no existe.
   Future<ProcessResult?> runProcessWithTimeout(
     String executable, List<String> args, Duration timeout) async {
     final Process proc;
     try {
       proc = await Process.start(executable, args);
     } on ProcessException {
       return null;
     }
     final stdout = proc.stdout.transform(systemEncoding.decoder).join();
     final stderr = proc.stderr.transform(systemEncoding.decoder).join();
     try {
       final code = await proc.exitCode.timeout(timeout);
       return ProcessResult(proc.pid, code, await stdout, await stderr);
     } on TimeoutException {
       proc.kill();
       return null;
     }
   }
   ```

   - `device_tier.dart:118` y `device_fingerprint.dart:192` pasan a usarlo: 3 s para la GPU, 8 s para la huella.

2. **Huella rápida (solo Windows):** en `DeviceFingerprint.generate()`, si existe el registro persistido `{f, s}`, devolver `f` de inmediato y revalidar en segundo plano:

   ```dart
   if (Platform.isWindows && persisted != null) {
     _cachedFingerprint = persisted.f;
     unawaited(_revalidateInBackground(persisted)); // compara stabilitySignature
     return persisted.f;
   }
   ```

   - Si la revalidación detecta otra firma, llama a un callback `onFingerprintChanged` que dispare `licenseProvider.notifier.sync()`.
   - Solo en Windows, porque es donde la huella cuesta un proceso externo. El almacén persistido va con DPAPI, ligado al usuario y a la máquina.
   - **No aplicar en Android:** la réplica en `shared_preferences` viaja con Auto Backup y permitiría arrancar con la huella de otro dispositivo.

3. **Lanzar la validación en paralelo.** El orden importa:
   - **Después** de la Fase 1: `AppStorageService.initialize()` migra `flutter_secure_storage.dat` en Windows.
   - **Después** de la Fase 2: `_cleanKeychainIfNeeded` borra claves en la primera instalación.
   - **En paralelo** con la Fase 2.5 (BD).

   ```dart
   // Tras la Fase 2:
   final secureStorage = SecureStorageImpl();
   final licenseManager = LicenseManager(
     secureStorage: secureStorage,
     fingerprint: DeviceFingerprint.withPersistentStorage(secureStorage),
   );
   final licenseCheck = licenseManager.validateLicense(); // sin await aquí
   // ... Fase 2.5 ...
   // en _AppServices: licenseManager, licenseCheck, secureStorage
   ```

   En el `ProviderScope`:

   ```dart
   secureStorageProvider.overrideWithValue(services.secureStorage),
   licenseManagerProvider.overrideWithValue(services.licenseManager),
   licenseProvider.overrideWith((ref) => LicenseNotifier(
     ref.read(licenseManagerProvider), preloaded: services.licenseCheck)),
   ```

   `LicenseNotifier` recibe `Future<Result<LicenseInfo>>? preloaded` y, si existe, lo espera con el mismo `_checkBudget` en lugar de volver a llamar a `validateLicense()`.

4. **Timeout ≠ sin licencia.** Añadir `LicenseLoadingState.timeout`:
   - En `_buildLicenseGate`, ese estado muestra una pantalla "No se pudo verificar la licencia" con **Reintentar**, **no** `ActivationScreen`, que pide la clave.
   - El `catch` de la línea 94 distingue `TimeoutException` (→ `timeout`) de cualquier otro error (→ `error`).

**Tests:**

- `LicenseNotifier` con un `preloaded` que termina: pasa a `licensed`.
- Con un `preloaded` que vence: pasa a `timeout`, no a `unlicensed`.
- `runProcessWithTimeout` con un ejecutable inexistente devuelve `null`.

**Aceptación:**

- En Windows, el segundo spinner (licencia) desaparece o dura menos de 300 ms en arranques posteriores al primero.
- Con WMI bloqueado (simúlalo renombrando temporalmente la ruta de `powershell`), un usuario con licencia **no** ve la pantalla de activación.

**Riesgo:** medio. Es la capa de seguridad de la licencia. No toques `Spp3Token.verify` ni la derivación del hash.

- [ ] Hecho

---

## T6: Detección de GPU: caché + regex corregida (F13, F14)

**Archivo:** `lib/core/platform/device_tier.dart`. El test va en `test/core/platform/device_tier_test.dart`.

**Pasos:**

1. **Extraer una función pura y testeable:**

   ```dart
   /// true solo para GPUs que ANGLE no puede servir con D3D11 (DX10.1 o inferior).
   @visibleForTesting
   bool isLegacyGpuName(String adapter) {
     final n = adapter.toLowerCase();
     // Intel "HD Graphics" sin número o 2000/2500/3000. "UHD" y la serie 5xx/6xx son modernas.
     final intel = RegExp(r'(?<!u)hd graphics(?:\s+(\d+))?\s*$').firstMatch(n);
     if (intel != null) {
       final gen = intel.group(1);
       if (gen == null) return true;
       return gen.length == 4 && int.parse(gen) < 4000;
     }
     if (n.contains('gma')) return true;
     if (RegExp(r'geforce\s+[89]\d{3}\b').hasMatch(n)) return true; // 8xxx/9xxx de 4 cifras
     if (RegExp(r'geforce\s+[23]\d0m?\b').hasMatch(n)) return true; // 210/310/320M
     if (RegExp(r'radeon hd [56]\d{3}\b').hasMatch(n)) return true;
     if (n.contains('quadro fx')) return true;
     return false;
   }
   ```

2. **Varios adaptadores:** partir la salida de CIM por líneas. `_reducedGpu = adapters.isNotEmpty && adapters.every(isLegacyGpuName)`. Con una sola GPU moderna, no se degrada.

3. **Caché:** `SharedPreferences` con la clave `gpu_probe_v1` = `{"os": Platform.operatingSystemVersion, "reduced": bool}`.
   - Si coincide el SO, usar el valor cacheado y relanzar la sonda **en segundo plano** (`unawaited`) para el próximo arranque.
   - Sin caché (primer arranque), sonda con `runProcessWithTimeout` (T5) de 3 s.

**Tabla del test (entrada → esperado):**

| Adaptador | Legacy |
|---|---|
| Intel(R) HD Graphics | sí |
| Intel(R) HD Graphics 3000 | sí |
| Intel(R) HD Graphics 4600 | no |
| Intel(R) HD Graphics 520 | no |
| Intel(R) UHD Graphics 620 | no |
| Intel(R) Iris(R) Xe Graphics | no |
| NVIDIA GeForce 9400 GT | sí |
| NVIDIA GeForce 940MX | no |
| NVIDIA GeForce 210 | sí |
| NVIDIA GeForce GTX 1050 | no |
| AMD Radeon HD 6450 | sí |
| UHD 630 + RTX 3060 (lista) | no |

**Aceptación:** tabla en verde. El segundo arranque en Windows no lanza PowerShell en el camino crítico.

- [ ] Hecho

---

## T7: Cola de carga de audio con concurrencia limitada (F10)

**Archivos:**

- Nuevo: `lib/features/audio_engine/data/audio_load_scheduler.dart`
- `soloud_audio_engine.dart`
- `pad_providers.dart:228-237`

**Diseño:**

- Prioridad a lo visible.
- Cancela lo pendiente cuando cambias de página.
- Deduplica por `id`.
- Sin dependencias nuevas.

```dart
/// Carga audios en segundo plano sin saturar CPU/RAM.
/// - [maxConcurrent] cargas simultáneas como máximo.
/// - `replaceQueue` descarta lo PENDIENTE (no lo que ya corre) y encola lo nuevo:
///   la última página abierta gana.
class AudioLoadScheduler {
  AudioLoadScheduler({required this.maxConcurrent, required Future<void> Function(String, String) load})
      : _load = load;

  final int maxConcurrent;
  final Future<void> Function(String id, String path) _load;
  final _pending = LinkedHashMap<String, String>(); // id -> path, en orden
  int _running = 0;

  void replaceQueue(Map<String, String> idToPath) {
    _pending
      ..clear()
      ..addAll(idToPath);
    _pump();
  }

  void _pump() {
    while (_running < maxConcurrent && _pending.isNotEmpty) {
      final id = _pending.keys.first;
      final path = _pending.remove(id)!;
      _running++;
      _load(id, path).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }
}
```

**Pasos:**

1. **En `SoLoudAudioEngine`:** crear el scheduler después de `_doInitialize`. El `load` es `loadAudio`, que ya deduplica con `_loadingIds` y la caché.
   - `maxConcurrent` hasta la Fase 3: `low → 1`, `mid → 2`, `high → (Platform.numberOfProcessors ~/ 2).clamp(2, 4)`.

2. **Reutilizar `preloadAll`,** que existe en el port y hoy nadie usa:

   ```dart
   @override
   Future<void> preloadAll(Map<String, String> idToPath) async {
     _preloadScheduler.replaceQueue(idToPath);
   }
   ```

   Documenta en `audio_engine_port.dart` que es "sustituye la cola de precarga; no espera".

3. **En `pad_providers.dart:230-237`,** sustituir el `for` por:

   ```dart
   final toLoad = {
     for (final pad in entities)
       if (pad.sampleId != null && !audioEngine.isLoaded(pad.id)) pad.id: pad.sampleId!,
   };
   if (toLoad.isNotEmpty) unawaited(audioEngine.preloadAll(toLoad));
   ```

   `entities` ya viene en `sortByPadId()`, que es el orden visual, así que los primeros pads visibles se cargan antes.

4. **`onPadDown` (línea 1448) no pasa por la cola:** sigue llamando a `loadAudio` directamente. Un toque del usuario es urgente.

5. **`assignSampleToPad` y los diálogos** siguen con `loadAudio` directo: es una sola carga.

**Tests:** `test/audio_load_scheduler_test.dart` con un `load` falso basado en `Completer`:

- Nunca hay más de `maxConcurrent` a la vez.
- `replaceQueue` descarta lo pendiente.
- Un error en una carga no detiene la cola (`whenComplete`).

**Aceptación:** al abrir una página de 64 pads en Android de gama media, ningún frame supera 32 ms en el Timeline, y el primer toque suena, aunque su audio no se hubiera precargado todavía.

- [ ] Hecho

---

## T8: Audio después de mostrar la UI (F09)

**Depende de:** T4.

**Archivos:**

- `lib/main.dart`
- `lib/core/providers/audio_providers.dart`
- Nuevo: `lib/core/audio/audio_bootstrapper.dart`

**Pasos:**

1. **Mover `_initAudioSafe` de `main.dart` a `AudioBootstrapper.start(engine, savedDeviceId)`.** Mismo timeout y mismos mensajes.

2. **En `_initialize()`:**
   - Crear el `SoLoudAudioEngine` y aplicar `setSoundCacheCapacity`, pero **no** inicializarlo.
   - Quitar `audioInitResult` de `_AppServices` y quitar el override de `audioInitializationCacheProvider`. Ya vale `null` → estado `initializing` → el overlay existente bloquea los pads.

3. **En `_SamplePadProAppState.initState`,** en `addPostFrameCallback`:

   ```dart
   final engine = ref.read(audioEngineProvider);
   final saved = ref.read(settingsServiceProvider).audioOutputDeviceId;
   AudioBootstrapper.start(engine, saved).then((result) {
     if (mounted) ref.read(audioInitializationCacheProvider.notifier).state = result;
   });
   ```

4. **Actualizar el comentario de `audioInitializationCacheProvider`:** ya no lo inyecta el bootstrap.

5. **Revisar `_AudioNotReadyOverlay`:** con `initializing` debe mostrar "Iniciando audio…" sin botón de reintentar.

**Advertencia:** mientras T12 (F08) no esté hecha, en Android el init nativo sigue bloqueando el hilo de UI hasta 5 s. La diferencia es que ahora ocurre con la app ya visible. En escritorio, tras T4, el bloqueo es breve.

**Aceptación:** `firstAppFrame` y `interactive` de T0 ya no incluyen el tiempo de audio. Si falta el dispositivo, el overlay muestra `noDevice` con Reintentar, igual que ahora.

- [ ] Hecho

---

## T9: `runApp` sin esperar al log y reintento seguro (F18, F17, F26)

**Archivos:** `lib/core/services/crash_log_service.dart` y `lib/main.dart`

**Pasos:**

1. **Partir `CrashLogService.initialize()` en dos:**
   - `installHandlers()`: síncrono. `FlutterError.onError`, `PlatformDispatcher.onError`, `ErrorWidget.builder`.
   - `attachLogFile()`: asíncrono. Rotación y apertura de **un único** `IOSink` (`openWrite(mode: FileMode.append)`). Al abrirse vuelca `_inMemoryLogs` pendientes.
   - `log()` escribe en el sink si existe; si no, solo en memoria.

2. **En `main()`:**

   ```dart
   CrashLogService.installHandlers();
   runApp(const _BootstrapApp());
   unawaited(CrashLogService.attachLogFile());
   ```

3. **En `_initialize()`, catch de la Fase 2.5:**
   - Llamar a `rollbackFailedRestore()` **solo** si `e is DatabaseUnavailableException`, es decir, si Isar no llegó a abrir. Con `TimeoutException`, relanzar sin rollback: nunca renombres el archivo de una BD que puede estar abierta.
   - Tras T1, bajar el presupuesto de la BD de 40 s a 20 s. Ahora solo abre.

4. **Reintento:** `onRetry` ignora pulsaciones mientras hay un `_initialize()` en vuelo, con un bool `_initializing` en el `State`.

**Aceptación:**

- En Windows la ventana aparece antes (marca `runApp` de T0).
- El log conserva el orden de las líneas.
- Pulsar Reintentar varias veces seguidas no lanza bootstraps paralelos.

- [ ] Hecho

---

# FASE 2: Estructural

## T10: Inserciones por lotes en la reconciliación (F02)

**Archivo:** `filesystem_sync_service.dart:341-379`

- Acumular los `PadModel` nuevos de cada carpeta en una lista.
- Tras el bucle de hijos, una sola transacción:

  ```dart
  await isar.writeTxn(() async {
    await isar.padModels.putAll(newPads);
    for (final pad in newPads) {
      await pad.page.save();
    }
  });
  ```

- Las carpetas nuevas (páginas ocultas + pad carpeta) necesitan el `id` de la página para la recursión: mantenlas en su propia transacción, que son pocas. Solo se agrupan los pads de audio.

**Aceptación:** 1.000 archivos nuevos en una carpeta → 1 commit (antes 1.000). El test de `filesystem_sync_service_test` sigue en verde.

- [x] Hecho

## T11: Consultas por link sin recorrer la colección (F05)

**Enfoque sin migrar el esquema.** Hay 39 sitios que construyen `PageModel`/`PadModel`; desnormalizar sería caro y arriesgado. Las consultas `filter().workspace(...)` / `filter().page(...)` pueden recorrer toda la colección. Se sustituyen por consultas **sobre el link**, que usan la tabla de enlaces:

```dart
// Antes
isar.pageModels.filter().workspace((w) => w.idEqualTo(ws.id)).pageIndexEqualTo(i).findFirst();
// Después
ws.pages.filter().pageIndexEqualTo(i).findFirst();

// Antes (pad_providers.dart:198)
isar.padModels.filter().page((q) => q.idEqualTo(page.id)).sortByPadId().findAll();
// Después
page.pads.filter().sortByPadId().findAll();
```

**Sitios:**

- `filesystem_sync_service.dart`: 180, 204, 226, 410, 453, 472.
- `pad_providers.dart:191-203`.
- Buscar el resto con `grep -rn "filter()\s*\.\s*workspace(\|filter()\s*\.\s*page(" lib`.

**Medición obligatoria:** compara con T0 antes y después con 5.000 pads. Si no mejora de forma medible, descarta el cambio: no es un bloqueo crítico. Solo si la medición lo justifica, plantea índices con migración.

- [x] Hecho

## T12: Apertura del audio nativo asíncrona en Android (F08)

**Archivos:**

- `third_party/flutter_soloud/src/soloud/src/backend/miniaudio/soloud_miniaudio.cpp`
- `src/bindings.cpp`
- `lib/src/bindings/*`
- `lib/src/soloud.dart`

**Diseño:**

1. **`initEngine` en Android:** lanza el worker (ya existe `android_device_open_worker`) y **devuelve de inmediato** un nuevo código `initPending`, en lugar de esperar con `wait_until`.
2. **Al terminar, el worker publica el resultado** por el mecanismo de callbacks a Dart que el plugin ya usa para `loadFile` (`NativeCallable.listener`).
3. **`SoLoud.init()` en Dart:** si recibe `initPending`, espera un `Completer` que completa el callback y le aplica un `timeout` Dart que **ahora sí puede dispararse**, porque el hilo está libre. Al vencer, marca el intento como abandonado (el flag `gAndroidInitAbandoned` ya existe).
4. **La cadena de 3 intentos de `SoLoudAudioEngine`** queda igual. Cada intento espera sin bloquear.

**Pruebas en dispositivo, obligatorias:** Android API 29 con 2 GB, Android 14 de gama media y Galaxy S25 (16 KB). Durante el init, la animación del overlay no se detiene.

**Riesgo:** alto (C++ vendorizado y ciclo de vida del hilo). Mantén el comportamiento actual detrás de un `#define` hasta validarlo.

- [x] Hecho

## T13: Restaurar el mezclador al arrancar (F21)

**Archivos:**

- Nuevo: `lib/features/settings/data/services/mixer_settings_service.dart`
- `master_mixer_panel.dart`
- `audio_bootstrapper.dart` (T8)

**Pasos:**

- `MixerSettingsService(SharedPreferences)` con `load() → MixerSettings` y `save(MixerSettings)`. Mismas claves `mixer_*`, así que no hay migración.
- `AudioBootstrapper`, cuando el resultado es `ready`, aplica `MixerSettings` al motor y fija `masterVolumeProvider`.
- `master_mixer_panel.dart` lee y escribe a través del servicio. Borrar `_loadSavedMixerSettings` y `_saveMixerSettings`.

**Aceptación:** con reverb y volumen 0,6 guardados, tras reiniciar suena igual sin abrir el panel.

- [x] Hecho

## T14: Estado de reproducción por pad (F22)

**Archivos:**

- `pad_providers.dart`
- `pad_grid_view.dart`
- `pad_button.dart`

**Pasos:**

- Nuevo `padRuntimeStateProvider = StateProvider.family<PadState, String>((ref, id) => PadState.idle)`. También puede ser un `Notifier` con `Map<String, PadState>` y `select` por id.
- `_setPadState` escribe ahí y **no** reemplaza la lista de la página.
- `PadButton` hace `ref.watch(padRuntimeStateProvider(pad.id))`. La lista de `padPageProvider` solo cambia con cambios estructurales (añadir, mover, editar).
- Migrar las lecturas de `pad.state`: `PadTriggerResolver.onDown(pad.playMode, pad.state)`, `_runtimeStates`, las macros y el MIDI.

**Aceptación:** en DevTools, con "Track widget rebuilds", un toque reconstruye 1 `PadButton`, no todos.

- [x] Hecho

## T15: Watcher incremental y pausado durante importaciones (F23)

**Archivos:** `filesystem_sync_service.dart` y los importadores (`workspace_importer`, `project_importer`, `workspace_zip_importer`, `pad_add_actions`, `folder_transfer_service`).

**Pasos:**

- Acumular las rutas de los eventos durante el debounce y reconciliar solo los workspaces de primer nivel afectados. Extraer `reconcileWorkspaceDir(isar, dirName)` de `reconcileOnStartup`.
- Añadir `FilesystemSyncService.suspend()` / `resume()` (un contador anidable). Cada importación interna lo envuelve en `try/finally`. Al hacer `resume`, reconciliación de los workspaces tocados.

**Aceptación:** importar una carpeta de 300 audios desde la app no crea pads duplicados; copiar 1 archivo con el Explorador solo reconcilia su workspace.

- [x] Hecho

## T16: Importaciones ZIP en streaming (F24)

**Archivos:**

- `config_backup_service.dart:215-241`
- `folder_transfer_service.dart:254-264`
- `project_importer.dart`
- `workspace_zip_importer.dart`

**Pasos:**

- `FilePicker.pickFiles(...)` **sin** `withData: true`. Usar `files.single.path`.
- Si en Android llega `path == null` (proveedor SAF), usar `readStream` del picker y volcarlo por partes a `AppStorageService.workDirectory('import')`.
- Pasar **la ruta** al isolate (no los bytes). Dentro: `InputFileStream(path)` + `ZipDecoder().decodeStream(...)` del paquete `archive` 4.x, que ya es dependencia. Extraer cada entrada a disco con `OutputFileStream`.
- Devolver al isolate principal solo metadatos y rutas extraídas, no un `Archive` completo.

**Aceptación:** respaldo de 1 GB en Android de 3 GB sin cierre; pico de RAM < 150 MB sobre la base (`dumpsys meminfo`).

- [x] Hecho

## T17: Revalidación de licencia con intervalo mínimo (F16)

**Archivos:** `license_providers.dart:178` y `license_manager.dart`

- `sync()` solo revalida si pasaron más de 30 min desde `lastLicenseCheckUtc`. Mantener la protección anti-retroceso de reloj.
- `_saveActivationData`: escribir solo los valores que cambiaron (lee y compara antes).

- [x] Hecho

---

# FASE 3: Adaptación al hardware

## T18: `DeviceProfile` en vez de `DeviceTier` fijo (F12)

**Archivos:**

- `lib/core/platform/device_tier.dart` (renombrar a `device_profile.dart`)
- Consumidores de `DeviceTierDetector`
- `settings_service.dart`
- `settings_screen.dart`

**Señales:**

| Señal | Windows | macOS | Android |
|---|---|---|---|
| RAM total | Sonda WMI existente o `GlobalMemoryStatusEx` vía runner | `sysctl hw.memsize` (MethodChannel en `AppDelegate`) | `/proc/meminfo` MemTotal (ya existe) |
| RAM disponible | `GlobalMemoryStatusEx` | `host_statistics64` | `/proc/meminfo` MemAvailable |
| Núcleos | `Platform.numberOfProcessors` | idem | idem |
| GPU | T6 | — | — |
| SDK | — | — | `sdkInt` (ya existe) |

**Puntuación:**

- `low`: RAM ≤ 4 GB **o** núcleos ≤ 2 **o** (Android con SDK < 26).
- `high`: RAM ≥ 12 GB **y** núcleos ≥ 8.
- `mid`: resto.
- Override manual en Ajustes → "Perfil de rendimiento: Automático / Ahorro / Equilibrado / Máximo". Nueva clave `performance_profile`.

**Parámetros que decide el perfil (un solo sitio):**

| Parámetro | low | mid | high |
|---|---|---|---|
| Presupuesto de caché de audio (T19) | 10 % de la RAM total, máx. 256 MB | 15 %, máx. 768 MB | 20 %, máx. 2 GB |
| Cargas simultáneas (T7) | 1 | 2 | min(4, núcleos/2) |
| Umbral para `LoadMode.disk` (T19) | > 30 s | > 90 s | > 180 s |
| Visualización | bajo demanda | bajo demanda | bajo demanda |
| Efectos visuales reducidos | sí | según GPU | según GPU |
| Polling de voces | 75 ms | 50 ms | 25 ms |

**Aceptación:** tests unitarios de la puntuación con entradas simuladas; en Ajustes → Diagnóstico se muestra el perfil y sus señales.

- [x] Hecho

## T19: Caché de audio por bytes y streaming para archivos largos (F11)

**Archivos:**

- `lib/core/utils/lru_cache.dart`
- `soloud_audio_engine.dart`
- `settings_screen.dart` (el ajuste de capacidad existente)

**Pasos:**

1. **`LruCache` acepta un `weigher`** opcional:
   - `LruCache<K,V>(capacity, {int Function(V)? weigh, int? maxWeight})`.
   - Desaloja mientras `totalWeight > maxWeight` **o** `length > capacity`.
   - Mantiene `onEvict` y la disposición diferida actual (los sonidos que suenan no se liberan).

2. **Peso de un sonido:**

   ```dart
   int estimateBytes(AudioSource s) =>
       (_soloud!.getLength(s).inMicroseconds * 48000 * 2 * 4 / 1e6).round();
   ```

   Estimación conservadora: 48 kHz, estéreo, float32.

3. **Antes de cargar,** si la duración supera el umbral del perfil, cargar con `LoadMode.disk` (`WavStream`).
   - La duración se lee con `SoLoud.getLength` tras una carga en disk, o se estima por el tamaño de archivo y la extensión si prefieres no cargar dos veces.
   - `WavStream` reproduce con **la misma calidad**: decodifica al vuelo en lugar de precargar.

4. **Probar a fondo los pads con `loopPoint`, `startPoint` y `reverse` en modo disk.** Si alguno falla (seek en MP3), mantener `LoadMode.memory` para ese pad (añade la condición `pad.reverse || pad.startPoint > 0` → memory). Anótalo en el código.

5. **El ajuste "capacidad de caché" de Ajustes** pasa a ser el tope de número. El de memoria lo decide el perfil.

**Aceptación:** 30 min recorriendo páginas con pistas largas → RAM estable (±10 %) y ≤ presupuesto del perfil. Sin huecos audibles en loops.

- [x] Hecho

## T20: Visualización bajo demanda (F20)

**Archivos:** `soloud_audio_engine.dart:242` y `master_mixer_panel.dart`

- En `_doInitialize`: `setVisualizationEnabled(false)` siempre.
- `MasterMixerPanel.initState` → `engine.setVisualizationEnabled(true)`; `dispose` → `false`.
- Borrar `DeviceTierDetector.enableVisualizationByDefault`, que queda sin uso.

- [x] Hecho

---

# FASE 4: Pulido y limpieza

| ID | Tarea | Archivo | Detalle |
|---|---|---|---|
| T21 | Logo del splash redimensionado (F19) | `main.dart:345`, `activation_screen.dart:109`, `storage_permission_gate.dart:134` | `cacheWidth: (104 * MediaQuery.devicePixelRatioOf(context)).round()` |
| T22 | Quitar E/S síncrona de la UI (F25) | `local_audio_storage_service.dart:102`, `workspace_importer.dart:144/287`, `project_importer.dart:178`, `workspace_zip_importer.dart:120`, `zip_utils.dart:26`, `pad_add_actions.dart:551/620`, `main_pad_page.dart:694` | Variantes asíncronas (`exists()`, `list()`) |
| T23 | Borrar la copia vendorizada sin uso | `frontend/third_party/isar_flutter_libs/` | Ya no está en `pubspec.yaml`. Quitarla también de `analysis_options.yaml` |
| T24 | Borrar el respaldo versionado | `frontend/pubspec.yaml.bak` | — |
| T25 | Quitar el asset duplicado | `pubspec.yaml` (`assets/icon/app_icon.png`) + archivo | Mismo MD5 que `logo.png`, sin referencias en Dart. Comprueba antes `installer.iss` y los scripts de icono |
| T26 | Consolidar el helper de tests | 6 tests con `_isarNativeLibPath()` | Mover a `test/helpers/isar_test_helper.dart` |
| T27 | Precarga de la página siguiente | `pad_providers.dart` | Solo perfil `high` y con la cola de T7 vacía: encolar la página de las carpetas visibles con prioridad baja |

---

# FASE 5: Importación en Android y publicación

## T28: Explorador "Desde el dispositivo" por MediaStore

**Problema:** desde Android 11, el selector de carpetas del sistema (SAF) no deja elegir la raíz de Descargas ni la del almacenamiento, aunque la app tenga todos sus permisos. Es justo donde más usuarios guardan sus efectos.

**Solución:** un explorador propio que lee la biblioteca de audio de Android (MediaStore) con el permiso que ya existe (`READ_MEDIA_AUDIO`; `READ_EXTERNAL_STORAGE` en Android ≤ 12). No hace falta "Todos los archivos".

**Nativo** (`MainActivity.kt` o un `MediaStoreAudioBrowser.kt` nuevo; mismo canal que `pickTree`):

1. `listAudioFolders()`:
   - Consulta `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI` con las columnas `_ID`, `DISPLAY_NAME`, `SIZE`, `RELATIVE_PATH` (API 29+) o `DATA` (API < 29) y `VOLUME_NAME`.
   - Agrupa por carpeta y devuelve `[{path, volume, count, totalBytes}]`, ordenado por nombre.
   - Filtra por extensión con la misma lista que `LocalAudioStorageService.supportedAudioExtensions`, no por `MIME_TYPE`: algunos fabricantes indexan mal WAV y FLAC.
   - Ejecútalo en un hilo de fondo (el `Executor` que ya usa SAF) y devuelve el resultado por el canal.
2. `listAudioFiles(folderPath, recursive)`: devuelve `[{uri, name, relativeSubPath, size}]` de esa carpeta y, si `recursive`, de sus subcarpetas (prefijo de `RELATIVE_PATH`).
3. `copyAudioFiles(items, destDir)`:
   - Copia cada `content://` con `contentResolver.openInputStream(uri)` a `destDir/relativeSubPath/name`, con búfer de 64 KB e informando del progreso por el canal.
   - Antes de copiar, comprueba el espacio con `StatFs`: `max(200 MB, 10 %)`, el mismo criterio y mensaje que `SafTreeImporter`.
   - Copia directamente a la carpeta de audio de la app, **sin pasar por la caché**.

**Dart:**

4. `MediaStoreAudioService` en `lib/core/services/` con los tres métodos y modelos tipados (`AudioFolderEntry`, `AudioFileEntry`).
5. Pantalla `DeviceAudioBrowserScreen`:
   - Lista de carpetas con recuento ("Download · 23 audios", "Download/Efectos · 40 audios"), un buscador y una casilla "Incluir subcarpetas".
   - Selección de una o varias carpetas y confirmación: "Importar 63 audios (412 MB)".
   - La importación reutiliza `_confirmAndImportTree` (carpetas → pads carpeta, audios → pads) dentro de `LibraryWriteLock` y `FilesystemSyncService.suspend()`.
6. Menú de importar en Android, en este orden:
   1. **Desde el dispositivo** (MediaStore): camino principal.
   2. **Elegir carpeta…** (SAF): para carpetas con `.nomedia` o fuera del índice.
   3. **Elegir audios…** (selección múltiple): para cualquier sitio, incluidas las nubes.
   - Aplica el mismo menú a "Importar workspace" (la carpeta elegida se convierte en workspace) y a "Importar carpeta".
7. **Permiso:** si `READ_MEDIA_AUDIO` no está concedido, pedirlo al abrir el explorador. Si se deniega, mostrar las opciones 2 y 3 con el motivo: "Sin el permiso de Música y audio no puedo listar tus carpetas. Puedes elegir una carpeta o audios sueltos."
8. **Estado vacío:** si MediaStore no devuelve nada, mostrar "No encontré audios en tu dispositivo. Si acabas de copiarlos, espera unos segundos o usa 'Elegir carpeta…'", en lugar de una lista vacía sin explicación.

**Tests:**

- Dart: agrupación y orden de carpetas, filtrado por extensión y construcción del árbol a partir de `relativeSubPath`, con un `MediaStoreAudioService` falso.
- Kotlin (instrumentado, opcional): consulta sobre un emulador con archivos sembrados.

**Pruebas reales (Honor X7c, Android 14):**

- Audios sueltos en la **raíz de Descargas** → aparecen y se importan.
- Carpeta `WhatsApp Audio` → aparece.
- Carpeta con `.nomedia` → no aparece aquí (esperado); se importa por "Elegir carpeta…".
- Permiso denegado → mensaje y alternativas.
- Poco espacio → mensaje con los MB necesarios.

**Aceptación:** un usuario con los efectos sueltos en Descargas los importa sin mover archivos, sin permisos nuevos y en menos de tres toques desde el menú.

- [x] Hecho

---

## T29: Versión 1.0.4 y publicación

1. **Subir la versión a `1.0.4+5`** en `pubspec.yaml` y en `distribution/installer.iss`. Todos los cambios de este plan salen en esta versión; con la misma 1.0.3, ni el cliente ni `preflight_release.py` distinguen los binarios nuevos de los viejos (el preflight compara versiones, no fechas).
2. **Compilar en limpio:**
   - APK en local (`flutter clean && flutter build apk --release`).
   - Windows con Inno Setup.
   - macOS con GitHub Actions.
3. **`python tools/preflight_release.py --write-checksums`** sobre esos binarios nuevos, no sobre los anteriores.
4. **Pruebas reales mínimas antes de enviar:**
   - Windows + rekordbox + DDJ-FLX4: aviso con el nombre correcto, los pads siguen sonando por la salida anterior, "Probar salida" funciona y la salida se mantiene tras cambiar de puerto USB.
   - Honor X7c: T28 más la importación por SAF (subcarpeta de Descargas, `.nomedia`, WhatsApp), el margen de espacio y el borrado de un pad que comparte archivo con otro.
   - Un arranque con biblioteca grande en cada plataforma, anotando las marcas de T0 en la tabla.
5. **T12:** pruebas en API 29 con 2 GB, Android 14 de gama media y Galaxy S25 (retraso simulado de 10 s y paso a segundo plano). `BDJ_ASYNC_AUDIO_INIT` sigue desactivado hasta que las tres pasen.
6. **Enviar la 1.0.4** a los clientes afectados (FLX4 e importación en móvil), con la guía de conexión que empieza por el cable a la mezcladora o al parlante.

- [ ] Hecho

---

# Validación final por plataforma

**Windows:**

- [ ] Doble clic → ventana visible < 500 ms.
- [ ] Grid tocable < 2 s (equipo medio), con 50 y con 5.000 pads.
- [ ] 0 PowerShell en el camino crítico en arranques posteriores al primero.
- [ ] Portátil Intel UHD + NVIDIA → efectos completos.
- [ ] Desconectar la interfaz de audio con la app abierta → overlay `noDevice` → reconectar → Reintentar funciona.

**macOS:**

- [ ] Arranque en Apple Silicon de 8 GB con biblioteca grande < 2 s hasta interactivo.
- [ ] 30 min de sesión → RAM estable.

**Android:**

- [ ] Gama baja (2–3 GB, API 29): el overlay de audio no se congela (tras T12); abrir una página de 64 pads sin frames > 32 ms.
- [ ] Galaxy S25 (páginas de 16 KB): abre, suena, `tools/preflight_release.py` en verde.
- [ ] Importar un respaldo de 1 GB sin cierre.
- [ ] Sin conexión: arranque idéntico.

**Regresión funcional (todas las plataformas):**

- [ ] Restaurar respaldo y rollback de respaldo fallido.
- [ ] Carpetas, macros, MIDI learn, choke groups, loops, reverse, fades.
- [ ] Cambio de workspace y página; copiar archivos con el explorador del SO con la app abierta y cerrada.
- [ ] `flutter analyze` sin incidencias y `flutter test` en verde.
