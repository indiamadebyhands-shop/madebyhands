import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/domain/repositories/auth_repository.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/buyer/data/mock_buyer_repository.dart';
import 'package:madebyhands/features/buyer/presentation/bloc/buyer_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/pages/buyer_dashboard_page.dart';

void main() {
  runApp(const BuyerPreviewApp());
}

class BuyerPreviewApp extends StatelessWidget {
  const BuyerPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    final buyer = UserEntity(
      uid: 'buyer-preview',
      email: 'suhani@buyer.preview',
      name: 'Suhani',
      role: 'buyer',
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MadeByHands Buyer Preview',
      theme: AppTheme.lightThemeMode,
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(authRepository: FakeAuthRepository()),
          ),
          BlocProvider(
            create: (_) => BuyerBloc(repository: MockBuyerRepository()),
          ),
        ],
        child: BuyerDashboardPage(user: buyer, onLogout: () {}),
      ),
    );
  }
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, void>> signOut() async => throw UnimplementedError();
  @override
  Future<Either<Failure, UserEntity>> updateProfile({
    required String uid,
    required String name,
    required String phone,
  }) async => throw UnimplementedError();
  @override
  Future<Either<Failure, void>> deleteAccount(String uid, String reason) async =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, UserEntity>> signInWithGoogle() async =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, UserEntity>> signInAsTestBuyer() async =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, UserEntity>> signUpWithRole({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String role,
  }) async => throw UnimplementedError();
}
