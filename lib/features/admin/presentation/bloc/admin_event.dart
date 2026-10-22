part of 'admin_bloc.dart';

sealed class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object> get props => [];
}

/// Loads everything the admin panel needs. Admin-only.
final class AdminLoadDataRequested extends AdminEvent {}

/// Loads categories without seeding. Safe for creators.
final class AdminCategoriesRequested extends AdminEvent {}

final class AdminSuspendUserRequested extends AdminEvent {
  final String uid;
  final int moderationLevel;
  final String reason;
  final bool immediate;

  /// Name or email of the user, for the activity log only.
  final String userLabel;
  const AdminSuspendUserRequested(
    this.uid,
    this.moderationLevel, {
    this.reason = '',
    this.immediate = false,
    this.userLabel = '',
  });

  @override
  List<Object> get props => [
    uid,
    moderationLevel,
    reason,
    immediate,
    userLabel,
  ];
}

final class AdminApproveCreatorRequested extends AdminEvent {
  final String uid;
  const AdminApproveCreatorRequested(this.uid);

  @override
  List<Object> get props => [uid];
}

final class AdminRejectCreatorRequested extends AdminEvent {
  final String uid;
  final String reason;
  const AdminRejectCreatorRequested(this.uid, this.reason);

  @override
  List<Object> get props => [uid, reason];
}

final class AdminAddCategoryRequested extends AdminEvent {
  final String name;
  const AdminAddCategoryRequested(this.name);

  @override
  List<Object> get props => [name];
}

final class AdminDeleteCategoryRequested extends AdminEvent {
  final String name;
  const AdminDeleteCategoryRequested(this.name);

  @override
  List<Object> get props => [name];
}

/// Wipes every current category and reseeds the app's built-in defaults.
final class AdminResetCategoriesRequested extends AdminEvent {}

final class AdminUpdateSettingsRequested extends AdminEvent {
  final double flatFee;
  final double percentFee;
  final double commissionThreshold;
  const AdminUpdateSettingsRequested({
    required this.flatFee,
    required this.percentFee,
    required this.commissionThreshold,
  });

  @override
  List<Object> get props => [flatFee, percentFee, commissionThreshold];
}

final class AdminProductReviewRequested extends AdminEvent {
  final String productId;
  final bool approve;
  final String reviewerName;
  final String reviewerEmail;
  final String? rejectionReason;

  /// Product name, for the activity log only.
  final String productName;

  const AdminProductReviewRequested({
    required this.productId,
    required this.approve,
    required this.reviewerName,
    required this.reviewerEmail,
    this.rejectionReason,
    this.productName = '',
  });

  @override
  List<Object> get props => [
    productId,
    approve,
    reviewerName,
    reviewerEmail,
    productName,
  ];
}
