/// One entry in the credit ledger (credit history screen).
class CreditTransaction {
  final int id;
  final int amount; // + grant, - spend
  final int balanceAfter;
  final String kind; // "initial" | "text" | "image" | "voice"
  final String? description;
  final DateTime createdAt;

  const CreditTransaction({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.kind,
    this.description,
    required this.createdAt,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> j) => CreditTransaction(
        id: j['id'] as int,
        amount: j['amount'] as int,
        balanceAfter: j['balance_after'] as int,
        kind: j['kind'] as String,
        description: j['description'] as String?,
        // Backend sends naive UTC timestamps; parse and treat as UTC.
        createdAt:
            DateTime.parse(j['created_at'] as String).toUtc().toLocal(),
      );

  bool get isGrant => amount >= 0;
}
