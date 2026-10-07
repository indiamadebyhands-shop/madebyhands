import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madebyhands/core/constants/feature_flags.dart';
import 'package:madebyhands/features/auth/domain/repositories/auth_repository.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/auth/presentation/pages/welcome_screen.dart';

class _NoAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
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
