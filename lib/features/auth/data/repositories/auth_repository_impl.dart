import 'package:fpdart/fpdart.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return right(await action());
    } catch (error) {
      return left(Failure(friendlyErrorMessage(error)));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async {
    final result = await _guard(remoteDataSource.signInWithGoogle);
    return result.flatMap<UserEntity>(
      (user) => user == null
          ? left<Failure, UserEntity>(Failure('Google sign-in was cancelled.'))
          : right<Failure, UserEntity>(user),
    );
  }

  @override
  Future<Either<Failure, UserEntity>> signUpWithRole({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String role,
  }) => _guard(
    () => remoteDataSource.signUpWithRole(
      uid: uid,
      email: email,
      name: name,
      phone: phone,
      role: role,
    ),
  );

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    final result = await _guard(remoteDataSource.getCurrentUserData);
    return result.flatMap<UserEntity>(
      (user) => user == null
          ? left<Failure, UserEntity>(SignedOutFailure())
          : right<Failure, UserEntity>(user),
    );
  }

  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    required String uid,
    required String name,
    required String phone,
  }) => _guard(
    () => remoteDataSource.updateProfile(uid: uid, name: name, phone: phone),
  );

  @override
  Future<Either<Failure, void>> deleteAccount(String uid, String reason) =>
      _guard(() => remoteDataSource.deleteAccount(uid, reason));

  @override
  Future<Either<Failure, void>> signOut() => _guard(remoteDataSource.signOut);
}
