/// Estado explícito del motor de audio para que la UI reaccione
/// sin depender de un único bool.
enum AudioEngineState {
  uninitialized,
  initializing,
  ready,
  changingDevice,
  noDevice,
  error,
  disposed,
}
