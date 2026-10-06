import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:madebyhands/core/constants/feature_flags.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  /// Starts in [AuthLoading] so the app shows a spinner, not the welcome
  /// screen, while the saved session is restored.
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(AuthLoading()) {
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthTestBuyerSignInRequested>(_onTestBuyerSignInRequested);
    on<AuthSignUpWithRoleRequested>(_onSignUpWithRoleRequested);
    on<AuthIsUserLoggedIn>(_onIsUserLoggedIn);
    on<AuthDeleteAccountRequested>(_onDeleteAccountRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  AuthState _stateFor(UserEntity user) =>
      user.role.isEmpty ? AuthNeedsRoleSelection(user) : AuthSuccess(user);

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final res = await _authRepository.signInWithGoogle();
    res.fold(
      (failure) => emit(AuthFailure(failure.message, canRetrySession: false)),
      (user) => emit(_stateFor(user)),
    );
  }

  Future<void> _onTestBuyerSignInRequested(
    AuthTestBuyerSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    // The flag is checked here as well as in the UI, so the event does
    // nothing once the test sign-in is switched off.
    if (!kTestBuyerLoginEnabled) return;
    emit(AuthLoading());
    final res = await _authRepository.signInAsTestBuyer();
    res.fold(
      (failure) => emit(AuthFailure(failure.message, canRetrySession: false)),
      (user) => emit(_stateFor(user)),
    );
  }

  Future<void> _onSignUpWithRoleRequested(
    AuthSignUpWithRoleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final res = await _authRepository.signUpWithRole(
      uid: event.uid,
      email: event.email,
      name: event.name,
      phone: event.phone,
      role: event.role,
    );
    res.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthSuccess(user)),
    );
  }

  Future<void> _onIsUserLoggedIn(
    AuthIsUserLoggedIn event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final res = await _authRepository.getCurrentUser();
    res.fold(
      (failure) => emit(
        failure is SignedOutFailure ? AuthInitial() : AuthFailure(failure.message),
      ),
      (user) => emit(_stateFor(user)),
    );
  }

  Future<void> _onDeleteAccountRequested(
    AuthDeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    final previous = state;
    emit(AuthLoading());
    final res = await _authRepository.deleteAccount(event.uid, event.reason);
    res.fold((failure) {
      // Keep the user signed in and show why deletion did not happen.
      emit(AuthActionFailed(failure.message));
      if (previous is AuthSuccess) emit(previous);
    }, (_) => emit(AuthInitial()));
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _authRepository.signOut();
    emit(AuthInitial());
  }
}
