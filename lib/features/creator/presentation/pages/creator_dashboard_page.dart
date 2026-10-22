import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_notification.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';
import 'package:madebyhands/features/creator/domain/repositories/creator_repository.dart';
import 'package:madebyhands/features/creator/presentation/bloc/creator_bloc.dart';
import 'package:madebyhands/features/creator/presentation/pages/creator_notifications_page.dart';
import 'package:madebyhands/features/creator/presentation/views/creator_earnings_view.dart';
import 'package:madebyhands/features/creator/presentation/views/creator_home_view.dart';
import 'package:madebyhands/features/creator/presentation/views/creator_orders_view.dart';
import 'package:madebyhands/features/creator/presentation/views/creator_products_view.dart';
import 'package:madebyhands/features/creator/presentation/views/creator_profile_view.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/support/presentation/pages/support_center_page.dart';
import 'package:madebyhands/init_dependencies.dart';

class CreatorDashboardPage extends StatefulWidget {
  final UserEntity user;

  const CreatorDashboardPage({super.key, required this.user});

  @override
  State<CreatorDashboardPage> createState() => _CreatorDashboardPageState();
}

class _CreatorDashboardPageState extends State<CreatorDashboardPage> {
  int _selectedIndex = 0;
  final Set<int> _visited = {0};
  String? _shownWarningKey;
  bool _warningDialogOpen = false;
  late int _moderationLevel;
  late String _moderationReason;
  late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
  _moderationSubscription;

  static const List<String> _titles = [
    'Artisan Dashboard',
    'My Products',
    'Manage Orders',
    'Earnings',
    'My Profile',
  ];

  @override
  void initState() {
    super.initState();
    _moderationLevel = widget.user.creatorModerationLevel;
    _moderationReason = widget.user.creatorModerationReason;
    _moderationSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .snapshots()
        .listen(_onModerationSnapshot);
  }

  void _onModerationSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) return;
    final data = snapshot.data();
    final level =
        (data?['creatorModerationLevel'] as num?)?.toInt() ??
        widget.user.creatorModerationLevel;
    final reason =
        data?['creatorModerationReason'] as String? ??
        widget.user.creatorModerationReason;
    if (level != _moderationLevel || reason != _moderationReason) {
      setState(() {
        _moderationLevel = level;
        _moderationReason = reason;
      });
    }
    _scheduleWarningDialog(
      level: level,
      reason: reason,
      issuedAt: data?['creatorModerationIssuedAt'],
    );
  }

  @override
  void dispose() {
    _moderationSubscription.cancel();
    super.dispose();
  }

  void _select(int index) {
    setState(() {
      _selectedIndex = index;
      _visited.add(index);
    });
  }

  Widget _view(int index, CreatorProfile profile, int moderationLevel) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => CreatorHomeView(profile: profile),
      1 => CreatorProductsView(
        profile: profile,
        canAddProducts: moderationLevel < 2,
      ),
      2 => CreatorOrdersView(profile: profile),
      3 => CreatorEarningsView(creatorId: profile.uid),
      _ => CreatorProfileView(profile: profile, user: widget.user),
    };
  }

  void _scheduleWarningDialog({
    required int level,
    required String reason,
    Object? issuedAt,
  }) {
    if (level < 1 || level > 2) {
      _shownWarningKey = null;
      return;
    }
    final key = '$level|$reason|$issuedAt';
    if (_shownWarningKey == key) return;
    _shownWarningKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showModerationWarning(level: level, reason: reason);
    });
  }

  Future<void> _showModerationWarning({
    required int level,
    required String reason,
  }) async {
    if (_warningDialogOpen || !mounted) return;
    _warningDialogOpen = true;
    final warningColor = level == 1
        ? Colors.amber.shade800
        : Colors.red.shade700;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFFFAF6EE),
          titlePadding: const EdgeInsets.fromLTRB(24, 18, 8, 0),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: warningColor, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  level == 1 ? 'First warning' : 'Second warning',
                  style: TextStyle(
                    color: warningColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reason',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                reason.trim().isEmpty ? 'No reason provided.' : reason.trim(),
              ),
              const SizedBox(height: 16),
              Text(
                level == 1
                    ? 'Please resolve this issue within 24 hours. The next warning may restrict your storefront.'
                    : 'Please resolve this issue within 24 hours. Your storefront and products are hidden, and you cannot add new products.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    } finally {
      _warningDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreatorBloc, CreatorState>(
      // One place surfaces the outcome of every creator write.
      listenWhen: (previous, current) =>
          previous.actionId != current.actionId &&
          current.actionStatus != CreatorActionStatus.inProgress &&
          current.action != CreatorAction.saveProfile &&
          current.action != CreatorAction.submitVerification &&
          current.action != CreatorAction.saveProduct &&
          current.action != CreatorAction.saveBankAccount,
      listener: (context, state) {
        final message = state.actionMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: state.actionStatus == CreatorActionStatus.failure
                ? Colors.red.shade700
                : null,
          ),
        );
      },
      child: BlocSelector<CreatorBloc, CreatorState, CreatorProfile?>(
        selector: (state) => state.profile,
        builder: (context, profile) {
          if (profile == null) {
            return const Scaffold(
              backgroundColor: Color(0xFFFAF6EE),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF8B261D)),
              ),
            );
          }
          return BuyerBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  _titles[_selectedIndex],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B261D),
                  ),
                ),
                iconTheme: const IconThemeData(color: Color(0xFF8B261D)),
                centerTitle: true,
                leading: _moderationLevel > 0 && _moderationLevel < 3
                    ? IconButton(
                        tooltip: 'View account warning',
                        onPressed: () => _showModerationWarning(
                          level: _moderationLevel,
                          reason: _moderationReason,
                        ),
                        icon: Icon(
                          Icons.warning_amber_rounded,
                          color: _moderationLevel == 1
                              ? Colors.amber.shade800
                              : Colors.red.shade700,
                        ),
                      )
                    : null,
                actions: [
                  _NotificationButton(creatorUid: profile.uid),
                  IconButton(
                    tooltip: 'Help & support',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SupportCenterPage(
                          user: widget.user,
                          repository: serviceLocator(),
                        ),
                      ),
                    ),
                    icon: const Icon(
                      Icons.help_outline,
                      color: Color(0xFF8B261D),
                    ),
                  ),
                ],
              ),
              body: IndexedStack(
                index: _selectedIndex,
                children: [
                  for (var i = 0; i < _titles.length; i++)
                    _view(i, profile, _moderationLevel),
                ],
              ),
              bottomNavigationBar: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF6EE),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      height: 78,
                      backgroundColor: const Color(0xFFFAF6EE),
                      indicatorColor: const Color(0xFFF2DEDD),
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        return IconThemeData(
                          color: states.contains(WidgetState.selected)
                              ? const Color(0xFF8B261D)
                              : const Color(0xFF8B261D).withValues(alpha: 0.55),
                        );
                      }),
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        return GoogleFonts.montserrat(
                          fontSize: 11.5,
                          fontWeight: states.contains(WidgetState.selected)
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: states.contains(WidgetState.selected)
                              ? const Color(0xFF8B261D)
                              : const Color(0xFF8B261D).withValues(alpha: 0.6),
                        );
                      }),
                    ),
                    child: NavigationBar(
                      height: 78,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _select,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: 'Dashboard',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.inventory_2_outlined),
                          selectedIcon: Icon(Icons.inventory_2),
                          label: 'Products',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.shopping_bag_outlined),
                          selectedIcon: Icon(Icons.shopping_bag),
                          label: 'Orders',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.payments_outlined),
                          selectedIcon: Icon(Icons.payments),
                          label: 'Earnings',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: 'Profile',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationButton extends StatefulWidget {
  final String creatorUid;

  const _NotificationButton({required this.creatorUid});

  @override
  State<_NotificationButton> createState() => _NotificationButtonState();
}

class _NotificationButtonState extends State<_NotificationButton> {
  late final Stream<List<CreatorNotification>> _notifications =
      serviceLocator<CreatorRepository>().watchNotifications(widget.creatorUid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CreatorNotification>>(
      stream: _notifications,
      builder: (context, snapshot) {
        final unread = snapshot.data?.where((n) => !n.isRead).length ?? 0;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  CreatorNotificationsPage(creatorUid: widget.creatorUid),
            ),
          ),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            backgroundColor: Colors.redAccent,
            child: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF8B261D),
            ),
          ),
        );
      },
    );
  }
}
