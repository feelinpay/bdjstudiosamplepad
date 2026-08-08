import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/services/settings_service.dart';

final settingsServiceProvider = Provider<SettingsService>((ref) {
  throw UnimplementedError('Must be overridden at startup');
});

enum AppMode { basic, professional }

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService _service;

  SettingsNotifier(this._service)
    : super(
        SettingsState(
          themeMode: _service.themeMode,
          leftHanded: _service.leftHanded,
          highContrast: _service.highContrast,
          enablePadShortcuts: _service.enablePadShortcuts,
          fontScale: _service.fontScale,
          appMode: AppMode.values.byName(_service.appMode),
          snapToGrid: _service.snapToGrid,
          padSize: _service.padSize,
        ),
      );

  Future<void> setThemeMode(String value) async {
    await _service.setThemeMode(value);
    state = state.copyWith(themeMode: value);
  }

  Future<void> setLeftHanded(bool value) async {
    await _service.setLeftHanded(value);
    state = state.copyWith(leftHanded: value);
  }

  Future<void> setHighContrast(bool value) async {
    await _service.setHighContrast(value);
    state = state.copyWith(highContrast: value);
  }

  Future<void> setEnablePadShortcuts(bool value) async {
    await _service.setEnablePadShortcuts(value);
    state = state.copyWith(enablePadShortcuts: value);
  }

  Future<void> setFontScale(double value) async {
    await _service.setFontScale(value);
    state = state.copyWith(fontScale: value);
  }

  Future<void> setAppMode(AppMode value) async {
    await _service.setAppMode(value.name);
    state = state.copyWith(appMode: value);
  }

  Future<void> setPadSize(int value) async {
    await _service.setPadSize(value);
    state = state.copyWith(padSize: value);
  }

  Future<void> setSnapToGrid(bool value) async {
    await _service.setSnapToGrid(value);
    state = state.copyWith(snapToGrid: value);
  }
}

class SettingsState {
  final String themeMode;
  final bool leftHanded;
  final bool highContrast;
  final bool enablePadShortcuts;
  final double fontScale;
  final AppMode appMode;
  final bool snapToGrid;
  final int padSize;

  const SettingsState({
    required this.themeMode,
    required this.leftHanded,
    required this.highContrast,
    this.enablePadShortcuts = true,
    required this.fontScale,
    required this.appMode,
    required this.snapToGrid,
    this.padSize = 0,
  });

  SettingsState copyWith({
    String? themeMode,
    bool? leftHanded,
    bool? highContrast,
    bool? enablePadShortcuts,
    double? fontScale,
    AppMode? appMode,
    bool? snapToGrid,
    int? padSize,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      leftHanded: leftHanded ?? this.leftHanded,
      highContrast: highContrast ?? this.highContrast,
      enablePadShortcuts: enablePadShortcuts ?? this.enablePadShortcuts,
      fontScale: fontScale ?? this.fontScale,
      appMode: appMode ?? this.appMode,
      snapToGrid: snapToGrid ?? this.snapToGrid,
      padSize: padSize ?? this.padSize,
    );
  }

  bool get isDark => themeMode == 'dark';
  bool get isBasic => appMode == AppMode.basic;
  bool get isProfessional => appMode == AppMode.professional;
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    throw UnimplementedError('Must be overridden at startup');
  },
);
