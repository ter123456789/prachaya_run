import '../entities/shoe.dart';

abstract interface class ShoeRepository {
  /// The current account's shoes (or the device's when signed out).
  Future<List<Shoe>> getAll();

  /// Adds or replaces a shoe. Making it primary unsets the others.
  /// Throws [ShoeValidationException] for invalid values.
  Future<void> save(Shoe shoe);

  /// Activities keep their link; the distance simply stops showing.
  Future<void> delete(String id);

  /// The primary, non-retired shoe, if any.
  Future<Shoe?> primary();
}
