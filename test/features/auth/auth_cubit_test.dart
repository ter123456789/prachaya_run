import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prachaya_run/features/auth/domain/entities/auth_user.dart';
import 'package:prachaya_run/features/auth/domain/repositories/auth_repository.dart';
import 'package:prachaya_run/features/auth/presentation/bloc/auth_cubit.dart';

import '../../helpers/fakes.dart';

void main() {
  const user = AuthUser(id: 'u1', email: 'a@b.co');

  blocTest<AuthCubit, AuthState>(
    'start restores a saved session',
    build: () => AuthCubit(FakeAuthRepository(user: user)),
    act: (cubit) => cubit.start(),
    expect: () => [const AuthState(status: AuthStatus.signedIn, user: user)],
  );

  blocTest<AuthCubit, AuthState>(
    'invalid input is rejected before calling the server',
    build: () => AuthCubit(FakeAuthRepository()),
    seed: () => const AuthState(status: AuthStatus.signedOut),
    act: (cubit) async {
      await cubit.login('not-an-email', 'longenough');
      await cubit.register('a@b.co', 'short');
    },
    expect: () => [
      const AuthState(
        status: AuthStatus.signedOut,
        failure: AuthFailure.invalidEmail,
      ),
      const AuthState(
        status: AuthStatus.signedOut,
        failure: AuthFailure.passwordTooShort,
      ),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'login success signs in',
    build: () => AuthCubit(FakeAuthRepository()),
    seed: () => const AuthState(status: AuthStatus.signedOut),
    act: (cubit) => cubit.login('a@b.co', 'password1'),
    expect: () => [
      const AuthState(status: AuthStatus.signedOut, busy: true),
      const AuthState(status: AuthStatus.signedIn, user: user),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'server errors map to a failure',
    build: () =>
        AuthCubit(FakeAuthRepository()..failNext = AuthError.emailTaken),
    seed: () => const AuthState(status: AuthStatus.signedOut),
    act: (cubit) => cubit.register('a@b.co', 'password1'),
    expect: () => [
      const AuthState(status: AuthStatus.signedOut, busy: true),
      const AuthState(
        status: AuthStatus.signedOut,
        failure: AuthFailure.emailTaken,
      ),
    ],
  );

  final repo = FakeAuthRepository(user: user);
  blocTest<AuthCubit, AuthState>(
    'the server ending the session signs out',
    build: () => AuthCubit(repo),
    seed: () => const AuthState(status: AuthStatus.signedIn, user: user),
    act: (_) => repo.endSession(),
    expect: () => [const AuthState(status: AuthStatus.signedOut)],
  );

  final deleting = FakeAuthRepository(user: user);
  blocTest<AuthCubit, AuthState>(
    'deleteAccount signs out',
    build: () => AuthCubit(deleting),
    seed: () => const AuthState(status: AuthStatus.signedIn, user: user),
    act: (cubit) => cubit.deleteAccount(),
    expect: () => [
      const AuthState(status: AuthStatus.signedIn, user: user, busy: true),
      const AuthState(status: AuthStatus.signedOut),
    ],
    verify: (_) => expect(deleting.deleted, isTrue),
  );

  group('social sign-in', () {
    blocTest<AuthCubit, AuthState>(
      'start offers the available providers',
      build: () =>
          AuthCubit(FakeAuthRepository(providers: {SocialProvider.apple})),
      act: (cubit) => cubit.start(),
      expect: () => [
        const AuthState(status: AuthStatus.signedOut),
        const AuthState(
          status: AuthStatus.signedOut,
          providers: {SocialProvider.apple},
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'Apple sign-in signs in and remembers the method',
      build: () => AuthCubit(FakeAuthRepository()),
      seed: () => const AuthState(status: AuthStatus.signedOut),
      act: (cubit) => cubit.signInWith(SocialProvider.apple),
      expect: () => [
        const AuthState(status: AuthStatus.signedOut, busy: true),
        const AuthState(
          status: AuthStatus.signedIn,
          user: AuthUser(id: 'u1', email: 'apple@example.com'),
          method: SocialProvider.apple,
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'closing the sheet shows no error',
      build: () =>
          AuthCubit(FakeAuthRepository()..failNext = AuthError.cancelled),
      seed: () => const AuthState(status: AuthStatus.signedOut),
      act: (cubit) => cubit.signInWith(SocialProvider.google),
      expect: () => [
        const AuthState(status: AuthStatus.signedOut, busy: true),
        const AuthState(status: AuthStatus.signedOut),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'provider not set up on the server',
      build: () => AuthCubit(
        FakeAuthRepository()..failNext = AuthError.providerUnavailable,
      ),
      seed: () => const AuthState(status: AuthStatus.signedOut),
      act: (cubit) => cubit.signInWith(SocialProvider.google),
      skip: 1,
      expect: () => [
        const AuthState(
          status: AuthStatus.signedOut,
          failure: AuthFailure.providerUnavailable,
        ),
      ],
    );
  });
}
