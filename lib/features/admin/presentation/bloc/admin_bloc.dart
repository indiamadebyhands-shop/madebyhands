import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:madebyhands/features/admin/domain/entities/admin_log_entry.dart';
import 'package:madebyhands/features/admin/domain/repositories/admin_log_repository.dart';
import 'package:madebyhands/features/admin/domain/repositories/admin_repository.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';

part 'admin_event.dart';
part 'admin_state.dart';

/// Admin panel data that is not streamed directly by the views: platform
/// economics, creator profiles for the overview, and categories (which the
/// creator onboarding and listing forms also read).
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final AdminRepository _adminRepository;
  final AdminLogRepository _logs;

  AdminBloc({
    required AdminRepository adminRepository,
    required AdminLogRepository logRepository,
  }) : _adminRepository = adminRepository,
       _logs = logRepository,
       super(const AdminState()) {
    on<AdminLoadDataRequested>(_onLoadDataRequested);
    on<AdminCategoriesRequested>(_onCategoriesRequested);
    on<AdminApproveCreatorRequested>(_onApproveCreatorRequested);
    on<AdminRejectCreatorRequested>(_onRejectCreatorRequested);
    on<AdminAddCategoryRequested>(_onAddCategoryRequested);
    on<AdminDeleteCategoryRequested>(_onDeleteCategoryRequested);
    on<AdminResetCategoriesRequested>(_onResetCategoriesRequested);
    on<AdminSuspendUserRequested>(_onSuspendUserRequested);
    on<AdminUpdateSettingsRequested>(_onUpdateSettingsRequested);
    on<AdminProductReviewRequested>(_onProductReviewRequested);
  }

  /// Name to show in the activity log for a creator, falling back to the id.
  String _creatorLabel(String uid) {
    for (final profile in state.creatorProfiles) {
      if (profile.uid != uid) continue;
      final name = profile.name.trim();
      final business = profile.businessName.trim();
      if (name.isNotEmpty && business.isNotEmpty) return '$name ($business)';
      if (name.isNotEmpty) return name;
      if (business.isNotEmpty) return business;
    }
    return uid;
  }

  static String _money(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  Future<void> _onProductReviewRequested(
    AdminProductReviewRequested event,
    Emitter<AdminState> emit,
  ) async {
    final res = await _adminRepository.reviewProduct(
      productId: event.productId,
      approve: event.approve,
      reviewerName: event.reviewerName,
      reviewerEmail: event.reviewerEmail,
      rejectionReason: event.rejectionReason,
    );
    final failure = res.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure));
      return;
    }
    emit(
      state.copyWith(
        notice: event.approve ? 'Product approved.' : 'Product rejected.',
      ),
    );
    final product = event.productName.trim().isEmpty
        ? event.productId
        : '"${event.productName.trim()}"';
    await _logs.log(
      category: AdminLogCategory.product,
      action: event.approve ? 'product.approved' : 'product.rejected',
      summary: event.approve
          ? 'Approved product $product.'
          : 'Rejected product $product. Reason: ${(event.rejectionReason ?? '').trim()}',
      targetId: event.productId,
    );
  }

  Future<void> _onLoadDataRequested(
    AdminLoadDataRequested event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    final settingsResult = await _adminRepository.getPlatformSettings();
    final profilesResult = await _adminRepository.getCreatorProfiles();
    final categoriesResult = await _adminRepository.getCategories(
      seedDefaults: true,
    );

    var next = state.copyWith(isLoading: false);
    String? error;
    settingsResult.fold<void>((failure) => error = failure.message, (settings) {
      next = next.copyWith(
        flatFee: settings['flatFee'],
        percentFee: settings['percentFee'],
        commissionThreshold: settings['commissionThreshold'],
      );
    });
    profilesResult.fold<void>(
      (failure) => error ??= failure.message,
      (profiles) => next = next.copyWith(creatorProfiles: profiles),
    );
    categoriesResult.fold<void>(
      (failure) => error ??= failure.message,
      (categories) => next = next.copyWith(categories: categories),
    );
    emit(next.copyWith(errorMessage: error));
  }

  Future<void> _onCategoriesRequested(
    AdminCategoriesRequested event,
    Emitter<AdminState> emit,
  ) async {
    final res = await _adminRepository.getCategories();
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (categories) => emit(state.copyWith(categories: categories)),
    );
  }

  Future<void> _onApproveCreatorRequested(
    AdminApproveCreatorRequested event,
    Emitter<AdminState> emit,
  ) async {
    final label = _creatorLabel(event.uid);
    final res = await _adminRepository.approveCreator(event.uid);
    final failure = res.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure));
      return;
    }
    await _reloadProfiles(emit, notice: 'Creator verified.');
    await _logs.log(
      category: AdminLogCategory.creator,
      action: 'creator.verified',
      summary: 'Verified creator $label.',
      targetId: event.uid,
    );
  }

  Future<void> _onRejectCreatorRequested(
    AdminRejectCreatorRequested event,
    Emitter<AdminState> emit,
  ) async {
    final label = _creatorLabel(event.uid);
    final wasVerified = state.creatorProfiles.any(
      (profile) => profile.uid == event.uid && profile.isVerified,
    );
    final res = await _adminRepository.rejectCreator(event.uid, event.reason);
    final failure = res.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure));
      return;
    }
    await _reloadProfiles(emit, notice: 'Verification rejected.');
    await _logs.log(
      category: AdminLogCategory.creator,
      action: wasVerified ? 'creator.revoked' : 'creator.rejected',
      summary: wasVerified
          ? 'Revoked verification of creator $label. Reason: ${event.reason}'
          : 'Rejected verification of creator $label. Reason: ${event.reason}',
      targetId: event.uid,
    );
  }

  Future<void> _reloadProfiles(
    Emitter<AdminState> emit, {
    String? notice,
  }) async {
    final res = await _adminRepository.getCreatorProfiles();
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (profiles) =>
          emit(state.copyWith(creatorProfiles: profiles, notice: notice)),
    );
  }

  Future<void> _onAddCategoryRequested(
    AdminAddCategoryRequested event,
    Emitter<AdminState> emit,
  ) async {
    final name = event.name.trim();
    if (name.isEmpty) return;
    if (state.categories.any((c) => c.toLowerCase() == name.toLowerCase())) {
      emit(state.copyWith(errorMessage: '"$name" already exists.'));
      return;
    }
    final res = await _adminRepository.addCategory(name);
    final failure = res.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure));
      return;
    }
    emit(state.copyWith(categories: [...state.categories, name]..sort()));
    await _logs.log(
      category: AdminLogCategory.category,
      action: 'category.added',
      summary: 'Added category "$name".',
    );
  }

  Future<void> _onDeleteCategoryRequested(
    AdminDeleteCategoryRequested event,
    Emitter<AdminState> emit,
  ) async {
    final res = await _adminRepository.deleteCategory(event.name);
    final failure = res.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure));
      return;
    }
    emit(
      state.copyWith(
        categories: state.categories.where((c) => c != event.name).toList(),
      ),
    );
    await _logs.log(
      category: AdminLogCategory.category,
      action: 'category.deleted',
      summary: 'Deleted category "${event.name}".',
    );
  }

  Future<void> _onResetCategoriesRequested(
    AdminResetCategoriesRequested event,
    Emitter<AdminState> emit,
  ) async {
    final res = await _adminRepository.resetCategoriesToDefaults();
    final categories = res.fold<List<String>?>((_) => null, (value) => value);
    if (categories == null) {
      emit(
        state.copyWith(
          errorMessage: res.fold((failure) => failure.message, (_) => null),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        categories: categories,
        notice: 'Categories reset to defaults.',
      ),
    );
    await _logs.log(
      category: AdminLogCategory.category,
      action: 'category.reset',
      summary:
          'Reset categories to the ${categories.length} default categories.',
    );
  }

  Future<void> _onSuspendUserRequested(
    AdminSuspendUserRequested event,
    Emitter<AdminState> emit,
  ) async {
    final res = await _adminRepository.setUserModeration(
      uid: event.uid,
      level: event.moderationLevel,
      reason: event.reason,
    );
    final failure = res.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure));
      return;
    }
    emit(
      state.copyWith(
        notice: switch (event.moderationLevel) {
          0 => 'Warning cleared and user reinstated.',
          1 => 'First warning sent.',
          2 => 'Second warning sent and storefront hidden.',
          _ => 'User suspended.',
        },
      ),
    );
    final who = event.userLabel.trim().isEmpty
        ? event.uid
        : event.userLabel.trim();
    await _logs.log(
      category: AdminLogCategory.user,
      action: switch (event.moderationLevel) {
        0 => 'user.reinstated',
        1 => 'creator.warning.first',
        2 => 'creator.warning.second',
        _ => 'user.suspended',
      },
      summary: switch (event.moderationLevel) {
        0 => 'Cleared warnings and reinstated user $who.',
        1 => 'Sent first warning to $who: ${event.reason}',
        2 =>
          'Sent second warning to $who and hid their storefront: ${event.reason}',
        _ => 'Finally suspended user $who: ${event.reason}',
      },
      targetId: event.uid,
    );
  }

  Future<void> _onUpdateSettingsRequested(
    AdminUpdateSettingsRequested event,
    Emitter<AdminState> emit,
  ) async {
    final before = state;
    final res = await _adminRepository.updatePlatformSettings(
      event.flatFee,
      event.percentFee,
      event.commissionThreshold,
    );
    final failure = res.fold<String?>(
      (failure) => failure.message,
      (_) => null,
    );
    if (failure != null) {
      emit(state.copyWith(errorMessage: failure));
      return;
    }
    emit(
      state.copyWith(
        flatFee: event.flatFee,
        percentFee: event.percentFee,
        commissionThreshold: event.commissionThreshold,
        notice: 'Platform fees updated.',
      ),
    );
    final changes = <String>[
      if (before.flatFee != event.flatFee)
        'flat fee ₹${_money(before.flatFee)} → ₹${_money(event.flatFee)}',
      if (before.percentFee != event.percentFee)
        'commission ${_money(before.percentFee)}% → ${_money(event.percentFee)}%',
      if (before.commissionThreshold != event.commissionThreshold)
        'commission threshold ₹${_money(before.commissionThreshold)} → ₹${_money(event.commissionThreshold)}',
    ];
    if (changes.isEmpty) return;
    await _logs.log(
      category: AdminLogCategory.settings,
      action: 'settings.fees_updated',
      summary: 'Changed platform fees: ${changes.join(', ')}.',
    );
  }
}
