import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around flutter_secure_storage with sensible defaults.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _kCardholderName = 'wallet.cardholderName';
  static const _kBiometricEnabled = 'wallet.biometricEnabled';

  Future<String?> readCardholderName() => _storage.read(key: _kCardholderName);

  Future<void> writeCardholderName(String name) =>
      _storage.write(key: _kCardholderName, value: name);

  Future<bool> readBiometricEnabled() async {
    final raw = await _storage.read(key: _kBiometricEnabled);
    return raw == 'true';
  }

  Future<void> writeBiometricEnabled(bool enabled) =>
      _storage.write(key: _kBiometricEnabled, value: enabled.toString());
}
