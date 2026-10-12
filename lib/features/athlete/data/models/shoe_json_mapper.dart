import '../../../../core/sync/synced_record_store.dart';
import '../../domain/entities/shoe.dart';

/// Shoe ↔ the API object (docs/api.md v1.2, Shoes) without the bookkeeping
/// fields, which the record store keeps itself.
abstract final class ShoeJsonMapper {
  static Json toJson(Shoe s) => {
    'name': s.name,
    'model': s.model,
    'lifespanKm': s.lifespanKm,
    'startDistanceM': s.startDistanceMeters,
    'primary': s.primary,
    'retired': s.retired,
  };

  static Shoe fromJson(String id, Json json) => Shoe(
    id: id,
    name: json['name']! as String,
    model: json['model'] as String?,
    lifespanKm: (json['lifespanKm'] as num?)?.toInt() ?? kDefaultShoeLifespanKm,
    startDistanceMeters: (json['startDistanceM'] as num?)?.toDouble() ?? 0,
    primary: json['primary'] as bool? ?? false,
    retired: json['retired'] as bool? ?? false,
  );
}
