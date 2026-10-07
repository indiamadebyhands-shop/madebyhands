part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

final class AuthGoogleSignInRequested extends AuthEvent {}

final class AuthSignUpWithRoleRequested extends AuthEvent {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String role;

  const AuthSignUpWithRoleRequested({
    required this.uid,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
  });
}

final class AuthIsUserLoggedIn extends AuthEvent {}

final class AuthDeleteAccountRequested extends AuthEvent {
  final String uid;
  final String reason;

  const AuthDeleteAccountRequested(this.uid, {required this.reason});

  @override
  List<Object> get props => [uid, reason];
}

final class AuthLogoutRequested extends AuthEvent {}
