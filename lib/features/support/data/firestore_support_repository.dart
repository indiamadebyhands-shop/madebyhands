import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madebyhands/features/support/data/models/support_message_model.dart';
import 'package:madebyhands/features/support/data/models/support_ticket_model.dart';
import 'package:madebyhands/features/support/domain/entities/support_ticket.dart';
import 'package:madebyhands/features/support/domain/repositories/support_repository.dart';

class FirestoreSupportRepository implements SupportRepository {
  final FirebaseFirestore firestore;

  const FirestoreSupportRepository({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _tickets =>
      firestore.collection('support_tickets');

  @override
  Stream<List<SupportTicket>> watchUserTickets(String userId) => _tickets
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map(_ticketsFromSnapshot);

  @override
  Stream<List<SupportTicket>> watchAllTickets() =>
      _tickets.snapshots().map(_ticketsFromSnapshot);

  @override
  Stream<List<SupportMessage>> watchMessages(String ticketId) => _tickets
      .doc(ticketId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map<SupportMessage>(SupportMessageModel.fromDocument)
            .toList(),
      );

  List<SupportTicket> _ticketsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final tickets = snapshot.docs
        .map<SupportTicket>(SupportTicketModel.fromDocument)
        .toList();
    tickets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return tickets;
  }

  @override
  Future<String> createTicket({
    required String userId,
    required String userRole,
    required String userName,
    required String subject,
    required String message,
  }) async {
    final ticket = _tickets.doc();
    final batch = firestore.batch();

    batch.set(ticket, {
      'userId': userId,
      'userRole': userRole,
      'userName': userName,
      'subject': subject,
      'type': 'general',
      'status': 'open',
      'lastMessage': message,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(ticket.collection('messages').doc(), {
      'senderId': userId,
      'senderRole': userRole,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(firestore.collection('notifications').doc(), {
      'type': 'admin',
      'category': 'support_ticket',
      'title': 'New support ticket',
      'message':
          '${userName.isNotEmpty ? userName : 'A user'} ($userRole) raised a ticket: "$subject"',
      'targetId': ticket.id,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
    batch.set(firestore.collection('notifications').doc(), {
      'userId': userId,
      'creatorUid': userId,
      'type': 'support',
      'category': 'support_ticket',
      'title': 'Support ticket created',
      'message':
          'Your support ticket "$subject" has been successfully created.',
      'targetId': ticket.id,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await batch.commit();
    return ticket.id;
  }

  @override
  Future<void> sendMessage({
    required String ticketId,
    required String senderId,
    required String senderRole,
    required String message,
  }) async {
    final ticketRef = _tickets.doc(ticketId);
    final batch = firestore.batch();

    batch.set(ticketRef.collection('messages').doc(), {
      'senderId': senderId,
      'senderRole': senderRole,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(ticketRef, {
      'lastMessage': message,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (senderRole == 'admin') {
      final ticketSnap = await ticketRef.get();
      if (ticketSnap.exists) {
        final ticketData = ticketSnap.data();
        final ticketUserId = ticketData?['userId'] as String? ?? '';
        final subject = ticketData?['subject'] as String? ?? 'Support Ticket';
        if (ticketUserId.isNotEmpty) {
          final trimmedMsg = message.length > 80
              ? '${message.substring(0, 80)}...'
              : message;
          batch.set(firestore.collection('notifications').doc(), {
            'userId': ticketUserId,
            'creatorUid': ticketUserId,
            'type': 'support',
            'category': 'support_reply',
            'title': 'New reply on support ticket',
            'message': 'Admin replied to "$subject": "$trimmedMsg"',
            'targetId': ticketId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      }
    }

    await batch.commit();
  }

  @override
  Future<void> resolveTicket(String ticketId) => _tickets.doc(ticketId).update({
    'status': 'resolved',
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
