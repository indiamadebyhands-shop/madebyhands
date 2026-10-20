import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/auth/domain/entities/user_entity.dart';
import 'package:madebyhands/features/support/domain/entities/support_ticket.dart';
import 'package:madebyhands/features/support/domain/repositories/support_repository.dart';

class SupportCenterPage extends StatefulWidget {
  final UserEntity user;
  final SupportRepository repository;

  /// Wraps the conversation page this screen pushes, so a panel with its own
  /// look (the buyer's parchment theme) carries it onto that route too.
  final Widget Function(Widget page)? pageWrapper;

  const SupportCenterPage({
    super.key,
    required this.user,
    required this.repository,
    this.pageWrapper,
  });

  @override
  State<SupportCenterPage> createState() => _SupportCenterPageState();
}

class _SupportCenterPageState extends State<SupportCenterPage> {
  late final Stream<List<SupportTicket>> _tickets = widget.repository
      .watchUserTickets(widget.user.uid);
  bool _startingTicket = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _startingTicket ? null : _newTicket,
        icon: _startingTicket
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_startingTicket ? 'Loading orders' : 'Raise ticket'),
      ),
      body: StreamBuilder<List<SupportTicket>>(
        stream: _tickets,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load tickets: ${friendlyErrorMessage(snapshot.error!)}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tickets = snapshot.data!;
          if (tickets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No support tickets yet. Tap “Raise ticket” to get help.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => SupportTicketTile(
              ticket: tickets[index],
              onTap: () => _openConversation(tickets[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _newTicket() async {
    if (_startingTicket) return;
    setState(() => _startingTicket = true);
    final messenger = ScaffoldMessenger.of(context);
    List<SupportOrderReference> orders;
    try {
      orders = await widget.repository.getValidOrders(
        userId: widget.user.uid,
        userRole: widget.user.role,
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
      return;
    } finally {
      if (mounted) setState(() => _startingTicket = false);
    }
    if (!mounted) return;

    if (orders.isEmpty) {
      await _createGeneralTicket();
      return;
    }

    final choice = await showModalBottomSheet<_SupportTopic>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How can we help?',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _SupportTopicTile(
                icon: Icons.shopping_bag_outlined,
                title: 'Need help with my order',
                subtitle: 'Choose an order to share with support',
                onTap: () => Navigator.pop(sheetContext, _SupportTopic.order),
              ),
              const SizedBox(height: 10),
              _SupportTopicTile(
                icon: Icons.chat_bubble_outline,
                title: 'I need help with something else',
                subtitle: 'Describe another issue',
                onTap: () => Navigator.pop(sheetContext, _SupportTopic.general),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == _SupportTopic.order) {
      final selectedOrder = await _selectOrder(orders);
      if (!mounted || selectedOrder == null) return;
      await _createOrderTicket(selectedOrder);
      return;
    }
    await _createGeneralTicket();
  }

  Future<SupportOrderReference?> _selectOrder(
    List<SupportOrderReference> orders,
  ) => showModalBottomSheet<SupportOrderReference>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Select an order',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final order = orders[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      onTap: () => Navigator.pop(sheetContext, order),
                      title: Text(
                        'Order #${order.shortId}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${DateFormat('dd MMM yyyy').format(order.createdAt)}'
                        '  •  ${_displayStatus(order.status)}\n'
                        '${order.itemSummaries.join(', ')}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${order.total}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
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

  Future<void> _createOrderTicket(SupportOrderReference order) async {
    final role = widget.user.role.trim().toLowerCase() == 'buyer'
        ? 'Buyer'
        : 'Creator';
    final subject = 'Help with order #${order.shortId}';
    final message = [
      'I need help with this order.',
      '',
      'Order ID: ${order.id}',
      'Status: ${_displayStatus(order.status)}',
      'Placed: ${DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)}',
      'Items: ${order.itemSummaries.join(', ')}',
      'Order total: ₹${order.total}',
      'Account type: $role',
    ].join('\n');
    await _submitTicket(
      subject: subject,
      message: message,
      type: 'order',
      orderId: order.id,
    );
  }

  Future<void> _createGeneralTicket() async {
    var subject = '';
    var message = '';
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Raise a support ticket'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  onChanged: (value) => subject = value,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Enter a subject.'
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  onChanged: (value) => message = value,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Describe the issue',
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Describe the issue.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    await _submitTicket(subject: subject.trim(), message: message.trim());
  }

  Future<void> _submitTicket({
    required String subject,
    required String message,
    String type = 'general',
    String? orderId,
  }) async {
    if (_startingTicket) return;
    setState(() => _startingTicket = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ticketId = await widget.repository.createTicket(
        userId: widget.user.uid,
        userRole: widget.user.role,
        userName: widget.user.name,
        subject: subject,
        message: message,
        type: type,
        orderId: orderId,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Support ticket created.')),
      );
      final now = DateTime.now();
      _openConversation(
        SupportTicket(
          id: ticketId,
          userId: widget.user.uid,
          userRole: widget.user.role,
          userName: widget.user.name,
          subject: subject,
          status: 'open',
          lastMessage: message,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _startingTicket = false);
    }
  }

  void _openConversation(SupportTicket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          final page = SupportConversationPage(
            ticket: ticket,
            repository: widget.repository,
            senderId: widget.user.uid,
            senderRole: widget.user.role,
          );
          return widget.pageWrapper?.call(page) ?? page;
        },
      ),
    );
  }

  static String _displayStatus(String status) {
    final spaced = status.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    if (spaced.isEmpty) return 'Placed';
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}

enum _SupportTopic { order, general }

class _SupportTopicTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportTopicTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

/// A ticket row shared by the user and admin ticket lists.
class SupportTicketTile extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;
  final bool showRequester;

  const SupportTicketTile({
    super.key,
    required this.ticket,
    required this.onTap,
    this.showRequester = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = ticket.isOpen ? Colors.orange : Colors.green;
    final requester = '${ticket.userName} (${ticket.userRole})';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            ticket.isOpen ? Icons.help_outline : Icons.check_circle_outline,
            color: color,
          ),
        ),
        title: Text(
          ticket.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          showRequester
              ? '$requester\n${ticket.lastMessage}'
              : ticket.lastMessage,
          maxLines: showRequester ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
        ),
        trailing: Text(
          ticket.isOpen ? 'Open' : 'Resolved',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color.shade800,
          ),
        ),
      ),
    );
  }
}

class SupportConversationPage extends StatefulWidget {
  final SupportTicket ticket;
  final SupportRepository repository;
  final String senderId;
  final String senderRole;
  final bool canResolve;

  const SupportConversationPage({
    super.key,
    required this.ticket,
    required this.repository,
    required this.senderId,
    required this.senderRole,
    this.canResolve = false,
  });

  @override
  State<SupportConversationPage> createState() =>
      _SupportConversationPageState();
}

class _SupportConversationPageState extends State<SupportConversationPage> {
  final _message = TextEditingController();
  late final Stream<List<SupportMessage>> _messages = widget.repository
      .watchMessages(widget.ticket.id);
  late bool _isOpen = widget.ticket.isOpen;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool _isMine(SupportMessage message) {
    if (message.senderId == widget.senderId) return true;
    // Older admin replies were stored with a placeholder sender id.
    return widget.canResolve && message.senderRole == 'admin';
  }

  Future<void> _resolve() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.resolveTicket(widget.ticket.id);
      if (!mounted) return;
      setState(() => _isOpen = false);
      messenger.showSnackBar(const SnackBar(content: Text('Ticket resolved.')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.repository.sendMessage(
        ticketId: widget.ticket.id,
        senderId: widget.senderId,
        senderRole: widget.senderRole,
        message: text,
      );
      _message.clear();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ticket.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.canResolve && _isOpen)
            IconButton(
              tooltip: 'Mark as resolved',
              onPressed: _resolve,
              icon: const Icon(Icons.check_circle_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<SupportMessage>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(friendlyErrorMessage(snapshot.error!)),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final item = messages[messages.length - 1 - index];
                    final mine = _isMine(item);
                    final colors = Theme.of(context).colorScheme;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        child: Card(
                          color: mine
                              ? Color.alphaBlend(
                                  colors.primary.withValues(alpha: 0.12),
                                  colors.surface,
                                )
                              : colors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine)
                                  Text(
                                    item.senderRole == 'admin'
                                        ? 'MadeByHands support'
                                        : widget.ticket.userName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                Text(item.message),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'dd MMM, hh:mm a',
                                  ).format(item.createdAt),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isOpen)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _message,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: _sending ? null : _send,
                      // Explicit, because an ambient IconTheme colour (the
                      // buyer theme sets one) otherwise replaces the filled
                      // button's default foreground.
                      style: IconButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            )
          else
            const SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'This ticket is resolved.',
                  style: TextStyle(color: AppColors.mutedText),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
