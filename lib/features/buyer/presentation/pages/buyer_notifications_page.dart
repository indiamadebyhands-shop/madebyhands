import 'package:flutter/material.dart';
import 'package:madebyhands/features/buyer/presentation/theme/buyer_theme.dart';
import 'package:intl/intl.dart';
import 'package:madebyhands/features/buyer/domain/entities/buyer_product_notification.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_background.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_heading.dart';
import 'package:madebyhands/features/buyer/presentation/widgets/buyer_empty_state.dart';

class BuyerNotificationsPage extends StatefulWidget {
  final List<BuyerProductNotification> notifications;
  final Set<String> readNotificationIds;
  final ValueChanged<BuyerProductNotification> onNotificationTap;
  final VoidCallback onMarkAllRead;

  const BuyerNotificationsPage({
    super.key,
    required this.notifications,
    required this.readNotificationIds,
    required this.onNotificationTap,
    required this.onMarkAllRead,
  });

  @override
  State<BuyerNotificationsPage> createState() => _BuyerNotificationsPageState();
}

class _BuyerNotificationsPageState extends State<BuyerNotificationsPage> {
  late final Set<String> _readNotificationIds = {...widget.readNotificationIds};

  void _markAllRead() {
    setState(() {
      _readNotificationIds.addAll(
        widget.notifications.map((notification) => notification.id),
      );
    });
    widget.onMarkAllRead();
  }

  void _openNotification(BuyerProductNotification notification) {
    setState(() => _readNotificationIds.add(notification.id));
    widget.onNotificationTap(notification);
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = widget.notifications.any(
      (notification) => !_readNotificationIds.contains(notification.id),
    );
    return BuyerBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            if (hasUnread)
              TextButton(
                onPressed: _markAllRead,
                child: const Text('Mark all read'),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: widget.notifications.isEmpty
            ? const BuyerEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No new product alerts',
                message:
                    'When creators publish in categories you have wishlisted or purchased from, they will appear here.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: widget.notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notification = widget.notifications[index];
                  final isRead = _readNotificationIds.contains(notification.id);
                  return Card(
                    color: isRead ? null : BuyerColors.blush,
                    child: InkWell(
                      onTap: () => _openNotification(notification),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: isRead
                                  ? BuyerColors.blush
                                  : BuyerColors.card,
                              foregroundColor: BuyerColors.maroon,
                              child: Icon(
                                size: 20,
                                notification.type == BuyerNotificationType.order
                                    ? Icons.local_shipping_outlined
                                    : notification.type ==
                                            BuyerNotificationType.support
                                        ? Icons.support_agent_outlined
                                        : Icons.new_releases_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: BuyerHeading(
                                          notification.title,
                                          size: 15,
                                          color: isRead
                                              ? BuyerColors.ink
                                              : BuyerColors.maroonDeep,
                                        ),
                                      ),
                                      if (!isRead)
                                        const CircleAvatar(
                                          radius: 4,
                                          backgroundColor: BuyerColors.maroon,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    notification.message,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: BuyerColors.body,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy, hh:mm a',
                                    ).format(notification.publishedAt),
                                    style: const TextStyle(
                                      color: BuyerColors.muted,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
