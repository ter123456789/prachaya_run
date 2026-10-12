import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../activity/domain/repositories/activity_repository.dart';
import '../../domain/entities/shoe.dart';
import '../../domain/repositories/shoe_repository.dart';
import '../../domain/services/shoe_usage.dart';

final class GearState extends Equatable {
  const GearState({this.usage = const [], this.loaded = false});

  /// Primary first, then active, then retired.
  final List<ShoeUsage> usage;
  final bool loaded;

  List<Shoe> get shoes => [for (final u in usage) u.shoe];

  @override
  List<Object?> get props => [usage, loaded];
}

/// Shoes with their mileage from linked activities.
class GearCubit extends Cubit<GearState> {
  GearCubit(this._shoes, this._activities) : super(const GearState());

  final ShoeRepository _shoes;
  final ActivityRepository _activities;

  Future<void> load() async {
    final shoes = await _shoes.getAll();
    final activities = await _activities.getAll();
    if (!isClosed) {
      emit(GearState(usage: shoeUsage(shoes, activities), loaded: true));
    }
  }

  /// Throws [ShoeValidationException] for invalid values.
  Future<void> save(Shoe shoe) async {
    await _shoes.save(shoe);
    await load();
  }

  Future<void> delete(String id) async {
    await _shoes.delete(id);
    await load();
  }
}
