import '../../../activity/domain/services/best_efforts.dart';

/// What this device holds from use while signed out (Stitch 07.1, 08 guest):
/// the data a sign-in can merge into the account or keep on the device.
class GuestDataSummary {
  const GuestDataSummary({
    this.activityCount = 0,
    this.distanceMeters = 0,
    this.movingTime = Duration.zero,
    this.bests = const PersonalBests(),
    this.shoeCount = 0,
    this.workoutCount = 0,
    this.hasProfile = false,
  });

  static const empty = GuestDataSummary();

  final int activityCount;
  final double distanceMeters;
  final Duration movingTime;

  /// From the runs' tracks.
  final PersonalBests bests;
  final int shoeCount;
  final int workoutCount;

  /// Body data typed in while signed out.
  final bool hasProfile;

  /// Nothing to merge: sign-in skips the 07.1 question.
  bool get isEmpty =>
      activityCount == 0 && shoeCount == 0 && workoutCount == 0 && !hasProfile;

  @override
  bool operator ==(Object other) =>
      other is GuestDataSummary &&
      other.activityCount == activityCount &&
      other.distanceMeters == distanceMeters &&
      other.movingTime == movingTime &&
      other.bests == bests &&
      other.shoeCount == shoeCount &&
      other.workoutCount == workoutCount &&
      other.hasProfile == hasProfile;

  @override
  int get hashCode => Object.hash(
    activityCount,
    distanceMeters,
    movingTime,
    bests,
    shoeCount,
    workoutCount,
    hasProfile,
  );
}
