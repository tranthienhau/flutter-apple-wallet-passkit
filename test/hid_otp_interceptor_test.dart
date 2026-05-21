import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_apple_wallet_passkit/services/hid_approve_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockHidService extends Mock implements HidApproveService {}

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? captured;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured = options;
    return ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('HidOtpInterceptor', () {
    late _MockHidService service;
    late Dio dio;
    late _CaptureAdapter adapter;

    setUp(() {
      service = _MockHidService();
      dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
      adapter = _CaptureAdapter();
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(HidOtpInterceptor(service));
    });

    test('attaches X-HID-OTP header from the service', () async {
      when(() => service.generateOtp(requestId: any(named: 'requestId')))
          .thenAnswer((_) async => '123456');

      final res = await dio.get('/ping');

      expect(res.statusCode, 200);
      expect(adapter.captured?.headers['X-HID-OTP'], '123456');
      expect(adapter.captured?.headers['X-HID-Request-Id'], isNotNull);
    });

    test('rejects the request if HID throws', () async {
      when(() => service.generateOtp(requestId: any(named: 'requestId')))
          .thenThrow(const HidApproveException('chip locked'));

      await expectLater(
        () => dio.get('/ping'),
        throwsA(
          isA<DioException>().having(
            (e) => e.message,
            'message',
            contains('chip locked'),
          ),
        ),
      );
      expect(adapter.captured, isNull);
    });
  });
}
