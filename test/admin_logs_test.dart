import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/features/admin/domain/entities/admin_log_entry.dart';
import 'package:madebyhands/features/admin/domain/repositories/admin_log_repository.dart';
import 'package:madebyhands/features/admin/domain/repositories/admin_repository.dart';
import 'package:madebyhands/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:madebyhands/features/admin/presentation/views/admin_logs_view.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/domain/repositories/auth_repository.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';

class _RecordingLogs implements AdminLogRepository {
  final entries =
      <
        ({
          String action,
          AdminLogCategory category,
          String summary,
          String targetId,
        })
      >[];

  @override
  Future<void> log({
    required AdminLogCategory category,
    required String action,
    required String summary,
    String targetId = '',
  }) async {
    entries.add((
      action: action,
      category: category,
      summary: summary,
      targetId: targetId,
    ));
  }

  @override
  Stream<List<AdminLogEntry>> watchLogs({int limit = 300}) =>
      const Stream.empty();
}

class _FakeAdminRepository implements AdminRepository {
  bool failNext = false;
  List<CreatorProfile> profiles = [];

  Either<Failure, T> _result<T>(T value) {
    if (failNext) {
      failNext = false;
      return left(Failure('boom'));
    }
    return right(value);
  }

  @override
  Future<Either<Failure, void>> addCategory(String name) async => _result(null);

  @override
  Future<Either<Failure, void>> deleteCategory(String name) async =>
      _result(null);

  @override
  Future<Either<Failure, void>> updatePlatformSettings(
    double flatFee,
    double percentFee,
    double commissionThreshold,
  ) async => _result(null);

  @override
  Future<Either<Failure, void>> setUserModeration({
    required String uid,
    required int level,
    required String reason,
  }) async => _result(null);

  @override
  Future<Either<Failure, void>> approveCreator(String uid) async =>
      _result(null);

  @override
  Future<Either<Failure, void>> rejectCreator(
    String uid,
    String reason,
  ) async => _result(null);

  @override
  Future<Either<Failure, List<CreatorProfile>>> getCreatorProfiles() async =>
      right(profiles);

  @override
  Future<Either<Failure, Map<String, double>>> getPlatformSettings() async =>
      right(const {'flatFee': 50, 'percentFee': 5, 'commissionThreshold': 999});

  @override
  Future<Either<Failure, List<String>>> getCategories({
    bool seedDefaults = false,
  }) async => right(const ['Pottery']);

  @override
  Future<Either<Failure, List<String>>> resetCategoriesToDefaults() async =>
      _result(const ['A', 'B', 'C']);

  @override
  Future<Either<Failure, void>> reviewProduct({
    required String productId,
    required bool approve,
    required String reviewerName,
    required String reviewerEmail,
    String? rejectionReason,
  }) async => _result(null);
}

CreatorProfile _creator(String status) => CreatorProfile(
  uid: 'c1',
  name: 'Asha Rao',
  businessName: 'Rao Pottery',
  profileImage: '',
  bio: '',
  location: '',
  socialLinks: const [],
  portfolio: const [],
  story: '',
  verificationStatus: status,
);

class _NoAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An AuthBloc that is already signed in as [user].
class _SignedInAuthBloc extends AuthBloc {
  final UserEntity user;

  _SignedInAuthBloc(this.user) : super(authRepository: _NoAuthRepository());

  @override
  AuthState get state => AuthSuccess(user);
}

void main() {
  group('AdminLogEntry', () {
    test('round-trips through its map and matches searches', () {
      final entry = AdminLogEntry(
        id: 'l1',
        actorUid: 'a1',
        actorName: 'Suhani',
        actorEmail: 'suhani@example.com',
        actorRole: 'Super Admin',
        action: 'creator.verified',
        category: AdminLogCategory.creator,
        summary: 'Verified creator Asha Rao.',
        targetId: 'c1',
      );
      final copy = AdminLogEntry.fromMap('l1', entry.toMap());

      expect(copy.action, 'creator.verified');
      expect(copy.category, AdminLogCategory.creator);
      expect(copy.actorLabel, 'Suhani');
      expect(copy.matches('asha'), isTrue);
      expect(copy.matches('SUHANI'), isTrue);
      expect(copy.matches('payout'), isFalse);
      expect(copy.matches('   '), isTrue);
    });

    test('falls back to the email, then a placeholder, for the actor', () {
      AdminLogEntry entry(String name, String email) => AdminLogEntry(
        id: '',
        actorUid: 'a',
        actorName: name,
        actorEmail: email,
        actorRole: '',
        action: 'x',
        category: AdminLogCategory.settings,
        summary: '',
      );
      expect(entry('', 'a@b.com').actorLabel, 'a@b.com');
      expect(entry('', '').actorLabel, 'Unknown admin');
    });

    test('an unknown category does not break reading old entries', () {
      final entry = AdminLogEntry.fromMap('l', {'category': 'something-new'});
      expect(entry.category, AdminLogCategory.settings);
    });
  });

  group('AdminBloc records what admins do', () {
    late _RecordingLogs logs;
    late _FakeAdminRepository repository;
    late AdminBloc bloc;

    setUp(() {
      logs = _RecordingLogs();
      repository = _FakeAdminRepository();
      bloc = AdminBloc(adminRepository: repository, logRepository: logs);
    });

    tearDown(() => bloc.close());

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    test('adding and deleting a category', () async {
      bloc.add(const AdminAddCategoryRequested('Glass'));
      await settle();
      bloc.add(const AdminDeleteCategoryRequested('Glass'));
      await settle();

      expect(logs.entries.map((e) => e.action), [
        'category.added',
        'category.deleted',
      ]);
      expect(logs.entries.first.summary, 'Added category "Glass".');
    });

    test('a failed action is not logged', () async {
      repository.failNext = true;
      bloc.add(const AdminAddCategoryRequested('Glass'));
      await settle();

      expect(logs.entries, isEmpty);
      expect(bloc.state.errorMessage, 'boom');
    });

    test('changing fees lists only what changed', () async {
      bloc.add(
        const AdminUpdateSettingsRequested(
          flatFee: 60,
          percentFee: 5,
          commissionThreshold: 999,
        ),
      );
      await settle();

      expect(logs.entries, hasLength(1));
      expect(logs.entries.single.category, AdminLogCategory.settings);
      expect(
        logs.entries.single.summary,
        'Changed platform fees: flat fee ₹50 → ₹60.',
      );
    });

    test('saving fees without changing anything is not logged', () async {
      bloc.add(
        const AdminUpdateSettingsRequested(
          flatFee: 50,
          percentFee: 5,
          commissionThreshold: 999,
        ),
      );
      await settle();
      expect(logs.entries, isEmpty);
    });

    test('suspending and reinstating a user names them', () async {
      bloc.add(
        const AdminSuspendUserRequested(
          'u1',
          3,
          reason: 'Policy violation',
          userLabel: 'Ravi (ravi@example.com)',
        ),
      );
      await settle();
      bloc.add(const AdminSuspendUserRequested('u1', 0));
      await settle();

      expect(
        logs.entries.first.summary,
        'Finally suspended user Ravi (ravi@example.com): Policy violation',
      );
      expect(
        logs.entries.last.summary,
        'Cleared warnings and reinstated user u1.',
      );
      expect(logs.entries.first.targetId, 'u1');
    });

    test('product decisions include the product and the reason', () async {
      bloc.add(
        const AdminProductReviewRequested(
          productId: 'p1',
          approve: false,
          reviewerName: 'Suhani',
          reviewerEmail: 's@example.com',
          rejectionReason: 'Blurry photos',
          productName: 'Clay Vase',
        ),
      );
      await settle();

      expect(
        logs.entries.single.summary,
        'Rejected product "Clay Vase". Reason: Blurry photos',
      );
      expect(logs.entries.single.action, 'product.rejected');
    });

    test('verifying and revoking a creator uses their name', () async {
      repository.profiles = [_creator('In-Process')];
      bloc.add(AdminLoadDataRequested());
      await settle();
      bloc.add(const AdminApproveCreatorRequested('c1'));
      await settle();
      repository.profiles = [_creator('Verified')];
      bloc.add(AdminLoadDataRequested());
      await settle();
      bloc.add(const AdminRejectCreatorRequested('c1', 'Documents expired'));
      await settle();

      expect(logs.entries.map((e) => e.action), [
        'creator.verified',
        'creator.revoked',
      ]);
      expect(
        logs.entries.first.summary,
        'Verified creator Asha Rao (Rao Pottery).',
      );
      expect(logs.entries.last.summary, contains('Documents expired'));
    });

    test('resetting categories logs how many defaults were applied', () async {
      bloc.add(AdminResetCategoriesRequested());
      await settle();
      expect(
        logs.entries.single.summary,
        'Reset categories to the 3 default categories.',
      );
    });
  });

  group('AdminLogsView', () {
    final superAdmin = UserEntity(
      uid: 'a1',
      email: 'adhirajjain364@gmail.com',
      name: 'Suhani',
      role: 'super_admin',
    );
    final manager = UserEntity(
      uid: 'm1',
      email: 'manager@example.com',
      name: 'Manu',
      role: 'manager',
    );

    final now = DateTime.now();
    final entries = [
      AdminLogEntry(
        id: '1',
        actorUid: 'a1',
        actorName: 'Suhani',
        actorEmail: '',
        actorRole: 'Super Admin',
        action: 'payout.released',
        category: AdminLogCategory.payout,
        summary: 'Released ₹1200 payout to Asha for order #AB12CD.',
        createdAt: now,
      ),
      AdminLogEntry(
        id: '2',
        actorUid: 'm1',
        actorName: 'Manu',
        actorEmail: '',
        actorRole: 'Manager',
        action: 'category.added',
        category: AdminLogCategory.category,
        summary: 'Added category "Glass".',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    Widget host(UserEntity user, Stream<List<AdminLogEntry>> logs) =>
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: _SignedInAuthBloc(user),
            child: Scaffold(body: AdminLogsView(logs: logs)),
          ),
        );

    testWidgets('shows entries grouped by day and filters them', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(superAdmin, Stream.value(entries)));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.textContaining('Released ₹1200 payout'), findsOneWidget);
      expect(find.textContaining('by Manu (Manager)'), findsOneWidget);

      // The category chips scroll sideways, so bring 'Payouts' fully into view.
      final chipRow = find.byType(ListView).first;
      await tester.dragUntilVisible(
        find.widgetWithText(ChoiceChip, 'Payouts'),
        chipRow,
        const Offset(-100, 0),
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Payouts'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Payouts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Released ₹1200 payout'), findsOneWidget);
      expect(find.textContaining('Added category'), findsNothing);

      await tester.drag(chipRow, const Offset(800, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.enterText(find.byType(TextField), 'manu');
      await tester.pumpAndSettle();
      expect(find.textContaining('Added category'), findsOneWidget);
      expect(find.textContaining('Released'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nothing matches this');
      await tester.pumpAndSettle();
      expect(find.text('No matching activity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows an empty state when nothing has been logged', (
      tester,
    ) async {
      await tester.pumpWidget(host(superAdmin, Stream.value(const [])));
      await tester.pumpAndSettle();
      expect(find.text('No activity yet'), findsOneWidget);
    });

    testWidgets('managers see a restriction notice, not the log', (
      tester,
    ) async {
      await tester.pumpWidget(host(manager, Stream.value(entries)));
      await tester.pumpAndSettle();

      expect(
        find.text('Activity logs are restricted to super admins'),
        findsOneWidget,
      );
      expect(find.textContaining('Released'), findsNothing);
    });
  });
}
