import 'package:flutter/material.dart';

import '../models/provisioned_card.dart';

class CardTile extends StatelessWidget {
  const CardTile({super.key, required this.card});

  final ProvisionedCard card;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.credit_card),
        title: Text('${card.network} ending ${card.last4}'),
        subtitle: Text('${card.cardholderName} · ${_label(card.status)}'),
        trailing: Icon(
          card.status == CardStatus.active
              ? Icons.check_circle
              : Icons.hourglass_top,
          color: card.status == CardStatus.active ? Colors.green : null,
        ),
      ),
    );
  }

  String _label(CardStatus s) {
    switch (s) {
      case CardStatus.idle:
        return 'Idle';
      case CardStatus.provisioning:
        return 'Provisioning';
      case CardStatus.active:
        return 'Active';
      case CardStatus.failed:
        return 'Failed';
    }
  }
}
