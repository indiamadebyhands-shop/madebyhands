import 'package:fpdart/fpdart.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';

/// Returned by [AuthRepository.getCurrentUser] when nobody is signed in, so
/// callers can tell "signed out" apart from a real error.
class SignedOutFailure extends Failure {
  SignedOutFailure() : super('You are signed out.');
}

abstract interface class AuthRepository {
  Future<Either<Failure, UserEntity>> signInWithGoogle();

  /// Signs in as a fresh guest buyer, skipping Google and role selection.
  /// Temporary: see `kTestBuyerLoginEnabled`.
  Future<Either<Failure, UserEntity>> signInAsTestBuyer();
  Future<Either<Failure, UserEntity>> signUpWithRole({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String role,
  });
  Future<Either<Failure, UserEntity>> getCurrentUser();
  Future<Either<Failure, UserEntity>> updateProfile({
    required String uid,
    required String name,
    required String phone,
  });
  Future<Either<Failure, void>> deleteAccount(String uid, String reason);
  Future<Either<Failure, void>> signOut();
}
