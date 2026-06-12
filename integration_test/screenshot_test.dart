import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_apple_wallet_passkit/app/app.dart';
import 'package:flutter_apple_wallet_passkit/providers/providers.dart';
import 'package:flutter_apple_wallet_passkit/services/hid_approve_service.dart';

/// Deterministic stand-in for the native HID Approve channel so the
/// Transactions screen renders a real-looking OTP in the simulator
/// (the native MethodChannel has no impl under flutter drive).
class _StubHidApproveService extends HidApproveService {
  _StubHidApproveService();

  @override
  Future<String> generateOtp({required String requestId}) async {
    return '482915';
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shoot(WidgetTester tester, String name) async {
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  testWidgets('capture wallet passkit flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hidApproveServiceProvider.overrideWithValue(_StubHidApproveService()),
        ],
        child: const WalletPocApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 01 - Wallet tab: status rows + seeded provisioned card.
    await shoot(tester, '01-wallet');

    // 02 - Transactions tab: fire a signed request to populate the OTP card.
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send signed transaction'));
    await tester.pumpAndSettle();
    await shoot(tester, '02-transactions');

    // 03 - Settings tab: cardholder name + biometric toggle.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await shoot(tester, '03-settings');
  });
}
