import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/add_to_wallet_button.dart';
import '../widgets/card_tile.dart';
import '../widgets/status_row.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletControllerProvider);
    final entitlement = ref.watch(entitlementProvider);
    final supported = ref.watch(walletSupportProvider);
    final controller = ref.read(walletControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StatusRow(
              label: 'Platform',
              value: Platform.isIOS ? 'iOS' : 'Android (read-only)',
              ok: Platform.isIOS,
            ),
            StatusRow(
              label: 'PassKit supported',
              value: supported.when(
                data: (v) => v ? 'Yes' : 'No',
                loading: () => '...',
                error: (_, _) => 'Error',
              ),
              ok: supported.maybeWhen(data: (v) => v, orElse: () => false),
            ),
            StatusRow(
              label: 'Provisioning entitlement',
              value: entitlement.when(
                data: (v) => v ? 'Granted' : 'Pending Apple review',
                loading: () => '...',
                error: (_, _) => 'Error',
              ),
              ok: entitlement.maybeWhen(data: (v) => v, orElse: () => false),
            ),
            const SizedBox(height: 16),
            _AddCardCard(
              isProvisioning: wallet.isProvisioning,
              onAdd: () => controller.addCard(
                cardholderName: 'HAU TRAN',
                primaryAccountSuffix: '4242',
              ),
            ),
            if (wallet.lastError != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(
                message: wallet.lastError!,
                onDismiss: controller.dismissError,
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Provisioned cards',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (wallet.cards.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No cards yet.')),
              )
            else
              for (final card in wallet.cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CardTile(card: card),
                ),
          ],
        ),
      ),
    );
  }
}

class _AddCardCard extends StatelessWidget {
  const _AddCardCard({required this.isProvisioning, required this.onAdd});

  final bool isProvisioning;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a payment card',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              Platform.isIOS
                  ? 'Launches the native PKAddPaymentPassViewController flow.'
                  : 'iOS only. This button is disabled on Android.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                AddToWalletButton(
                  enabled: Platform.isIOS && !isProvisioning,
                  onPressed: onAdd,
                ),
                const SizedBox(width: 12),
                if (isProvisioning)
                  const CupertinoActivityIndicator(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      content: Text(message),
      actions: [
        TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
      ],
    );
  }
}
