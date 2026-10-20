class SupportTicket {
  final String id;
  final String userId;
  final String userRole;
  final String userName;
  final String subject;
  final String status;
  final String lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupportTicket({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.userName,
    required this.subject,
    required this.status,
    required this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status == 'open';
}

class SupportMessage {
  final String id;
  final String senderId;
  final String senderRole;
  final String message;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.createdAt,
  });
}

/// Minimal order information safe to attach to a support conversation.
class SupportOrderReference {
  final String id;
  final DateTime createdAt;
  final String status;
  final int total;
  final List<String> itemSummaries;

  const SupportOrderReference({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.total,
    required this.itemSummaries,
  });

  String get shortId => id.length > 8
      ? id.substring(id.length - 8).toUpperCase()
      : id.toUpperCase();
}
