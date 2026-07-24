class PairInvitation {
  const PairInvitation({
    required this.code,
    required this.expiresAt,
  });

  final String code;
  final DateTime expiresAt;

  Duration remainingAt(DateTime now) {
    final remaining = expiresAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);
}
