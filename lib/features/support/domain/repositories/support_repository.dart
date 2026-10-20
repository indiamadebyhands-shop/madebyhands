import 'package:madebyhands/features/support/domain/entities/support_ticket.dart';

abstract class SupportRepository {
  Stream<List<SupportTicket>> watchUserTickets(String userId);
  Stream<List<SupportTicket>> watchAllTickets();
  Stream<List<SupportMessage>> watchMessages(String ticketId);

  Future<List<SupportOrderReference>> getValidOrders({
    required String userId,
    required String userRole,
  });

  Future<String> createTicket({
    required String userId,
    required String userRole,
    required String userName,
    required String subject,
    required String message,
    String type = 'general',
    String? orderId,
  });

  Future<void> sendMessage({
    required String ticketId,
    required String senderId,
    required String senderRole,
    required String message,
  });

  Future<void> resolveTicket(String ticketId);
}
