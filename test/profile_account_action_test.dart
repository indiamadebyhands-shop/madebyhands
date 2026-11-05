import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/buyer/presentation/views/profile_tab.dart';

void main() {
  final dualRoleUser = UserEntity(
    uid: 'user-1',
    email: 'user@example.com',
    name: 'User',
    role: 'buyer',
    roles: const ['buyer', 'creator'],
  );

  Widget profile({required bool hasCompletedCreatorProfile}) => MaterialApp(
    home: Scaffold(
      body: ProfileTab(
        user: dualRoleUser,
        onOrders: () {},
        onAddresses: () {},
        onSupport: () {},
        onAccount: () {},
        onCreatorMode: () {},
        hasCompletedCreatorProfile: hasCompletedCreatorProfile,
        onLogout: () {},
      ),
    ),
  );

  testWidgets('unfinished creator setup offers profile creation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(profile(hasCompletedCreatorProfile: false));

    expect(find.text('Make a creator account'), findsOneWidget);
    expect(find.text('Switch accounts'), findsNothing);
  });

  testWidgets('completed creator profile offers account switching', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(profile(hasCompletedCreatorProfile: true));

    expect(find.text('Switch accounts'), findsOneWidget);
    expect(find.text('Make a creator account'), findsNothing);
  });
}
