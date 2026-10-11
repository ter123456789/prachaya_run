import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

enum ProfileSaveResult { saved, offline, failed }

final class ProfileState extends Equatable {
  const ProfileState({this.profile, this.saving = false, this.result});

  /// Null when signed out or not loaded yet.
  final UserProfile? profile;
  final bool saving;

  /// One-shot outcome of the last save.
  final ProfileSaveResult? result;

  double? get weightKg => profile?.weightKg;

  @override
  List<Object?> get props => [profile, saving, result];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;

  Future<void> load() async {
    final profile = await _repository.load();
    if (!isClosed) emit(ProfileState(profile: profile));
  }

  void clear() => emit(const ProfileState());

  Future<void> save({String? displayName, double? weightKg}) async {
    emit(ProfileState(profile: state.profile, saving: true));
    try {
      final profile = await _repository.update(
        displayName: displayName,
        weightKg: weightKg,
        clearWeight: weightKg == null,
      );
      emit(ProfileState(profile: profile, result: ProfileSaveResult.saved));
    } on ProfileUpdateException catch (e) {
      emit(
        ProfileState(
          profile: state.profile,
          result: e.offline
              ? ProfileSaveResult.offline
              : ProfileSaveResult.failed,
        ),
      );
    }
  }
}
