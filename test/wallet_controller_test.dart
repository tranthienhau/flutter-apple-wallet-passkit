import 'package:flutter_apple_wallet_passkit/models/provisioned_card.dart';
import 'package:flutter_apple_wallet_passkit/services/wallet_service.dart';
import 'package:flutter_apple_wallet_passkit/state/wallet_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletService extends Mock implements WalletService {}

void main() {
  group('WalletController state machine', () {
    late _MockWalletService service;

    setUp(() {
      service = _MockWalletService();
    });

    test('seeds with one mock card', () {
      final c = WalletController(service);
      expect(c.state.cards, hasLength(1));
      expect(c.state.cards.first.status, CardStatus.active);
    });

    test('success path appends a card', () async {
      when(() => service.addPaymentPass(
            cardholderName: any(named: 'cardholderName'),
            primaryAccountSuffix: any(named: 'primaryAccountSuffix'),
          )).thenAnswer(
        (_) async => const WalletProvisionResult.success(passId: 'pass-xyz'),
      );

      final c = WalletController(service);
      await c.addCard(cardholderName: 'JANE DOE', primaryAccountSuffix: '5555');

      expect(c.state.isProvisioning, false);
      expect(c.state.cards, hasLength(2));
      expect(c.state.cards.last.last4, '5555');
      expect(c.state.cards.last.network, 'Mastercard');
      expect(c.state.lastError, isNull);
    });

    test('failure path records the error and does not add a card', () async {
      when(() => service.addPaymentPass(
            cardholderName: any(named: 'cardholderName'),
            primaryAccountSuffix: any(named: 'primaryAccountSuffix'),
          )).thenAnswer(
        (_) async => const WalletProvisionResult.failure('chip locked'),
      );

      final c = WalletController(service);
      final before = c.state.cards.length;
      await c.addCard(cardholderName: 'JANE DOE', primaryAccountSuffix: '4111');

      expect(c.state.cards.length, before);
      expect(c.state.lastError, 'chip locked');
    });

    test('unsupported platform yields friendly message', () async {
      when(() => service.addPaymentPass(
            cardholderName: any(named: 'cardholderName'),
            primaryAccountSuffix: any(named: 'primaryAccountSuffix'),
          )).thenAnswer((_) async => const WalletProvisionResult.unsupported());

      final c = WalletController(service);
      await c.addCard(cardholderName: 'JANE DOE', primaryAccountSuffix: '4111');

      expect(c.state.lastError, contains('iOS only'));
    });

    test('dismissError clears the error', () async {
      when(() => service.addPaymentPass(
            cardholderName: any(named: 'cardholderName'),
            primaryAccountSuffix: any(named: 'primaryAccountSuffix'),
          )).thenAnswer(
        (_) async => const WalletProvisionResult.failure('boom'),
      );
      final c = WalletController(service);
      await c.addCard(cardholderName: 'JANE DOE', primaryAccountSuffix: '4111');
      expect(c.state.lastError, 'boom');
      c.dismissError();
      expect(c.state.lastError, isNull);
    });
  });
}
