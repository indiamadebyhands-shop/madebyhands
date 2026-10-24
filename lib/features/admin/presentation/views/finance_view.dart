import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/core/services/notification_messaging_service.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/admin/domain/entities/admin_log_entry.dart';
import 'package:madebyhands/features/admin/domain/repositories/admin_log_repository.dart';
import 'package:madebyhands/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:madebyhands/features/admin/presentation/widgets/small_stat.dart';
import 'package:madebyhands/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:madebyhands/features/orders/domain/order_status.dart';
import 'package:madebyhands/init_dependencies.dart';

/// Super-admin finance: platform revenue and creator payout releases.
///
/// Payouts are released manually (bank/UPI transfer outside the app) and
/// then recorded here. Only delivered, paid orders are releasable.
class FinanceView extends StatelessWidget {
  const FinanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = context.select<AuthBloc, bool>((bloc) {
      final state = bloc.state;
      return state is AuthSuccess && state.user.isSuperAdmin;
    });
    if (!isSuperAdmin) return const _RestrictedNotice();
    return const _FinanceBody();
  }
}

class _RestrictedNotice extends StatelessWidget {
  const _RestrictedNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 56, color: Colors.orange.shade800),
            const SizedBox(height: 20),
            const Text(
              'Finance is restricted to super admins',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Platform balances, fees and creator payouts can only be managed by a super admin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedText, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutOrder {
  final String id;
  final String creatorId;
  final String creatorName;
  final int amount;
  final String status;
  final DateTime createdAt;
  final DateTime? releasedAt;

  const _PayoutOrder({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.releasedAt,
  });

  String get shortId =>
      id.length > 6 ? id.substring(id.length - 6).toUpperCase() : id.toUpperCase();
}

class _FinanceSummary {
  int revenue = 0;
  int settled = 0;
  final List<_PayoutOrder> awaiting = [];
  final List<_PayoutOrder> releasable = [];
  final List<_PayoutOrder> released = [];

  _FinanceSummary(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    for (final doc in docs) {
      final data = doc.data();
      if (data['isSample'] == true) continue;
      final paymentStatus = (data['paymentStatus'] as String? ?? 'paid').toLowerCase();
      if (paymentStatus != 'paid') continue;
      final status = data['status'] as String? ?? '';
      final payoutStatus = (data['payoutStatus'] as String? ?? 'pending').toLowerCase();
      if (OrderStatus.isRejectedOrCancelled(status) || payoutStatus == 'cancelled') continue;

      final subtotal = (data['subtotal'] as num?)?.round() ?? 0;
      final flatFee = (data['flatFee'] as num?)?.round() ?? 0;
      revenue += (data['platformFee'] as num?)?.round() ?? flatFee;

      final order = _PayoutOrder(
        id: doc.id,
        creatorId: data['creatorId'] as String? ?? '',
        creatorName: data['creatorName'] as String? ?? 'Creator',
        amount: (data['creatorNetAmount'] as num?)?.round() ?? subtotal,
        status: status,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970),
        releasedAt: (data['payoutReleasedAt'] as Timestamp?)?.toDate(),
      );
      if (payoutStatus == 'paid' || payoutStatus == 'released') {
        settled += order.amount;
        released.add(order);
      } else if (OrderStatus.isDelivered(status)) {
        releasable.add(order);
      } else {
        awaiting.add(order);
      }
    }
    releasable.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    awaiting.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    released.sort(
      (a, b) => (b.releasedAt ?? b.createdAt).compareTo(a.releasedAt ?? a.createdAt),
    );
  }
}

class _FinanceBody extends StatefulWidget {
  const _FinanceBody();

  @override
  State<_FinanceBody> createState() => _FinanceBodyState();
}

class _FinanceBodyState extends State<_FinanceBody> {
  final Stream<QuerySnapshot<Map<String, dynamic>>> _orders =
      FirebaseFirestore.instance.collection('orders').snapshots();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const TabBar(
          tabs: [
            Tab(text: 'Pending payouts'),
            Tab(text: 'Payout history'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.mutedText,
          indicatorColor: AppColors.primary,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _orders,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load financial data: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            final summary = _FinanceSummary(snapshot.data!.docs);
            return TabBarView(
              children: [
                _PendingTab(summary: summary),
                _HistoryTab(summary: summary),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PendingTab extends StatelessWidget {
  final _FinanceSummary summary;

  const _PendingTab({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Platform revenue', style: TextStyle(color: Colors.white70)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '₹${summary.revenue}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              BlocBuilder<AdminBloc, AdminState>(
                buildWhen: (previous, current) =>
                    previous.flatFee != current.flatFee ||
                    previous.percentFee != current.percentFee,
                builder: (context, state) => Wrap(
                  spacing: 32,
                  runSpacing: 12,
                  children: [
                    SmallStat(label: 'Flat fee', value: '₹${state.flatFee.round()}'),
                    SmallStat(
                      label: 'Commission (> ₹999)',
                      value: '${state.percentFee.toStringAsFixed(state.percentFee % 1 == 0 ? 0 : 1)}%',
                    ),
                    SmallStat(
                      label: 'Awaiting delivery',
                      value: '${summary.awaiting.length} orders',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Ready to release',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${summary.releasable.length} delivered',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Creator payouts become releasable once the order is delivered.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (summary.releasable.isEmpty)
          const _EmptyBox(message: 'No payouts waiting to be released.')
        else
          for (final order in summary.releasable)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.creatorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Order #${order.shortId} · ${DateFormat('dd MMM yyyy').format(order.createdAt)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${order.amount}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FilledButton(
                          onPressed: () => _showReleaseSheet(context, order),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 34),
                          ),
                          child: const Text('Release', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Awaiting delivery',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '₹${summary.awaiting.fold<int>(0, (total, order) => total + order.amount)} owed',
              style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Paid orders still being fulfilled. They move to "Ready to release" once delivered.',
          style: TextStyle(color: AppColors.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (summary.awaiting.isEmpty)
          const _EmptyBox(message: 'No paid orders in fulfilment.')
        else
          for (final order in summary.awaiting)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  order.creatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Order #${order.shortId} · ${OrderStatus.label(order.status)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '₹${order.amount}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final _FinanceSummary summary;

  const _HistoryTab({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade800,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total paid to creators', style: TextStyle(color: Colors.white70)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '₹${summary.settled}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${summary.released.length} payout(s) released',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (summary.released.isEmpty)
          const _EmptyBox(message: 'No payouts released yet.')
        else
          for (final order in summary.released)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.15),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 22),
                ),
                title: Text(
                  order.creatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Order #${order.shortId}'
                  '${order.releasedAt == null ? '' : ' · Released ${DateFormat('dd MMM yyyy').format(order.releasedAt!)}'}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '₹${order.amount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String message;

  const _EmptyBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.mutedText)),
    );
  }
}

Future<void> _showReleaseSheet(BuildContext context, _PayoutOrder order) async {
  Map<String, dynamic>? bank;
  String? loadError;
  if (order.creatorId.isNotEmpty) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('creator_bank_accounts')
          .doc(order.creatorId)
          .get();
      bank = doc.data();
    } catch (error) {
      loadError = friendlyErrorMessage(error);
    }
  }
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);

  Widget detail(String label, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            tooltip: 'Copy $label',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              messenger.showSnackBar(SnackBar(content: Text('$label copied.')));
            },
          ),
        ],
      ),
    );
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Release creator payout',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.creatorName} · Order #${order.shortId}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '₹${order.amount}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          if (loadError != null)
            Text('Could not load payout details: $loadError',
                style: const TextStyle(color: Colors.redAccent))
          else if (bank == null)
            const Text(
              'This creator has not added payout details yet. Ask them to add bank details in their profile before releasing.',
              style: TextStyle(color: Colors.redAccent),
            )
          else ...[
            detail('Account holder', bank['accountHolderName'] as String?),
            detail('Account no.', bank['accountNumber'] as String?),
            detail('Account type', bank['accountType'] as String?),
            detail('IFSC', bank['ifscCode'] as String?),
            detail('Bank', bank['bankName'] as String?),
            detail('Branch', bank['branchName'] as String?),
            detail('UPI ID', bank['upiId'] as String?),
            detail('PAN', bank['panNumber'] as String?),
          ],
          const SizedBox(height: 12),
          const Text(
            'Transfer the amount using these details, then confirm below to record the payout.',
            style: TextStyle(fontSize: 12, color: AppColors.mutedText),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: bank == null
                  ? null
                  : () async {
                      Navigator.pop(sheetContext);
                      try {
                        final batch = FirebaseFirestore.instance.batch();
                        batch.update(
                          FirebaseFirestore.instance.collection('orders').doc(order.id),
                          {
                            'payoutStatus': 'paid',
                            'payoutReleasedAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                        );
                        if (order.creatorId.isNotEmpty) {
                          batch.set(
                            FirebaseFirestore.instance.collection('notifications').doc(),
                            {
                              'creatorUid': order.creatorId,
                              'title': 'Payout released',
                              'message':
                                  '₹${order.amount} for Order #${order.shortId} has been paid out to your account.',
                              'type': 'payout',
                              'targetId': order.id,
                              'createdAt': FieldValue.serverTimestamp(),
                              'isRead': false,
                            },
                          );
                        }
                        await batch.commit();
                        if (order.creatorId.isNotEmpty) {
                          NotificationMessagingService.sendPushNotification(
                            targetUserId: order.creatorId,
                            title: 'Payout released',
                            message:
                                '₹${order.amount} for Order #${order.shortId} has been paid out to your account.',
                            category: 'payout',
                            targetId: order.id,
                          );
                        }
                        await serviceLocator<AdminLogRepository>().log(
                          category: AdminLogCategory.payout,
                          action: 'payout.released',
                          summary:
                              'Released ₹${order.amount} payout to ${order.creatorName} for order #${order.shortId}.',
                          targetId: order.id,
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Payout of ₹${order.amount} recorded for ${order.creatorName}.',
                            ),
                          ),
                        );
                      } catch (error) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(friendlyErrorMessage(error))),
                        );
                      }
                    },
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark as paid'),
            ),
          ),
        ],
      ),
    ),
  );
}
