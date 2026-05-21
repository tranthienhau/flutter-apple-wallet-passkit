/// Lightweight model representing a provisioned card in the wallet.
class ProvisionedCard {
  const ProvisionedCard({
    required this.id,
    required this.cardholderName,
    required this.last4,
    required this.network,
    required this.status,
    required this.provisionedAt,
  });

  final String id;
  final String cardholderName;
  final String last4;
  final String network; // "Visa", "Mastercard", etc.
  final CardStatus status;
  final DateTime provisionedAt;

  ProvisionedCard copyWith({CardStatus? status}) {
    return ProvisionedCard(
      id: id,
      cardholderName: cardholderName,
      last4: last4,
      network: network,
      status: status ?? this.status,
      provisionedAt: provisionedAt,
    );
  }
}

enum CardStatus { idle, provisioning, active, failed }
