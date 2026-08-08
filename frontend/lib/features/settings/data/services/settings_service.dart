import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyAudioOutputDeviceId = 'audio_output_device_id';
  static const _keySoundCacheCapacity = 'sound_cache_capacity';
  late SharedPreferences _prefs;

  SettingsService();

  /// Inicializa con una instancia ya resuelta (evita doble fetch).
  SettingsService.withPrefs(SharedPreferences prefs) : _prefs = prefs;

  static const _keyThemeMode = 'theme_mode';
  static const _keyLeftHanded = 'left_handed';
  static const _keyHighContrast = 'high_contrast';
  static const _keyEnablePadShortcuts = 'enable_pad_shortcuts';
  static const _keyFontScale = 'font_scale';

  bool get enablePadShortcuts => _prefs.getBool(_keyEnablePadShortcuts) ?? true;
  Future<void> setEnablePadShortcuts(bool value) =>
      _prefs.setBool(_keyEnablePadShortcuts, value);
  static const _keyAppMode = 'app_mode';
  static const _keySnapToGrid = 'snap_to_grid';
  static const _keyPadSize = 'pad_size'; // 0=auto 1=grande 2=mediano 3=pequeno 4=ultra denso 5=extra pequeno

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'dark';
  Future<void> setThemeMode(String value) =>
      _prefs.setString(_keyThemeMode, value);

  bool get leftHanded => _prefs.getBool(_keyLeftHanded) ?? false;
  Future<void> setLeftHanded(bool value) =>
      _prefs.setBool(_keyLeftHanded, value);

  bool get highContrast => _prefs.getBool(_keyHighContrast) ?? false;
  Future<void> setHighContrast(bool value) =>
      _prefs.setBool(_keyHighContrast, value);

  double get fontScale => _prefs.getDouble(_keyFontScale) ?? 1.0;
  Future<void> setFontScale(double value) =>
      _prefs.setDouble(_keyFontScale, value);

  int? get audioOutputDeviceId => _prefs.getInt(_keyAudioOutputDeviceId);
  Future<void> setAudioOutputDeviceId(int? value) async {
    if (value == null) {
      await _prefs.remove(_keyAudioOutputDeviceId);
    } else {
      await _prefs.setInt(_keyAudioOutputDeviceId, value);
    }
  }

  int get soundCacheCapacity => _prefs.getInt(_keySoundCacheCapacity) ?? 100;
  Future<void> setSoundCacheCapacity(int value) =>
      _prefs.setInt(_keySoundCacheCapacity, value);

  String get appMode => _prefs.getString(_keyAppMode) ?? 'professional';
  Future<void> setAppMode(String value) => _prefs.setString(_keyAppMode, value);

  int get padSize => _prefs.getInt(_keyPadSize) ?? 0;
  Future<void> setPadSize(int value) => _prefs.setInt(_keyPadSize, value);

  bool get snapToGrid => _prefs.getBool(_keySnapToGrid) ?? false;
  Future<void> setSnapToGrid(bool value) =>
      _prefs.setBool(_keySnapToGrid, value);

  static const _keyLastWorkspaceId = 'last_workspace_id';
  static const _keyLastPageIndex = 'last_page_index';

  int? get lastWorkspaceId => _prefs.getInt(_keyLastWorkspaceId);
  Future<void> setLastWorkspaceId(int? value) async {
    if (value == null) {
      await _prefs.remove(_keyLastWorkspaceId);
    } else {
      await _prefs.setInt(_keyLastWorkspaceId, value);
    }
  }

  int get lastPageIndex => _prefs.getInt(_keyLastPageIndex) ?? 0;
  Future<void> setLastPageIndex(int value) =>
      _prefs.setInt(_keyLastPageIndex, value);

  static const _keyWorkspaceOrder = 'workspace_order_ids';

  List<int> get workspaceOrder {
    var raw = _prefs.getStringList(_keyWorkspaceOrder);
    if (raw == null) return [];
    return raw
        .map((s) => int.tryParse(s) ?? -1)
        .where((id) => id != -1)
        .toList();
  }

  Future<void> setWorkspaceOrder(List<int> order) {
    return _prefs.setStringList(
      _keyWorkspaceOrder,
      order.map((i) => i.toString()).toList(),
    );
  }
}
