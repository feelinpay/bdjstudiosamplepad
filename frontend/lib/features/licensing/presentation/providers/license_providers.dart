import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/licensing/licensing_port.dart';
import '../../../../core/licensing/license_manager.dart';
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

enum LicenseLoadingState { initial, loading, licensed, unlicensed, error }

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

  LicenseNotifier(this._manager) : super(const LicenseState()) {
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    state = state.copyWith(loadingState: LicenseLoadingState.loading);

    var result = await _manager.validateLicense();
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
    var result = await _manager.syncLicense();
    result.fold((failure) {}, (info) {
      state = state.copyWith(
        status: info.status,
        remainingOfflineDays: info.remainingOfflineDays,
      );
    });
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
