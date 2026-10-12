import '../../../activity/domain/entities/activity.dart';
import '../entities/shoe.dart';

/// How far a shoe has gone: its starting distance plus every activity
/// linked to it.
class ShoeUsage {
  const ShoeUsage(this.shoe, this.usedMeters);

  final Shoe shoe;
  final double usedMeters;

  /// Share of the lifespan used, 0–1 (capped).
  double get fraction =>
      (usedMeters / (shoe.lifespanKm * 1000)).clamp(0.0, 1.0);

  /// Whole percent used; may pass 100 when the shoe is past its lifespan.
  int get percent => (usedMeters / (shoe.lifespanKm * 10)).round();

  bool get wornOut => usedMeters >= shoe.lifespanKm * 1000;

  @override
  bool operator ==(Object other) =>
      other is ShoeUsage &&
      other.shoe == shoe &&
      other.usedMeters == usedMeters;

  @override
  int get hashCode => Object.hash(shoe, usedMeters);
}

/// Usage of each shoe, primary first, then active before retired, then by
/// name.
List<ShoeUsage> shoeUsage(
  Iterable<Shoe> shoes,
  Iterable<ActivitySummary> activities,
) {
  final linked = <String, double>{};
  for (final a in activities) {
    final id = a.shoeId;
    if (id != null) linked[id] = (linked[id] ?? 0) + a.distanceMeters;
  }
  final result = [
    for (final s in shoes)
      ShoeUsage(s, s.startDistanceMeters + (linked[s.id] ?? 0)),
  ];
  int rank(Shoe s) => s.primary ? 0 : (s.retired ? 2 : 1);
  result.sort((a, b) {
    final r = rank(a.shoe).compareTo(rank(b.shoe));
    return r != 0 ? r : a.shoe.name.compareTo(b.shoe.name);
  });
  return result;
}
