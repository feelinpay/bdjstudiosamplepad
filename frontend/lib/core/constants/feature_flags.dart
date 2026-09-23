/// Interruptores de funciones que ya estan implementadas y probadas pero que
/// todavia no deben verse en la interfaz.
///
/// Se declaran con `bool.fromEnvironment` y no con un `true`/`false` literal a
/// proposito: asi el analizador no marca como codigo muerto las ramas ocultas
/// (el valor no se conoce en tiempo de analisis), el codigo se sigue
/// compilando y verificando con `flutter analyze` y `flutter test`, y el
/// arbol de widgets oculto se elimina igualmente del binario de release.
///
/// Para activar una funcion sin tocar el codigo:
///
/// ```bash
/// flutter run --dart-define=BDJ_PROJECT_BACKUP=true
/// flutter build apk --release --dart-define=BDJ_PROJECT_BACKUP=true
/// ```
///
/// Cuando la funcion se anuncie oficialmente, se cambia el `defaultValue` a
/// `true` y se retira el flag en la version siguiente.
class FeatureFlags {
  const FeatureFlags._();

  /// Respaldo e importacion del PROYECTO COMPLETO (`.sppproject`).
  ///
  /// Cubre todos los workspaces con sus paginas, carpetas, pads y ediciones,
  /// los audios, las macros y los mapeos MIDI. Es la operacion pensada para
  /// mudarse de dispositivo, distinta de exportar o importar un solo
  /// workspace, que si esta visible.
  ///
  /// Implementado en `ProjectExporter` / `ProjectImporter`. Oculto en Ajustes
  /// hasta la version que lo anuncie.
  static const bool projectBackupVisible = bool.fromEnvironment(
    'BDJ_PROJECT_BACKUP',
    defaultValue: false,
  );
}
