import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:madebyhands/features/admin/presentation/bloc/admin_cubit.dart';
import 'package:madebyhands/features/admin/presentation/views/admin_logs_view.dart';
import 'package:madebyhands/features/admin/presentation/views/admin_settings_view.dart';
import 'package:madebyhands/features/admin/presentation/views/category_management_view.dart';
import 'package:madebyhands/features/admin/presentation/views/finance_view.dart';
import 'package:madebyhands/features/admin/presentation/views/order_management_view.dart';
import 'package:madebyhands/features/admin/presentation/views/overview_view.dart';
import 'package:madebyhands/features/admin/presentation/views/product_approval_view.dart';
import 'package:madebyhands/features/admin/presentation/views/support_tickets_view.dart';
import 'package:madebyhands/features/admin/presentation/views/user_management_view.dart';
import 'package:madebyhands/features/admin/presentation/views/verification_view.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';

class _AdminSection {
  final String title;
  final String menuLabel;
  final IconData icon;
  final IconData selectedIcon;
  final Widget view;
  final bool superAdminOnly;

  const _AdminSection({
    required this.title,
    required this.menuLabel,
    required this.icon,
    required this.selectedIcon,
    required this.view,
    this.superAdminOnly = false,
  });
}

const _sections = <_AdminSection>[
  _AdminSection(
    title: 'Overview',
    menuLabel: 'Overview',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    view: OverviewView(),
  ),
  _AdminSection(
    title: 'Creator Verifications',
    menuLabel: 'Verifications',
    icon: Icons.verified_user_outlined,
    selectedIcon: Icons.verified_user,
    view: VerificationView(),
  ),
  _AdminSection(
    title: 'Product Approvals',
    menuLabel: 'Products',
    icon: Icons.shopping_bag_outlined,
    selectedIcon: Icons.shopping_bag,
    view: ProductApprovalView(),
  ),
  _AdminSection(
    title: 'Categories',
    menuLabel: 'Categories',
    icon: Icons.category_outlined,
    selectedIcon: Icons.category,
    view: CategoryManagementView(),
  ),
  _AdminSection(
    title: 'Orders',
    menuLabel: 'Orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    view: OrderManagementView(),
  ),
  _AdminSection(
    title: 'Users',
    menuLabel: 'Users',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    view: UserManagementView(),
  ),
  _AdminSection(
    title: 'Support Tickets',
    menuLabel: 'Support',
    icon: Icons.support_agent_outlined,
    selectedIcon: Icons.support_agent,
    view: SupportTicketsView(),
  ),
  _AdminSection(
    title: 'Payouts & Finance',
    menuLabel: 'Payouts & Finance',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    view: FinanceView(),
    superAdminOnly: true,
  ),
  _AdminSection(
    title: 'Admin Settings',
    menuLabel: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    view: AdminSettingsView(),
  ),
  // Appended after Settings so the indices the notification bell navigates
  // to (1, 2, 4, 6) stay valid.
  _AdminSection(
    title: 'Activity Logs',
    menuLabel: 'Activity Logs',
    icon: Icons.history,
    selectedIcon: Icons.history,
    view: AdminLogsView(),
    superAdminOnly: true,
  ),
];

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  /// Sections are built the first time they are opened, so the panel does
  /// not subscribe to every collection up front.
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    context.read<AdminBloc>().add(AdminLoadDataRequested());
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is AuthSuccess ? authState.user : null;
    final isSuperAdmin = user?.isSuperAdmin ?? false;

    return BlocListener<AdminBloc, AdminState>(
      listenWhen: (previous, current) =>
          current.errorMessage != null || current.notice != null,
      listener: (context, state) {
        if (state.errorMessage != null) {
          _showSnack(state.errorMessage!, isError: true);
        } else if (state.notice != null) {
          _showSnack(state.notice!);
        }
      },
      child: BlocBuilder<AdminCubit, int>(
        builder: (context, rawIndex) {
          final selectedIndex = rawIndex.clamp(0, _sections.length - 1);
          _visited.add(selectedIndex);
          return Scaffold(
            appBar: AppBar(
              title: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _sections[selectedIndex].title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              actions: [
                const _AdminNotificationBell(),
                IconButton(
                  tooltip: 'Log out',
                  onPressed: () =>
                      context.read<AuthBloc>().add(AuthLogoutRequested()),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            drawer: _AdminDrawer(
              user: user,
              isSuperAdmin: isSuperAdmin,
              selectedIndex: selectedIndex,
            ),
            body: IndexedStack(
              index: selectedIndex,
              children: [
                for (var index = 0; index < _sections.length; index++)
                  _visited.contains(index)
                      ? _sections[index].view
                      : const SizedBox.shrink(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final UserEntity? user;
  final bool isSuperAdmin;
  final int selectedIndex;

  const _AdminDrawer({
    required this.user,
    required this.isSuperAdmin,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    size: 44,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'MADEBYHANDS ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white70),
                    ),
                    child: Text(
                      isSuperAdmin ? 'SUPER ADMIN' : 'MANAGER',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < _sections.length; index++)
                  _buildTile(context, index),
              ],
            ),
          ),
          const Divider(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Signed in as ${user?.name.isNotEmpty == true ? user!.name : 'Admin'} (${user?.roleDisplay ?? 'Admin'})',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, int index) {
    final section = _sections[index];
    final isSelected = selectedIndex == index;
    final isRestricted = section.superAdminOnly && !isSuperAdmin;
    return ListTile(
      leading: Icon(
        isRestricted
            ? Icons.lock_outline
            : isSelected
            ? section.selectedIcon
            : section.icon,
        color: isRestricted
            ? Colors.orange.shade700
            : (isSelected ? AppColors.primary : AppColors.mutedText),
      ),
      title: Text(
        section.menuLabel,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.text,
        ),
      ),
      trailing: isRestricted
          ? Text(
              'SUPER ADMIN',
              style: TextStyle(
                fontSize: 9,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
      selected: isSelected,
      onTap: () {
        context.read<AdminCubit>().changePage(index);
        Navigator.pop(context);
      },
    );
  }
}

/// Unread admin alerts (new tickets, verification and product submissions).
class _AdminNotificationBell extends StatefulWidget {
  const _AdminNotificationBell();

  @override
  State<_AdminNotificationBell> createState() => _AdminNotificationBellState();
}

class _AdminNotificationBellState extends State<_AdminNotificationBell> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _alerts =
      FirebaseFirestore.instance
          .collection('notifications')
          .where('type', isEqualTo: 'admin')
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _alerts,
      builder: (context, snapshot) {
        final notifications = <Map<String, dynamic>>[
          for (final doc in snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            {'id': doc.id, ...doc.data()},
        ]..sort((a, b) {
            final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });
        final unreadCount = notifications
            .where((item) => item['isRead'] != true)
            .length;
        return IconButton(
          tooltip: 'Admin notifications',
          onPressed: () => _showNotifications(context, notifications),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            backgroundColor: Colors.redAccent,
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }

  static int? _sectionFor(String category) => switch (category) {
    'creator_verification' || 'verification' => 1,
    'product_approval' || 'product' => 2,
    'order_rejected' || 'order' => 4,
    'support_ticket' || 'support' || 'support_reply' || 'support_resolved' => 6,
    _ => null,
  };

  static IconData _iconFor(String category) => switch (_sectionFor(category)) {
    1 => Icons.verified_user_outlined,
    2 => Icons.inventory_2_outlined,
    4 => Icons.receipt_long_outlined,
    6 => Icons.support_agent_outlined,
    _ => Icons.info_outline,
  };

  void _showNotifications(
    BuildContext context,
    List<Map<String, dynamic>> notifications,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) => SizedBox(
        height: MediaQuery.sizeOf(modalContext).height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Admin notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'No notifications at the moment.',
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      )
                    : ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          final category = item['category'] as String? ?? 'general';
                          final isRead = item['isRead'] == true;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: isRead
                                ? AppColors.surface
                                : AppColors.primary.withValues(alpha: 0.08),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                child: Icon(
                                  _iconFor(category),
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item['title'] as String? ?? 'System alert',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(item['message'] as String? ?? ''),
                              onTap: () {
                                if (!isRead) {
                                  FirebaseFirestore.instance
                                      .collection('notifications')
                                      .doc(item['id'] as String)
                                      .update({'isRead': true})
                                      .catchError((_) {});
                                }
                                Navigator.pop(modalContext);
                                final section = _sectionFor(category);
                                if (section != null) {
                                  context.read<AdminCubit>().changePage(section);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
