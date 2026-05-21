import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hid_approve_service.dart';
import '../services/secure_storage_service.dart';
import '../services/wallet_service.dart';
import '../state/wallet_controller.dart';

final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService();
});

final hidApproveServiceProvider = Provider<HidApproveService>((ref) {
  return HidApproveService();
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Dio configured against a mocked banking backend with the HID OTP
/// interceptor wired in. The base URL points at a non-routable host on
/// purpose; in this POC we never actually hit the network.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://mocked-bank.example.invalid',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );
  dio.interceptors.add(HidOtpInterceptor(ref.read(hidApproveServiceProvider)));
  return dio;
});

final walletControllerProvider =
    StateNotifierProvider<WalletController, WalletState>((ref) {
  return WalletController(ref.read(walletServiceProvider));
});

final entitlementProvider = FutureProvider<bool>((ref) async {
  return ref.read(walletServiceProvider).hasEntitlement();
});

final walletSupportProvider = FutureProvider<bool>((ref) async {
  return ref.read(walletServiceProvider).isSupported();
});
