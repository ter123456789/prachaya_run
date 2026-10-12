import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/services/profile_validation.dart';

enum ProfileSaveResult { saved, invalid }

final class ProfileState extends Equatable {
  const ProfileState({
    this.profile = const UserProfile(),
    this.loaded = false,
    this.saving = false,
    this.result,
    this.invalid = const {},
  });

  /// The device's profile while signed out, the account's when signed in.
  final UserProfile profile;
  final bool loaded;
  final bool saving;

  /// One-shot outcome of the last save.
  final ProfileSaveResult? result;

  /// Fields the last save rejected.
  final Set<ProfileField> invalid;

  double? get weightKg => profile.weightKg;

  @override
  List<Object?> get props => [profile, loaded, saving, result, invalid];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileState());

  final ProfileRepository _repository;

  Future<void> load() async {
    final profile = await _repository.load();
    if (!isClosed) emit(ProfileState(profile: profile, loaded: true));
  }

  /// Saves on the device straight away (and syncs when signed in).
  Future<void> save(UserProfile profile) async {
    emit(ProfileState(profile: state.profile, loaded: true, saving: true));
    try {
      final saved = await _repository.save(profile);
      emit(
        ProfileState(
          profile: saved,
          loaded: true,
          result: ProfileSaveResult.saved,
        ),
      );
    } on ProfileValidationException catch (e) {
      emit(
        ProfileState(
          profile: state.profile,
          loaded: true,
          result: ProfileSaveResult.invalid,
          invalid: e.fields,
        ),
      );
    }
  }
}
