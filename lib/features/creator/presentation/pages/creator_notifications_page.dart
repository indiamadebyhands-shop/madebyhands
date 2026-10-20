import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_notification.dart';
import 'package:madebyhands/features/creator/domain/repositories/creator_repository.dart';
import 'package:madebyhands/init_dependencies.dart';

class CreatorNotificationsPage extends StatefulWidget {
  final String creatorUid;

  const CreatorNotificationsPage({super.key, required this.creatorUid});

  @override
  State<CreatorNotificationsPage> createState() => _CreatorNotificationsPageState();
}

class _CreatorNotificationsPageState extends State<CreatorNotificationsPage> {
  final CreatorRepository _repository = serviceLocator<CreatorRepository>();
  late final Stream<List<CreatorNotification>> _notifications = _repository
      .watchNotifications(widget.creatorUid);
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markAllAsRead() async {
    final result = await _repository.markAllNotificationsAsRead(widget.creatorUid);
    result.fold((failure) => _showError(failure.message), (_) {});
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) {
        _selectedIds.add(id);
      } else if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _enterSelectionMode(String initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(initialId);
    });
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete notifications'),
        content: Text('Delete ${_selectedIds.length} notification(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ids = _selectedIds.toList();
    _exitSelectionMode();
    final result = await _repository.deleteNotifications(ids);
    result.fold((failure) => _showError(failure.message), (_) {});
  }

  void _selectAll(List<CreatorNotification> notifications) {
    setState(() {
      if (_selectedIds.length == notifications.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds
          ..clear()
          ..addAll(notifications.map((n) => n.id));
      }
    });
  }

  void _showNotificationDetail(CreatorNotification notification) {
    if (!notification.isRead) {
      _repository.markNotificationAsRead(notification.id);
    }
    showDialog<void>(
      context: context,
      builder: (_) => _NotificationDetailDialog(notification: notification),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CreatorNotification>>(
      stream: _notifications,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <CreatorNotification>[];
        final allSelected =
            notifications.isNotEmpty && _selectedIds.length == notifications.length;

        return Scaffold(
          appBar: AppBar(
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _exitSelectionMode,
                    tooltip: 'Exit selection mode',
                  )
                : null,
            title: Text(
              _isSelectionMode ? '${_selectedIds.length} selected' : 'Notifications',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: !_isSelectionMode,
            actions: _isSelectionMode
                ? [
                    IconButton(
                      icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                      tooltip: allSelected ? 'Deselect all' : 'Select all',
                      onPressed: () => _selectAll(notifications),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete selected',
                      onPressed: _selectedIds.isEmpty ? null : _confirmDeleteSelected,
                    ),
                    const SizedBox(width: 8),
                  ]
                : [
                    if (notifications.any((n) => !n.isRead))
                      IconButton(
                        tooltip: 'Mark all as read',
                        icon: const Icon(Icons.done_all),
                        onPressed: _markAllAsRead,
                      ),
                    const SizedBox(width: 8),
                  ],
          ),
          body: _buildBody(snapshot, notifications),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<List<CreatorNotification>> snapshot,
    List<CreatorNotification> notifications,
  ) {
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load notifications: ${friendlyErrorMessage(snapshot.error!)}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (notifications.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none, size: 64, color: AppColors.mutedText),
              SizedBox(height: 16),
              Text(
                'No notifications yet.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Updates about your orders, products and account will appear here.',
                style: TextStyle(color: AppColors.mutedText),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _NotificationTile(
          notification: notification,
          isSelectionMode: _isSelectionMode,
          isSelected: _selectedIds.contains(notification.id),
          onTap: () => _isSelectionMode
              ? _toggleSelection(notification.id)
              : _showNotificationDetail(notification),
          onLongPress: () => _isSelectionMode
              ? _toggleSelection(notification.id)
              : _enterSelectionMode(notification.id),
        );
      },
    );
  }
}

IconData _iconFor(String type) => switch (type) {
  'order' => Icons.shopping_bag_outlined,
  'verification' => Icons.verified_outlined,
  'product' => Icons.inventory_2_outlined,
  'announcement' => Icons.campaign_outlined,
  'support' => Icons.support_agent_outlined,
  _ => Icons.notifications_outlined,
};

Color _colorFor(String type) => switch (type) {
  'order' => AppColors.primary,
  'verification' => Colors.green,
  'product' => Colors.orange,
  'announcement' => Colors.purple,
  'support' => Colors.blue,
  _ => AppColors.accent,
};

class _NotificationTile extends StatelessWidget {
  final CreatorNotification notification;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NotificationTile({
    required this.notification,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.12)
          : (isUnread ? AppColors.primary.withValues(alpha: 0.04) : AppColors.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? AppColors.primary
              : (isUnread
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.outline.withValues(alpha: 0.5)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? AppColors.primary : AppColors.mutedText,
                    size: 22,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _colorFor(notification.type).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(notification.type), color: _colorFor(notification.type), size: 20),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isUnread && !isSelectionMode)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd MMM').format(notification.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationDetailDialog extends StatelessWidget {
  final CreatorNotification notification;

  const _NotificationDetailDialog({required this.notification});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _colorFor(notification.type).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(notification.type), color: _colorFor(notification.type), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notification.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            notification.message,
            style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.text),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(notification.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  notification.type.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
