import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/credentials.dart';

enum AuthStatus { unknown, signedOut, signedIn }

enum AuthFailure {
  invalidEmail,
  passwordTooShort,
  invalidCredentials,
  emailTaken,
  network,
  providerUnavailable,
  unknown,
}

final class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.busy = false,
    this.failure,
    this.providers = const {},
    this.method,
  });

  final AuthStatus status;
  final AuthUser? user;

  /// A login, register or logout call is in flight.
  final bool busy;

  /// One-shot: cleared by the next state.
  final AuthFailure? failure;

  /// Apple / Google buttons to offer (Stitch 07).
  final Set<SocialProvider> providers;

  /// How the current account signed in during this run (null: email and
  /// password, or restored from a previous launch).
  final SocialProvider? method;

  AuthState _with({
    AuthStatus? status,
    AuthUser? user,
    bool busy = false,
    AuthFailure? failure,
    SocialProvider? method,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    busy: busy,
    failure: failure,
    providers: providers,
    method: method ?? this.method,
  );

  @override
  List<Object?> get props => [status, user, busy, failure, providers, method];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState()) {
    _changes = _repository.userChanges.listen(_setUser);
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthUser?> _changes;

  Future<void> start() async {
    _setUser(await _repository.currentUser());
    await refreshProviders();
  }

  /// Asks again which Apple / Google buttons to show (the server may have
  /// been set up since, or the device was offline).
  Future<void> refreshProviders() async {
    final providers = await _repository.availableProviders();
    if (isClosed) return;
    emit(
      AuthState(
        status: state.status,
        user: state.user,
        busy: state.busy,
        providers: providers,
        method: state.method,
      ),
    );
  }

  Future<void> signInWith(SocialProvider provider) async {
    emit(state._with(busy: true));
    try {
      final user = await _repository.signInWith(provider);
      _setUser(user, method: provider);
    } on AuthException catch (e) {
      emit(
        state._with(
          status: AuthStatus.signedOut,
          failure: switch (e.error) {
            AuthError.cancelled => null,
            AuthError.network => AuthFailure.network,
            AuthError.providerUnavailable => AuthFailure.providerUnavailable,
            AuthError.emailTaken => AuthFailure.emailTaken,
            _ => AuthFailure.unknown,
          },
        ),
      );
    }
  }

  Future<void> login(String email, String password) =>
      _submit(email, password, _repository.login);

  Future<void> register(String email, String password) =>
      _submit(email, password, _repository.register);

  Future<void> logout() async {
    emit(state._with(busy: true));
    await _repository.logout();
    _setUser(null);
  }

  Future<void> deleteAccount() async {
    emit(state._with(busy: true));
    try {
      await _repository.deleteAccount();
      _setUser(null);
    } on AuthException catch (e) {
      emit(
        state._with(
          failure: e.error == AuthError.network
              ? AuthFailure.network
              : AuthFailure.unknown,
        ),
      );
    }
  }

  Future<void> _submit(
    String email,
    String password,
    Future<AuthUser> Function({required String email, required String password})
    call,
  ) async {
    final problem = checkCredentials(email, password);
    if (problem != null) {
      emit(
        state._with(
          failure: switch (problem) {
            CredentialsProblem.invalidEmail => AuthFailure.invalidEmail,
            CredentialsProblem.passwordTooShort => AuthFailure.passwordTooShort,
          },
        ),
      );
      return;
    }
    emit(state._with(busy: true));
    try {
      _setUser(await call(email: email, password: password));
    } on AuthException catch (e) {
      emit(
        state._with(
          status: AuthStatus.signedOut,
          failure: switch (e.error) {
            AuthError.invalidCredentials => AuthFailure.invalidCredentials,
            AuthError.emailTaken => AuthFailure.emailTaken,
            AuthError.invalidInput => AuthFailure.invalidEmail,
            AuthError.network => AuthFailure.network,
            AuthError.providerUnavailable => AuthFailure.providerUnavailable,
            AuthError.cancelled || AuthError.unknown => AuthFailure.unknown,
          },
        ),
      );
    }
  }

  void _setUser(AuthUser? user, {SocialProvider? method}) {
    if (isClosed) return;
    emit(
      AuthState(
        status: user == null ? AuthStatus.signedOut : AuthStatus.signedIn,
        user: user,
        providers: state.providers,
        method: user == null
            ? null
            : (method ?? (user == state.user ? state.method : null)),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
