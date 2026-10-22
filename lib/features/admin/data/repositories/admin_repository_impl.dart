import 'package:fpdart/fpdart.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/core/services/payment_api.dart';
import 'package:madebyhands/features/admin/data/datasources/admin_remote_data_source.dart';
import 'package:madebyhands/features/admin/domain/repositories/admin_repository.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';

class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDataSource remoteDataSource;
  final UserModerationApi userModerationApi;

  AdminRepositoryImpl(this.remoteDataSource, {required this.userModerationApi});

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return right(await action());
    } catch (error) {
      return left(Failure(friendlyErrorMessage(error)));
    }
  }

  @override
  Future<Either<Failure, Map<String, double>>> getPlatformSettings() =>
      _guard(() async {
        final settings = await remoteDataSource.getPlatformSettings();
        return {
          'flatFee': (settings['flatFee'] as num?)?.toDouble() ?? 50,
          'percentFee': (settings['percentFee'] as num?)?.toDouble() ?? 5,
          'commissionThreshold':
              (settings['commissionThreshold'] as num?)?.toDouble() ?? 999,
        };
      });

  @override
  Future<Either<Failure, void>> updatePlatformSettings(
    double flatFee,
    double percentFee,
    double commissionThreshold,
  ) => _guard(
    () => remoteDataSource.updatePlatformSettings(
      flatFee,
      percentFee,
      commissionThreshold,
    ),
  );

  @override
  Future<Either<Failure, List<CreatorProfile>>> getCreatorProfiles() =>
      _guard(remoteDataSource.getCreatorProfiles);

  @override
  Future<Either<Failure, void>> approveCreator(String uid) =>
      _guard(() => remoteDataSource.approveCreator(uid));

  @override
  Future<Either<Failure, void>> rejectCreator(String uid, String reason) =>
      _guard(() => remoteDataSource.rejectCreator(uid, reason));

  @override
  Future<Either<Failure, List<String>>> getCategories({
    bool seedDefaults = false,
  }) =>
      _guard(() => remoteDataSource.getCategories(seedDefaults: seedDefaults));

  @override
  Future<Either<Failure, void>> addCategory(String name) =>
      _guard(() => remoteDataSource.addCategory(name));

  @override
  Future<Either<Failure, void>> deleteCategory(String name) =>
      _guard(() => remoteDataSource.deleteCategory(name));

  @override
  Future<Either<Failure, List<String>>> resetCategoriesToDefaults() =>
      _guard(remoteDataSource.resetCategoriesToDefaults);

  // Goes through the payment API, not a direct Firestore write: suspending
  // must disable the user's actual Firebase Auth account and revoke any
  // open session, which only the Admin SDK (server-side) can do.
  @override
  Future<Either<Failure, void>> setUserModeration({
    required String uid,
    required int level,
    required String reason,
    bool immediate = false,
  }) => _guard(() async {
    // Warning stages remain admin-controlled Firestore writes and work
    // immediately. Only disabling/re-enabling Firebase Auth needs the
    // privileged server endpoint.
    if (level == 0 || level == 3) {
      await userModerationApi.setModeration(
        uid: uid,
        level: level,
        reason: reason,
        immediate: immediate,
      );
    }
    await remoteDataSource.setModerationState(
      uid: uid,
      level: level,
      reason: reason,
    );
  });

  @override
  Future<Either<Failure, void>> reviewProduct({
    required String productId,
    required bool approve,
    required String reviewerName,
    required String reviewerEmail,
    String? rejectionReason,
  }) => _guard(
    () => remoteDataSource.reviewProduct(
      productId: productId,
      approve: approve,
      reviewerName: reviewerName,
      reviewerEmail: reviewerEmail,
      rejectionReason: rejectionReason,
    ),
  );
}
