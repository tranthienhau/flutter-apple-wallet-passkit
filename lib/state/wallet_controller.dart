import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/provisioned_card.dart';
import '../services/wallet_service.dart';

/// Immutable wallet UI state.
class WalletState {
  const WalletState({
    this.cards = const [],
    this.isProvisioning = false,
    this.lastError,
  });

  final List<ProvisionedCard> cards;
  final bool isProvisioning;
  final String? lastError;

  WalletState copyWith({
    List<ProvisionedCard>? cards,
    bool? isProvisioning,
    String? lastError,
    bool clearError = false,
  }) {
    return WalletState(
      cards: cards ?? this.cards,
      isProvisioning: isProvisioning ?? this.isProvisioning,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

/// Drives the wallet provisioning state machine:
/// idle -> provisioning -> (success: card added) | (failure: error set)
class WalletController extends StateNotifier<WalletState> {
  WalletController(this._service)
      : super(
          WalletState(
            cards: [
              // MOCK: seed one already-provisioned card for the demo UI.
              ProvisionedCard(
                id: 'seed-1',
                cardholderName: 'HAU TRAN',
                last4: '4242',
                network: 'Visa',
                status: CardStatus.active,
                provisionedAt: DateTime.now().subtract(const Duration(days: 3)),
              ),
            ],
          ),
        );

  final WalletService _service;

  Future<void> addCard({
    required String cardholderName,
    required String primaryAccountSuffix,
  }) async {
    if (state.isProvisioning) return;
    state = state.copyWith(isProvisioning: true, clearError: true);

    final result = await _service.addPaymentPass(
      cardholderName: cardholderName,
      primaryAccountSuffix: primaryAccountSuffix,
    );

    if (result.isSuccess) {
      final card = ProvisionedCard(
        id: result.passId ?? DateTime.now().toIso8601String(),
        cardholderName: cardholderName,
        last4: primaryAccountSuffix,
        network: _guessNetwork(primaryAccountSuffix),
        status: CardStatus.active,
        provisionedAt: DateTime.now(),
      );
      state = state.copyWith(
        cards: [...state.cards, card],
        isProvisioning: false,
      );
    } else {
      state = state.copyWith(
        isProvisioning: false,
        lastError: result.error ??
            (result.kind == WalletResultKind.unsupported
                ? 'Apple Wallet provisioning is iOS only.'
                : 'Provisioning failed.'),
      );
    }
  }

  void dismissError() {
    state = state.copyWith(clearError: true);
  }

  String _guessNetwork(String suffix) {
    // MOCK: tiny heuristic for the demo only.
    if (suffix.startsWith('4')) return 'Visa';
    if (suffix.startsWith('5')) return 'Mastercard';
    return 'Card';
  }
}
