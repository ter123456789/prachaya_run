import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/planned_route.dart';
import '../../domain/repositories/route_repository.dart';

final class RoutesState extends Equatable {
  const RoutesState({this.routes = const [], this.loaded = false});

  final List<PlannedRoute> routes;
  final bool loaded;

  @override
  List<Object?> get props => [routes, loaded];
}

/// The saved routes, reloaded on account changes and after a sync.
class RoutesCubit extends Cubit<RoutesState> {
  RoutesCubit(this._routes) : super(const RoutesState());

  final RouteRepository _routes;

  Future<void> load() async {
    final routes = await _routes.getAll();
    if (isClosed) return;
    emit(RoutesState(routes: routes, loaded: true));
  }

  Future<void> delete(String id) async {
    await _routes.delete(id);
    await load();
  }
}
