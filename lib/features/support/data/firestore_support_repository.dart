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
  Future<List<SupportOrderReference>> getValidOrders({
    required String userId,
    required String userRole,
  }) async {
    final normalizedRole = userRole.trim().toLowerCase();
    final ownerField = normalizedRole == 'creator' || normalizedRole == 'seller'
        ? 'creatorId'
        : 'buyerId';
    final snapshot = await firestore
        .collection('orders')
        .where(ownerField, isEqualTo: userId)
        .get();
    final orders =
        snapshot.docs
            .where((document) => document.data()['isSample'] != true)
            .map((document) {
              final data = document.data();
              final rawItems = data['items'] as List<dynamic>? ?? const [];
              final itemSummaries = rawItems.whereType<Map>().map((raw) {
                final item = Map<String, dynamic>.from(raw);
                final name = item['name'] as String? ?? 'Handmade item';
                final quantity = (item['quantity'] as num?)?.round() ?? 1;
                return '$name × $quantity';
              }).toList();
              final subtotal =
                  (data['subtotal'] as num?)?.round() ??
                  (data['totalAmount'] as num?)?.round() ??
                  (data['total'] as num?)?.round() ??
                  0;
              final total = normalizedRole == 'buyer'
                  ? (data['buyerPayableAmount'] as num?)?.round() ?? subtotal
                  : subtotal;
              final createdAt = data['createdAt'];
              return SupportOrderReference(
                id: document.id,
                createdAt: createdAt is Timestamp
                    ? createdAt.toDate()
                    : DateTime.fromMillisecondsSinceEpoch(0),
                status: data['status'] as String? ?? 'Placed',
                total: total,
                itemSummaries: itemSummaries,
              );
            })
            .where((order) => order.itemSummaries.isNotEmpty)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  @override
  Future<String> createTicket({
    required String userId,
    required String userRole,
    required String userName,
    required String subject,
    required String message,
    String type = 'general',
    String? orderId,
  }) async {
    final ticket = _tickets.doc();
    final batch = firestore.batch();

    batch.set(ticket, {
      'userId': userId,
      'userRole': userRole,
      'userName': userName,
      'subject': subject,
      'type': type,
      if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
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
      'ticketId': ticket.id,
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
      'ticketId': ticket.id,
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

    final ticketSnap = await ticketRef.get();
    if (ticketSnap.exists) {
      final ticketData = ticketSnap.data();
      final ticketUserId = ticketData?['userId'] as String? ?? '';
      final userName = ticketData?['userName'] as String? ?? 'User';
      final userRole = ticketData?['userRole'] as String? ?? 'user';
      final subject = ticketData?['subject'] as String? ?? 'Support Ticket';
      final trimmedMsg = message.length > 80
          ? '${message.substring(0, 80)}...'
          : message;

      if (senderRole == 'admin') {
        if (ticketUserId.isNotEmpty) {
          batch.set(firestore.collection('notifications').doc(), {
            'userId': ticketUserId,
            'creatorUid': ticketUserId,
            'type': 'support',
            'category': 'support_reply',
            'title': 'New reply on support ticket',
            'message': 'Admin replied to "$subject": "$trimmedMsg"',
            'targetId': ticketId,
            'ticketId': ticketId,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        }
      } else {
        batch.set(firestore.collection('notifications').doc(), {
          'type': 'admin',
          'category': 'support_reply',
          'title': 'New reply on support ticket',
          'message':
              '${userName.isNotEmpty ? userName : 'A user'} ($userRole) replied to "$subject": "$trimmedMsg"',
          'targetId': ticketId,
          'ticketId': ticketId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }
    }

    await batch.commit();
  }

  @override
  Future<void> resolveTicket(String ticketId) async {
    final ticketRef = _tickets.doc(ticketId);
    final batch = firestore.batch();

    batch.update(ticketRef, {
      'status': 'resolved',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final ticketSnap = await ticketRef.get();
    if (ticketSnap.exists) {
      final ticketData = ticketSnap.data();
      final ticketUserId = ticketData?['userId'] as String? ?? '';
      final userName = ticketData?['userName'] as String? ?? 'User';
      final userRole = ticketData?['userRole'] as String? ?? 'user';
      final subject = ticketData?['subject'] as String? ?? 'Support Ticket';

      if (ticketUserId.isNotEmpty) {
        batch.set(firestore.collection('notifications').doc(), {
          'userId': ticketUserId,
          'creatorUid': ticketUserId,
          'type': 'support',
          'category': 'support_resolved',
          'title': 'Support ticket resolved',
          'message':
              'Your support ticket "$subject" has been closed by support.',
          'targetId': ticketId,
          'ticketId': ticketId,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      batch.set(firestore.collection('notifications').doc(), {
        'type': 'admin',
        'category': 'support_resolved',
        'title': 'Support ticket closed',
        'message':
            'Ticket "$subject" raised by ${userName.isNotEmpty ? userName : 'A user'} ($userRole) has been closed.',
        'targetId': ticketId,
        'ticketId': ticketId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    await batch.commit();
  }
}
