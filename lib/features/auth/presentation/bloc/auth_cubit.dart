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
  unknown,
}

final class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.busy = false,
    this.failure,
  });

  final AuthStatus status;
  final AuthUser? user;

  /// A login, register or logout call is in flight.
  final bool busy;

  /// One-shot: cleared by the next state.
  final AuthFailure? failure;

  @override
  List<Object?> get props => [status, user, busy, failure];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState()) {
    _changes = _repository.userChanges.listen(_setUser);
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthUser?> _changes;

  Future<void> start() async => _setUser(await _repository.currentUser());

  Future<void> login(String email, String password) =>
      _submit(email, password, _repository.login);

  Future<void> register(String email, String password) =>
      _submit(email, password, _repository.register);

  Future<void> logout() async {
    emit(AuthState(status: state.status, user: state.user, busy: true));
    await _repository.logout();
    _setUser(null);
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
        AuthState(
          status: state.status,
          failure: switch (problem) {
            CredentialsProblem.invalidEmail => AuthFailure.invalidEmail,
            CredentialsProblem.passwordTooShort => AuthFailure.passwordTooShort,
          },
        ),
      );
      return;
    }
    emit(AuthState(status: state.status, busy: true));
    try {
      _setUser(await call(email: email, password: password));
    } on AuthException catch (e) {
      emit(
        AuthState(
          status: AuthStatus.signedOut,
          failure: switch (e.error) {
            AuthError.invalidCredentials => AuthFailure.invalidCredentials,
            AuthError.emailTaken => AuthFailure.emailTaken,
            AuthError.invalidInput => AuthFailure.invalidEmail,
            AuthError.network => AuthFailure.network,
            AuthError.unknown => AuthFailure.unknown,
          },
        ),
      );
    }
  }

  void _setUser(AuthUser? user) {
    if (isClosed) return;
    emit(
      AuthState(
        status: user == null ? AuthStatus.signedOut : AuthStatus.signedIn,
        user: user,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }
}
