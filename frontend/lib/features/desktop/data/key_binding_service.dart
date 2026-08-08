import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persiste los atajos de teclado que el USUARIO asigna a cada pad
/// (no hay atajos por defecto). Mapea keyId -> padId.
class KeyBindingService {
  final SharedPreferences _prefs;
  static const _key = 'key_bindings';

  KeyBindingService(this._prefs);

  Map<String, String> getAll() {
    var raw = _prefs.getString(_key);
    if (raw == null) return {};
    var m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> save(Map<String, String> map) =>
      _prefs.setString(_key, jsonEncode(map));

  /// Etiqueta legible de una tecla a partir de su keyId (ej. 'A', '1', 'ESC').
  String labelFor(String keyId) {
    var id = int.tryParse(keyId);
    if (id == null) return '?';
    var k = LogicalKeyboardKey(id);
    if (k == LogicalKeyboardKey.escape) return 'ESC';
    if (k == LogicalKeyboardKey.space) return 'ESPACIO';
    if (k.keyLabel.isNotEmpty) return k.keyLabel.toUpperCase();
    return k.debugName?.toUpperCase() ?? '?';
  }
}
