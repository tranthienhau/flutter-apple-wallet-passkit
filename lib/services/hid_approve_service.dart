import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

/// Dart wrapper around the HID Approve MethodChannel.
///
/// The real HID Approve SDK signs a transaction with a server-issued
/// challenge and returns a one-time password. For this POC, the native
/// side returns a deterministic 6-digit pseudo-OTP after a short delay.
class HidApproveService {
  HidApproveService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('poc.hid/approve');

  final MethodChannel _channel;

  /// Generate an OTP bound to a specific request id (typically a server
  /// challenge nonce). Throws [HidApproveException] on failure.
  Future<String> generateOtp({required String requestId}) async {
    try {
      final otp = await _channel.invokeMethod<String>(
        'generateOtp',
        {'requestId': requestId},
      );
      if (otp == null || otp.isEmpty) {
        throw const HidApproveException('Empty OTP from native HID channel');
      }
      return otp;
    } on PlatformException catch (e) {
      throw HidApproveException(e.message ?? e.code);
    }
  }
}

class HidApproveException implements Exception {
  const HidApproveException(this.message);
  final String message;

  @override
  String toString() => 'HidApproveException: $message';
}

/// Dio interceptor that attaches a fresh HID Approve OTP to every outbound
/// request as the `X-HID-OTP` header. The header value is the OTP that
/// signed the request body hash (server side replays the hash check).
class HidOtpInterceptor extends Interceptor {
  HidOtpInterceptor(this._service);

  final HidApproveService _service;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // The request id is a stable correlation token. In production, the
      // server would issue it as a challenge. Here we derive one from the
      // path + timestamp so each call is unique.
      final requestId =
          '${options.method}:${options.path}:${DateTime.now().millisecondsSinceEpoch}';
      final otp = await _service.generateOtp(requestId: requestId);
      options.headers['X-HID-OTP'] = otp;
      options.headers['X-HID-Request-Id'] = requestId;
      handler.next(options);
    } on HidApproveException catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          message: e.message,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
}
