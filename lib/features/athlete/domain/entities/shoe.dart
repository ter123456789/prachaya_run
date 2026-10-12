/// A pair of shoes (or other gear) whose mileage is tracked.
class Shoe {
  const Shoe({
    required this.id,
    required this.name,
    this.model,
    this.lifespanKm = kDefaultShoeLifespanKm,
    this.startDistanceMeters = 0,
    this.primary = false,
    this.retired = false,
  });

  final String id;
  final String name;

  /// Free text under the name, e.g. "Carbon Road Racer".
  final String? model;

  /// When the shoe is due for replacement.
  final int lifespanKm;

  /// Distance run in it before it was added to the app.
  final double startDistanceMeters;

  /// New runs and hikes are linked to the primary shoe.
  final bool primary;
  final bool retired;

  Shoe copyWith({
    String? name,
    String? Function()? model,
    int? lifespanKm,
    double? startDistanceMeters,
    bool? primary,
    bool? retired,
  }) => Shoe(
    id: id,
    name: name ?? this.name,
    model: model == null ? this.model : model(),
    lifespanKm: lifespanKm ?? this.lifespanKm,
    startDistanceMeters: startDistanceMeters ?? this.startDistanceMeters,
    primary: primary ?? this.primary,
    retired: retired ?? this.retired,
  );

  @override
  bool operator ==(Object other) =>
      other is Shoe &&
      other.id == id &&
      other.name == name &&
      other.model == model &&
      other.lifespanKm == lifespanKm &&
      other.startDistanceMeters == startDistanceMeters &&
      other.primary == primary &&
      other.retired == retired;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    model,
    lifespanKm,
    startDistanceMeters,
    primary,
    retired,
  );
}

/// A common replacement point for running shoes.
const int kDefaultShoeLifespanKm = 600;

class ShoeValidationException implements Exception {
  const ShoeValidationException();
}

/// Same limits as the server (docs/api.md, Shoes).
bool isValidShoe(Shoe s) =>
    s.name.trim().isNotEmpty &&
    s.name.trim().length <= 60 &&
    (s.model == null || s.model!.length <= 60) &&
    s.lifespanKm >= 50 &&
    s.lifespanKm <= 5000 &&
    s.startDistanceMeters >= 0;
