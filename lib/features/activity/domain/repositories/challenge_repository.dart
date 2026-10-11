import '../entities/monthly_challenge.dart';

abstract interface class ChallengeRepository {
  /// This month's challenge: from the server when reachable, else the last
  /// one cached, else null.
  Future<MonthlyChallenge?> current();
}
