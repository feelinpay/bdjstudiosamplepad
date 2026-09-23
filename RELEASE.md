# Distribución y publicación

BDJ Studio Sample Pad se distribuye **directamente**, fuera de tiendas, para uso
personal y sin coste.

El reparto de trabajo es: **Android y Windows se compilan en local**, porque el
equipo de desarrollo es Windows y tiene todo lo necesario. **macOS se compila en
GitHub Actions**, porque es la única forma de acceder a un Mac.

---

## Procedimiento para publicar una versión

### 1. Subir la versión

En `frontend/pubspec.yaml`, campo `version:` (formato `1.0.4+5`: nombre + número
de build). El número de build debe subir siempre, aunque el nombre no cambie.

No hace falta tocar `distribution/installer.iss`: acepta la versión desde fuera
(paso 3). El valor que lleva dentro es solo el respaldo para compilaciones
manuales, y el preflight avisa si se desincroniza.

### 2. Compilar

```bash
cd frontend
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter build apk --release          # deja el APK en distribution/ automáticamente
flutter build windows --release
```

`dart run build_runner` es obligatorio tras cambiar cualquier `@collection`.

### 3. Empaquetar Windows

```powershell
cd distribution
ISCC /DMyAppVersion=1.0.4 installer.iss
```

Pasar `/DMyAppVersion` es lo que evita que el instalador salga numerado con una
versión distinta a la del binario que lleva dentro.

### 4. Preflight — la puerta antes de repartir

```bash
python3 tools/preflight_release.py --write-checksums
python3 tools/preflight_release.py
```

Verifica de una vez las cosas que no se ven abriendo la app en el equipo de
desarrollo:

- **Coherencia de versión** entre `pubspec.yaml`, `installer.iss` y los nombres
  de los artefactos.
- **Alineación de 16 KB** de cada librería nativa de cada APK (ver más abajo).
- **Clave de firma**: detecta un APK firmado con la clave de debug de Android.
  Esa clave es pública y compartida por todo el SDK; un APK firmado con ella
  puede ser sustituido por cualquiera con una actualización falsa.
- **Checksums** SHA-256 de todo lo que se va a repartir.

Si sale `NO SE PUEDE DISTRIBUIR`, no se reparte. Es el único criterio.

### 5. Publicar

Android y Windows ya están listos en `distribution/` tras los pasos anteriores.
Para el binario de macOS:

```bash
git push origin main          # compila y deja el DMG/ZIP en Artifacts
git tag v1.0.4 && git push origin v1.0.4   # ademas publica un Release
```

Un push a `main` es un ensayo sin consecuencias: solo genera Artifacts. Los
Releases se crean únicamente al empujar un tag.

---

## Canales

| Canal | Qué es | Quién puede descargarlo |
|---|---|---|
| `distribution/` | APK y instalador de Windows, compilados en local. | Tú. |
| GitHub Artifacts | DMG y ZIP de macOS de cada build de `main`. Caduca a los 30 días. | Solo cuentas con acceso al repositorio. |
| GitHub Releases | Salida de un tag `vX.Y.Z`. Permanente. | Cualquiera. |

---

## Android — compilación local

`flutter build apk --release` produce el APK y lo deja en `distribution/` ya
renombrado, gracias a la tarea `copyReleaseApkToDistribution` de
`frontend/android/app/build.gradle.kts`. Se firma con el keystore de
`frontend/android/key.properties`, que no está versionado.

No hay workflow de Android en CI: el equipo de desarrollo compila Android sin
problema, así que la verificación se hace en local con el preflight (paso 4).

### Puerta de calidad: páginas de 16 KB

Los dispositivos que arrancan con páginas de memoria de 16 KB (Android 15+,
p. ej. Galaxy S25) **no pueden cargar librerías nativas alineadas a 4 KB**: el
enlazador rechaza el `dlopen()` y la app muere antes de pintar nada. Como solo
falla en esos móviles, el síntoma es *"no abre en algunos dispositivos"* y no se
reproduce ni en un emulador estándar ni en un móvil de 4 KB.

Esto es exactamente lo que ocurrió con `isar_flutter_libs 3.1.0` (ver la sección
de Isar), y es la razón de que el preflight sea obligatorio y no opcional:

```bash
python3 tools/check_16kb_alignment.py distribution/*.apk
```

`tools/preflight_release.py` ya lo ejecuta por dentro. Si alguna vez quieres la
comprobación oficial del SDK:

```bash
zipalign -c -P 16 -v 4 distribution/BDJ_Studio_Sample_Pad_1.0.3.apk
```

`android:pageSizeCompat` **no** es una solución: solo existe a partir de
Android 17 y no cubre los dispositivos afectados hoy.

### Compatibilidad con dispositivos antiguos

Cuatro decisiones del manifest existen por una razón concreta. Ninguna es
cosmética y ninguna debe quitarse sin entender qué rompe.

**`EnableImpeller = false`.** Fuerza el renderizador Skia. Impeller usa Vulkan,
y en GPUs de gama baja o antiguas (Mali, Adreno viejas, PowerVR) el driver
falla de una forma muy característica: el proceso arranca y vive, pero nunca
presenta un fotograma. El usuario ve una **pantalla negra**, no un cierre. Ya
pasó una vez: la línea se quitó del manifest y una tablet Samsung dejó de
pintar. En una app de pads —rectángulos de color, texto— la diferencia de
rendimiento entre Impeller y Skia es invisible; la diferencia de estabilidad no
lo es. **No se prueba en emulador**: el emulador usa el driver de la máquina
anfitriona, así que siempre funciona ahí.

**`uses-feature android.software.midi` con `required="false"`.**
`flutter_midi_command` lo declara como obligatorio. Si se deja así, Play Store
filtra y oculta la app a cualquier dispositivo sin hardware MIDI, que son casi
todas las tablets. El `tools:replace="android:required"` es lo que pisa la
declaración del plugin.

**`allowBackup="false"` + `backup_rules.xml` + `data_extraction_rules.xml`.**
La base es un archivo Isar. Un restore de Google Backup, o una transferencia
dispositivo-a-dispositivo, puede traer un `.isar` de otro equipo o de otra
versión del esquema y dejar la app sin abrir. En Android 12+ `allowBackup` solo
corta la copia en la nube: la transferencia D2D se controla aparte con
`dataExtractionRules`, por eso hacen falta los tres.

**`minSdk 24` (Android 7.0).** Por debajo de eso la app no instala — el síntoma
es *"aplicación no instalada"*, nunca una pantalla negra. Y como el mínimo llega
hasta Android 7, todo código nativo que use API 26+ necesita su guard explícito:
`PerformanceAudioService` crea el `NotificationChannel` dentro de un
`if (SDK_INT >= O)` justamente por esto.

El APK se compila con las tres ABIs (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
`armeabi-v7a` no es opcional: las tablets baratas de 32 bits que corren
Android 7-10 son exactamente el público que da problemas.

### R8 desactivado a propósito

`isMinifyEnabled` y `isShrinkResources` están en `false`. R8 rompe la reflexión,
y hay tres candidatos en el proyecto (Isar, `flutter_secure_storage`,
`flutter_midi_command`). El coste de tenerlo apagado es un APK de ~79 MB en vez
de ~50. Si algún día se activa, hay que probar el APK **release** completo en
hardware real, no solo comprobar que compila.

---

## macOS — `.github/workflows/macos-build.yml`

Produce un DMG y un ZIP por arquitectura (`arm64` y `x64`), más checksums.

### Firma ad-hoc, sin coste

El proyecto no paga el Apple Developer Program, así que no hay certificado
*Developer ID Application* ni notarización. La app se firma **ad-hoc**
(`codesign --sign -`), que es lo mínimo que exige macOS en Apple Silicon: un
binario arm64 sin firmar ni siquiera arranca.

La firma se hace *inside-out* — primero cada dylib y framework anidado, el
bundle principal al final — y no con `--deep`, que Apple tiene deprecado y que
sella mal los frameworks anidados de un bundle Flutter.

### Cómo abrir la app

Depende de cómo llegue al Mac:

- **Compilada en el propio Mac**: se abre con doble clic, sin más. Los archivos
  creados localmente no reciben el atributo de cuarentena.
- **Descargada** (Artifacts, Releases, AirDrop, correo): macOS le pone
  cuarentena y Gatekeeper la bloquea con *"está dañada y no se puede abrir"*.
  Se quita una vez, y ya queda abierta para siempre:

```bash
xattr -dr com.apple.quarantine "/Applications/BDJ Studio Sample Pad.app"
```

El mensaje de "dañada" es engañoso: el bundle está perfecto, lo que falta es el
sello de Apple. Sin notarización no hay forma de evitar ese paso, y notarizar
requiere la suscripción anual.

Esto vale para uso personal. Si algún día la app se reparte a otras personas,
cada una tendría que ejecutar ese comando a mano — que es justo el momento en
que la suscripción empieza a tener sentido, y no antes.

### Desinstalación

macOS no tiene desinstalador: arrastrar la app a la Papelera **no borra los
datos**, que quedan en `~/Library/Application Support`. La política del
producto es que nada sobreviva a la desinstalación, así que antes de borrar la
app (o después), se ejecuta:

```bash
bash tools/macos/uninstall.sh
```

Borra la app de `/Applications` y toda su carpeta de datos (base de datos,
ajustes, almacén cifrado, cachés y preferencias). Con `--sin-app` solo limpia
los datos y deja la app instalada.

### Secretos

Ninguno para firmar. El único secreto que necesita el repositorio es
`CORE_TOKEN`, un PAT con permiso de lectura sobre
`dzapataba/bdjstudiolicensecore`.

---

## Base de datos: `isar_community`

El proyecto usa `isar_community` (fork mantenido de Isar v3), no `isar`:

- `isar` 3.1.0 está abandonado. Su `libisar.so` se enlaza con alineación de
  4 KB, lo que rompe la app en dispositivos de 16 KB
  ([isar#1699](https://github.com/isar/isar/issues/1699), cerrado sin arreglo).
- `isar_community` ≥ 3.2.0-dev.1 enlaza con `-Wl,-z,max-page-size=16384` y
  declara el namespace de AGP 8, así que tampoco hace falta vendorizar el
  paquete.

Las tres dependencias (`isar_community`, `isar_community_flutter_libs`,
`isar_community_generator`) deben ir **siempre a la misma versión**.

La base se abre en el arranque (`openAppDatabase()` en la fase 2.5 de
`main.dart`), no de forma perezosa: así un fallo llega a la pantalla de inicio
con mensaje y botón de reintentar, en lugar de dejar la app girando sobre el
logo indefinidamente.

---

## Pendiente conocido

- **`POST_NOTIFICATIONS` no se solicita en runtime.** Está declarado en el
  manifest, pero en Android 13+ se deniega por defecto, así que la notificación
  del servicio en primer plano del modo performance queda suprimida. El audio
  funciona; lo que falta es el indicador visible. Requiere tocar el código
  nativo (`MainActivity.kt` / un plugin de permisos).
- `PerformanceAudioService.kt` crea el `NotificationChannel` sin comprobar
  API 26 y usa la sobrecarga de `startForeground` de 2 argumentos en lugar de
  declarar el tipo `mediaPlayback` explícitamente.
