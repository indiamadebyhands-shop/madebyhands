import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/support/data/models/support_ticket_model.dart';
import 'package:madebyhands/features/support/domain/repositories/support_repository.dart';
import 'package:madebyhands/features/support/presentation/pages/support_center_page.dart';
import 'package:madebyhands/init_dependencies.dart';

Future<void> openSupportConversation({
  required BuildContext context,
  required String ticketId,
  required String userId,
  required String userRole,
  NavigatorState? navigator,
}) async {
  final nav = navigator ?? Navigator.of(context);
  final repository = serviceLocator<SupportRepository>();
  final trimmedTicketId = ticketId.trim();

  if (trimmedTicketId.isNotEmpty) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(trimmedTicketId)
          .get();

      if (doc.exists) {
        final ticket = SupportTicketModel.fromDocument(doc);
        nav.push(
          MaterialPageRoute(
            builder: (_) => SupportConversationPage(
              ticket: ticket,
              repository: repository,
              senderId: userId,
              senderRole: userRole,
              canResolve: userRole.trim().toLowerCase() == 'admin',
            ),
          ),
        );
        return;
      }
    } catch (_) {}
  }

  nav.push(
    MaterialPageRoute(
      builder: (_) => SupportCenterPage(
        user: UserEntity(
          uid: userId,
          email: '',
          name: '',
          role: userRole,
        ),
        repository: repository,
      ),
    ),
  );
}

class SupportNotificationDialog extends StatelessWidget {
  final String title;
  final String message;
  final DateTime createdAt;
  final String? ticketId;
  final String userId;
  final String userRole;

  const SupportNotificationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.createdAt,
    this.ticketId,
    required this.userId,
    required this.userRole,
  });

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
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
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
            message,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SUPPORT',
                  style: TextStyle(
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
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: () {
                final nav = Navigator.of(context);
                nav.pop();
                openSupportConversation(
                  context: context,
                  navigator: nav,
                  ticketId: ticketId ?? '',
                  userId: userId,
                  userRole: userRole,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Open Chat'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ],
    );
  }
}
