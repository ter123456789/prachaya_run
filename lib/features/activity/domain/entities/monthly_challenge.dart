/// The month's distance challenge (defined by the server).
class MonthlyChallenge {
  const MonthlyChallenge({
    required this.id,
    required this.title,
    required this.badge,
    required this.goalMeters,
    required this.startsAt,
    required this.endsAt,
  });

  /// e.g. `2026-10`.
  final String id;
  final String title;
  final String badge;
  final double goalMeters;
  final DateTime startsAt;

  /// Exclusive: the start of the next month.
  final DateTime endsAt;

  bool contains(DateTime t) => !t.isBefore(startsAt) && t.isBefore(endsAt);
}
