import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/licensing/licensing_port.dart';
import '../../../../core/licensing/license_manager.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/security/secure_storage_impl.dart';
import '../../../../core/security/device_fingerprint.dart';

final secureStorageProvider = Provider<SecureStorageImpl>((ref) {
  return SecureStorageImpl();
});

final deviceFingerprintProvider = Provider<DeviceFingerprint>((ref) {
  return DeviceFingerprint.withPersistentStorage(
    ref.read(secureStorageProvider),
  );
});

final licenseManagerProvider = Provider<LicenseManager>((ref) {
  return LicenseManager(
    secureStorage: ref.read(secureStorageProvider),
    fingerprint: ref.read(deviceFingerprintProvider),
  );
});

enum LicenseLoadingState { initial, loading, licensed, unlicensed, error, timeout }

class LicenseState {
  final LicenseLoadingState loadingState;
  final LicenseStatus status;
  final String? error;
  final String? licenseKey;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String? deviceId;
  final int remainingOfflineDays;

  const LicenseState({
    this.loadingState = LicenseLoadingState.initial,
    this.status = LicenseStatus.none,
    this.error,
    this.licenseKey,
    this.activatedAt,
    this.expiresAt,
    this.deviceId,
    this.remainingOfflineDays = 30,
  });

  LicenseState copyWith({
    LicenseLoadingState? loadingState,
    LicenseStatus? status,
    String? error,
    String? licenseKey,
    DateTime? activatedAt,
    DateTime? expiresAt,
    String? deviceId,
    int? remainingOfflineDays,
  }) {
    return LicenseState(
      loadingState: loadingState ?? this.loadingState,
      status: status ?? this.status,
      error: error,
      licenseKey: licenseKey ?? this.licenseKey,
      activatedAt: activatedAt ?? this.activatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      deviceId: deviceId ?? this.deviceId,
      remainingOfflineDays: remainingOfflineDays ?? this.remainingOfflineDays,
    );
  }
}

class LicenseNotifier extends StateNotifier<LicenseState> {
  final LicenseManager _manager;

  /// Presupuesto máximo para validar la licencia al arrancar.
  ///
  /// La validación es offline (criptográfica), pero lee del almacenamiento
  /// seguro (Keystore de Android) y genera la huella HWID. En gama baja o con
  /// Keystore degradado esas operaciones pueden tardar demasiado; sin límite
  /// la app se quedaría en el spinner eterno. Con él, cae a la pantalla de
  /// activación con mensaje y el usuario puede reintentar.
  static const _checkBudget = Duration(seconds: 12);
  int _checkGeneration = 0;

  LicenseNotifier(this._manager, {Future<Result<LicenseInfo>>? preloaded})
      : super(const LicenseState()) {
    _checkLicense(preloaded: preloaded);
  }

  void _applyValidationResult(Result<LicenseInfo> result) {
    result.fold(
      (failure) {
        state = state.copyWith(
          loadingState: LicenseLoadingState.unlicensed,
          status: _manager.currentStatus,
          error: _manager.currentStatus == LicenseStatus.none
              ? null
              : failure.message,
        );
      },
      (info) {
        state = state.copyWith(
          loadingState: LicenseLoadingState.licensed,
          status: info.status,
          licenseKey: info.licenseKey,
          activatedAt: info.activatedAt,
          expiresAt: info.expiresAt,
          deviceId: info.deviceId,
          remainingOfflineDays: info.remainingOfflineDays,
        );
      },
    );
  }

  Future<void> _checkLicense({Future<Result<LicenseInfo>>? preloaded}) async {
    final generation = ++_checkGeneration;
    state = state.copyWith(loadingState: LicenseLoadingState.loading);

    final future = preloaded ?? _manager.validateLicense();
    final Result<LicenseInfo> result;
    try {
      result = await future.timeout(_checkBudget);
    } on TimeoutException {
      // Si la verificación completa tarde (ej. hardware lento o WMI),
      // y la pantalla sigue en timeout en la MISMA generación, resolvemos automáticamente.
      future.then((lateResult) {
        if (generation == _checkGeneration &&
            state.loadingState == LicenseLoadingState.timeout) {
          _applyValidationResult(lateResult);
        }
      }).catchError((_) {});

      if (generation == _checkGeneration) {
        state = state.copyWith(
          loadingState: LicenseLoadingState.timeout,
          status: _manager.currentStatus,
          error: 'La verificación de licencia tardó demasiado. '
              'Revisa el dispositivo e inténtalo de nuevo.',
        );
      }
      return;
    } catch (e) {
      if (generation == _checkGeneration) {
        state = state.copyWith(
          loadingState: LicenseLoadingState.error,
          status: _manager.currentStatus,
          error: 'Error al verificar la licencia. '
              'Revisa el dispositivo e inténtalo de nuevo.',
        );
      }
      return;
    }

    if (generation == _checkGeneration) {
      _applyValidationResult(result);
    }
  }

  /// Reintenta la comprobación completa de la licencia limpiando cachés previas.
  Future<void> retry() async {
    _manager.clearFingerprintCache();
    await _checkLicense();
  }

  Future<void> activate(String licenseKey) async {
    state = state.copyWith(
      loadingState: LicenseLoadingState.loading,
      error: null,
    );

    var result = await _manager.activateLicense(licenseKey);
    result.fold(
      (failure) {
        state = state.copyWith(
          loadingState: LicenseLoadingState.error,
          error: failure.message,
        );
      },
      (info) {
        state = state.copyWith(
          loadingState: LicenseLoadingState.licensed,
          status: info.status,
          licenseKey: info.licenseKey,
          activatedAt: info.activatedAt,
          expiresAt: info.expiresAt,
          deviceId: info.deviceId,
          remainingOfflineDays: info.remainingOfflineDays,
        );
      },
    );
  }

  Future<String?> updateLicense(String licenseKey) async {
    final result = await _manager.activateLicense(licenseKey);
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return failure.message;
      },
      (info) {
        state = state.copyWith(
          loadingState: LicenseLoadingState.licensed,
          status: info.status,
          error: null,
          licenseKey: info.licenseKey,
          activatedAt: info.activatedAt,
          expiresAt: info.expiresAt,
          deviceId: info.deviceId,
          remainingOfflineDays: info.remainingOfflineDays,
        );
        return null;
      },
    );
  }

  Future<void> sync() async {
    _manager.clearFingerprintCache();
    try {
      final result = await _manager.syncLicense().timeout(_checkBudget);
      result.fold(
        (failure) {
          state = state.copyWith(
            loadingState: LicenseLoadingState.unlicensed,
            error: failure.message,
          );
        },
        (info) {
          state = state.copyWith(
            loadingState: LicenseLoadingState.licensed,
            status: info.status,
            remainingOfflineDays: info.remainingOfflineDays,
          );
        },
      );
    } catch (_) {
      // Timeout o error transitorio en sincronización de fondo: no degradamos estado
    }
  }

  Future<void> deactivate() async {
    await _manager.deactivateLicense();
    state = const LicenseState(
      loadingState: LicenseLoadingState.unlicensed,
      status: LicenseStatus.none,
    );
  }
}

final licenseProvider = StateNotifierProvider<LicenseNotifier, LicenseState>((
  ref,
) {
  return LicenseNotifier(ref.read(licenseManagerProvider));
});
