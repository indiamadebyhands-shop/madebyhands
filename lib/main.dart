import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:madebyhands/core/services/notification_messaging_service.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:madebyhands/features/admin/presentation/bloc/admin_cubit.dart';
import 'package:madebyhands/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/auth/presentation/pages/role_selection_page.dart';
import 'package:madebyhands/features/auth/presentation/pages/welcome_screen.dart';
import 'package:madebyhands/features/buyer/presentation/bloc/buyer_bloc.dart';
import 'package:madebyhands/features/buyer/presentation/pages/buyer_dashboard_page.dart';
import 'package:madebyhands/features/creator/presentation/bloc/creator_bloc.dart';
import 'package:madebyhands/features/creator/presentation/pages/creator_flow_wrapper.dart';
import 'package:madebyhands/init_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => serviceLocator<AuthBloc>()..add(AuthIsUserLoggedIn()),
        ),
        BlocProvider(create: (_) => serviceLocator<CreatorBloc>()),
        BlocProvider(create: (_) => serviceLocator<BuyerBloc>()),
        BlocProvider(create: (_) => serviceLocator<AdminCubit>()),
        BlocProvider(create: (_) => serviceLocator<AdminBloc>()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _navigatorKey = GlobalKey<NavigatorState>();

  void _showError(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MadeByHands',
        theme: AppTheme.lightThemeMode,
        scaffoldMessengerKey: _messengerKey,
        navigatorKey: _navigatorKey,
        home: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthActionFailed) _showError(state.message);
            if (state is AuthFailure && !state.canRetrySession) {
              _showError(state.message);
            }
            if (state is AuthInitial) {
              // Close any pages opened by the previous session.
              _navigatorKey.currentState?.popUntil((route) => route.isFirst);
              // Stop listening to the previous user's data after sign-out.
              context.read<BuyerBloc>().add(BuyerSessionEnded());
              context.read<CreatorBloc>().add(CreatorSessionEnded());
              context.read<AdminCubit>().changePage(0);
            }
          },
          // A failed one-off action keeps the current screen on display.
          buildWhen: (previous, current) => current is! AuthActionFailed,
          builder: (context, state) => switch (state) {
            AuthLoading() => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            AuthSuccess(:final user) => _homeFor(context, user),
            AuthNeedsRoleSelection(:final tempUser) => RoleSelectionPage(
              tempUser: tempUser,
            ),
            AuthFailure(:final message, :final canRetrySession)
                when canRetrySession =>
              _SessionErrorScreen(message: message),
            _ => const WelcomeScreen(),
          },
        ),
      ),
    );
  }

  Widget _homeFor(BuildContext context, UserEntity user) {
    NotificationMessagingService.instance.initialize(
      userId: user.uid,
      onNotificationTap: (data) {
        final category = data['category'] as String?;
        if (user.isAdminOrManager) {
          int? section;
          if (category == 'creator_verification' || category == 'verification') {
            section = 1;
          } else if (category == 'product_approval' || category == 'product') {
            section = 2;
          } else if (category == 'order_rejected' || category == 'order') {
            section = 4;
          } else if (category == 'support_ticket' ||
              category == 'support' ||
              category == 'support_reply' ||
              category == 'support_resolved') {
            section = 6;
          }
          if (section != null) {
            context.read<AdminCubit>().changePage(section);
          }
        }
      },
    );

    if (user.isSuspended) return const _SuspendedScreen();
    if (user.isAdminOrManager) return AdminDashboardPage(key: ValueKey(user.uid));
    if (user.isCreator) {
      return CreatorFlowWrapper(key: ValueKey(user.uid), user: user);
    }
    return BuyerDashboardPage(
      key: ValueKey(user.uid),
      user: user,
      onLogout: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
    );
  }
}

class _SessionErrorScreen extends StatelessWidget {
  final String message;

  const _SessionErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 56, color: AppColors.mutedText),
                const SizedBox(height: 16),
                const Text(
                  'We could not load your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.mutedText),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.read<AuthBloc>().add(AuthIsUserLoggedIn()),
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuspendedScreen extends StatelessWidget {
  const _SuspendedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text(
                  'Your account is suspended',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please contact MadeByHands support if you believe this is a mistake.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText),
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
