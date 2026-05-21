import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Thin Dart wrapper around the iOS WalletProvisioning MethodChannel.
///
/// On iOS, this triggers the real `PKAddPaymentPassViewController` flow
/// (see `ios/Runner/WalletProvisioningChannel.swift`). On Android, every
/// method short-circuits because the platform has no equivalent feature.
class WalletService {
  WalletService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('poc.wallet/provisioning');

  final MethodChannel _channel;

  /// Returns true if the device supports adding payment passes.
  /// Hard-coded false on non-iOS for this POC.
  Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Returns true if the app has been granted the
  /// `com.apple.developer.payment-pass-provisioning` entitlement by Apple.
  Future<bool> hasEntitlement() async {
    if (!Platform.isIOS) return false;
    try {
      // MOCK: the native channel returns a hard-coded value for the POC.
      final granted = await _channel.invokeMethod<bool>('hasEntitlement');
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Kicks off the native PKAddPaymentPassViewController flow.
  /// Returns an opaque pass identifier on success.
  Future<WalletProvisionResult> addPaymentPass({
    required String cardholderName,
    required String primaryAccountSuffix,
  }) async {
    if (!Platform.isIOS) {
      return const WalletProvisionResult.unsupported();
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'addPaymentPass',
        {
          'cardholderName': cardholderName,
          'primaryAccountSuffix': primaryAccountSuffix,
        },
      );
      if (raw == null) {
        return const WalletProvisionResult.failure('Empty native response');
      }
      final ok = raw['ok'] as bool? ?? false;
      if (!ok) {
        return WalletProvisionResult.failure(
          raw['error'] as String? ?? 'Unknown native error',
        );
      }
      return WalletProvisionResult.success(
        passId: raw['passId'] as String? ?? 'unknown',
      );
    } on PlatformException catch (e) {
      return WalletProvisionResult.failure(e.message ?? e.code);
    }
  }
}

/// Sealed-style result for the wallet provisioning flow.
class WalletProvisionResult {
  const WalletProvisionResult._({
    required this.kind,
    this.passId,
    this.error,
  });

  const WalletProvisionResult.success({required String passId})
      : this._(kind: WalletResultKind.success, passId: passId);

  const WalletProvisionResult.failure(String error)
      : this._(kind: WalletResultKind.failure, error: error);

  const WalletProvisionResult.unsupported()
      : this._(kind: WalletResultKind.unsupported);

  final WalletResultKind kind;
  final String? passId;
  final String? error;

  bool get isSuccess => kind == WalletResultKind.success;
}

enum WalletResultKind { success, failure, unsupported }
