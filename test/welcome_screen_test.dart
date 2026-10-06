import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:madebyhands/core/constants/feature_flags.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/domain/repositories/auth_repository.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/auth/presentation/pages/welcome_screen.dart';

class _NoAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers the test-buyer sign-in and nothing else.
class _TestBuyerAuthRepository implements AuthRepository {
  _TestBuyerAuthRepository({this.error});

  final String? error;
  int testBuyerSignIns = 0;

  @override
  Future<Either<Failure, UserEntity>> signInAsTestBuyer() async {
    testBuyerSignIns++;
    if (error != null) return left(Failure(error!));
    return right(
      UserEntity(uid: 'guest-1', email: '', name: 'Test Buyer', role: 'buyer'),
    );
  }

  /// Nobody is signed in when the app starts.
  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async =>
      left(SignedOutFailure());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps the welcome screen and swipes to its last onboarding page.
Future<void> _openLastPage(
  WidgetTester tester,
  AuthBloc bloc, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  // The onboarding slides load Unsplash photos, which tests cannot fetch.
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is NetworkImageLoadException) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);

  await tester.pumpWidget(
    BlocProvider.value(
      value: bloc,
      child: const MaterialApp(home: WelcomeScreen()),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  for (var i = 0; i < 6; i++) {
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  group('test-buyer sign-in', () {
    test('signs straight in as a buyer, with no role selection', () async {
      final repository = _TestBuyerAuthRepository();
      final bloc = AuthBloc(authRepository: repository);
      addTearDown(bloc.close);

      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);

      bloc.add(AuthTestBuyerSignInRequested());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      if (!kTestBuyerLoginEnabled) {
        // Switched off: the event must do nothing at all.
        expect(repository.testBuyerSignIns, 0);
        expect(states, isEmpty);
        return;
      }
      expect(repository.testBuyerSignIns, 1);
      expect(states.first, isA<AuthLoading>());
      final signedIn = states.last as AuthSuccess;
      expect(signedIn.user.role, 'buyer');
      expect(signedIn.user.isAdminOrManager, isFalse);
      expect(signedIn.user.isCreator, isFalse);
    });

    test('a failure returns to the welcome screen with the reason', () async {
      if (!kTestBuyerLoginEnabled) return;
      final bloc = AuthBloc(
        authRepository: _TestBuyerAuthRepository(error: 'Not switched on.'),
      );
      addTearDown(bloc.close);

      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);

      bloc.add(AuthTestBuyerSignInRequested());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final failure = states.last as AuthFailure;
      expect(failure.message, 'Not switched on.');
      expect(failure.canRetrySession, isFalse);
    });

    testWidgets('the button follows its flag and fits a small phone', (
      tester,
    ) async {
      final repository = _TestBuyerAuthRepository();
      // As in the app: the session check finishes (signed out) before the
      // welcome screen's buttons become active.
      final bloc = AuthBloc(authRepository: repository)
        ..add(AuthIsUserLoggedIn());
      addTearDown(bloc.close);

      await _openLastPage(tester, bloc, size: const Size(360, 640));
      expect(tester.takeException(), isNull);

      final button = find.text('Continue as test buyer');
      expect(button, kTestBuyerLoginEnabled ? findsOneWidget : findsNothing);
      if (!kTestBuyerLoginEnabled) return;

      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.testBuyerSignIns, 1);
      expect(bloc.state, isA<AuthSuccess>());
    });
  });

  testWidgets(
    'last page follows the Google sign-in flag and keeps the policy links',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // The onboarding slides load Unsplash photos, which tests cannot fetch.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception is NetworkImageLoadException) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        BlocProvider(
          create: (_) => AuthBloc(authRepository: _NoAuthRepository()),
          child: const MaterialApp(home: WelcomeScreen()),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Swipe to the last onboarding page.
      for (var i = 0; i < 6; i++) {
        await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }

      expect(
        find.text('Continue with Google'),
        kGoogleSignInEnabled ? findsOneWidget : findsNothing,
      );
      expect(
        find.textContaining('Sign-in is temporarily unavailable'),
        kGoogleSignInEnabled ? findsNothing : findsOneWidget,
      );
      expect(find.text('Terms and Conditions'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    },
  );
}
