import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:madebyhands/core/constants/couriers.dart';
import 'package:madebyhands/core/error/failures.dart';
import 'package:madebyhands/core/services/invoice_pdf_service.dart';
import 'package:madebyhands/core/theme/app_theme.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_order.dart';
import 'package:madebyhands/features/creator/domain/entities/creator_profile.dart';
import 'package:madebyhands/features/creator/domain/repositories/creator_repository.dart';
import 'package:madebyhands/features/creator/presentation/bloc/creator_bloc.dart';
import 'package:madebyhands/features/orders/domain/order_status.dart';
import 'package:madebyhands/init_dependencies.dart';

class CreatorOrdersView extends StatefulWidget {
  final CreatorProfile profile;
  const CreatorOrdersView({super.key, required this.profile});

  @override
  State<CreatorOrdersView> createState() => _CreatorOrdersViewState();
}

class _CreatorOrdersViewState extends State<CreatorOrdersView> {
  late final Stream<List<CreatorOrder>> _orders = serviceLocator<CreatorRepository>()
      .watchCreatorOrders(widget.profile.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CreatorOrder>>(
      stream: _orders,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load orders: ${friendlyErrorMessage(snapshot.error!)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF8B261D)),
          );
        }
        final orders = snapshot.data!;
        final newOrders = orders.where((o) => OrderStatus.isNew(o.status)).toList();
        final active = orders.where((o) => OrderStatus.isInProgress(o.status)).toList();
        final closed = orders
            .where(
              (o) =>
                  OrderStatus.isDelivered(o.status) ||
                  OrderStatus.isRejectedOrCancelled(o.status),
            )
            .toList();

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                labelColor: const Color(0xFF8B261D),
                indicatorColor: const Color(0xFF8B261D),
                unselectedLabelColor: AppColors.mutedText,
                tabs: [
                  Tab(text: 'New (${newOrders.length})'),
                  Tab(text: 'Active (${active.length})'),
                  Tab(text: 'Closed (${closed.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _OrderList(
                      orders: newOrders,
                      emptyMessage: 'No new orders.',
                      profile: widget.profile,
                    ),
                    _OrderList(
                      orders: active,
                      emptyMessage: 'No orders in progress.',
                      profile: widget.profile,
                    ),
                    _OrderList(
                      orders: closed,
                      emptyMessage: 'No completed orders yet.',
                      profile: widget.profile,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<CreatorOrder> orders;
  final String emptyMessage;
  final CreatorProfile profile;

  const _OrderList({
    required this.orders,
    required this.emptyMessage,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(emptyMessage, style: const TextStyle(color: AppColors.mutedText)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: orders.length,
      itemBuilder: (context, index) => _OrderCard(
        order: orders[index],
        profile: profile,
      ),
    );
  }
}

/// Confirms with the creator, then rejects through the payment API which
/// refunds the buyer.
Future<bool> _rejectOrder(BuildContext context, CreatorOrder order) async {
  final bloc = context.read<CreatorBloc>();
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFFFAF6EE),
      title: Text(
        'Reject order #${order.shortId}?',
        style: const TextStyle(color: Color(0xFF8B261D)),
      ),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The buyer is refunded in full and the items go back into stock.',
              style: TextStyle(fontSize: 13, color: AppColors.mutedText),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Reason for the buyer *'),
              validator: (value) =>
                  (value?.trim().length ?? 0) < 3 ? 'Please give a short reason.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(dialogContext, controller.text.trim());
            }
          },
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Reject & refund'),
        ),
      ],
    ),
  );
  if (reason == null) return false;
  bloc.add(CreatorRejectOrder(orderId: order.id, reason: reason));
  return true;
}

class _OrderCard extends StatelessWidget {
  final CreatorOrder order;
  final CreatorProfile profile;

  const _OrderCard({required this.order, required this.profile});

  @override
  Widget build(BuildContext context) {
    final isNew = OrderStatus.isNew(order.status);
    final itemCount = order.items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Card(
      elevation: 1,
      color: const Color(0xFFFAF6EE).withValues(alpha: 0.95),
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: const Color(0xFF8B261D).withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: const Color(0xFFFAF6EE),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          builder: (_) => _OrderDetailSheet(order: order, profile: profile),
        ),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.shortId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B261D),
                      ),
                    ),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Customer: ${order.buyerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
              ),
              if ((order.rejectionReason ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Rejected: ${order.rejectionReason}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                      style: const TextStyle(color: AppColors.mutedText),
                    ),
                  ),
                  Text(
                    '₹${order.totalAmount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF8B261D),
                    ),
                  ),
                ],
              ),
              if (isNew) ...[
                const SizedBox(height: 16),
                BlocSelector<CreatorBloc, CreatorState, bool>(
                  selector: (state) =>
                      state.isRunning(CreatorAction.rejectOrder) ||
                      state.isRunning(CreatorAction.updateOrder),
                  builder: (context, busy) => Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => _rejectOrder(context, order),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: busy
                              ? null
                              : () => context.read<CreatorBloc>().add(
                                  CreatorUpdateOrderStatus(
                                    orderId: order.id,
                                    status: OrderStatus.confirmed,
                                  ),
                                ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8B261D),
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OrderStatusBadge extends StatelessWidget {
  final String status;
  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (OrderStatus.normalize(status)) {
      OrderStatus.placed => Colors.blue.shade800,
      OrderStatus.confirmed => Colors.orange.shade800,
      OrderStatus.processing => Colors.amber.shade900,
      OrderStatus.inTransit => Colors.purple.shade800,
      OrderStatus.shipped => Colors.indigo.shade800,
      OrderStatus.outForDelivery => Colors.deepOrange.shade800,
      OrderStatus.delivered => Colors.green.shade800,
      OrderStatus.rejected || OrderStatus.cancelled => Colors.red.shade800,
      _ => AppColors.mutedText,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        OrderStatus.shortLabel(status),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

Future<void> _downloadBuyerInvoice(BuildContext context, CreatorOrder order) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final data = InvoiceData.buyerCopy(
      orderId: order.id,
      invoiceDate: order.createdAt,
      billToName: order.buyerName,
      billToAddressLines: order.deliveryAddress
          .split(',')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      items: order.items
          .map(
            (item) => InvoiceLineItem(
              name: item.name,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
            ),
          )
          .toList(),
      subtotal: order.totalAmount,
      buyerTotalPaid: order.totalAmount + order.flatFee,
    );
    await InvoicePdfService.downloadOrShare(data);
  } catch (error) {
    logInvoiceError(error);
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not generate the invoice. Please try again.')),
      );
    }
  }
}

Future<void> _downloadSellerInvoice(BuildContext context, CreatorOrder order) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final data = InvoiceData.sellerCopy(
      orderId: order.id,
      invoiceDate: order.createdAt,
      billToName: order.buyerName,
      billToAddressLines: order.deliveryAddress
          .split(',')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(),
      items: order.items
          .map(
            (item) => InvoiceLineItem(
              name: item.name,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
            ),
          )
          .toList(),
      subtotal: order.totalAmount,
      flatFee: order.flatFee,
      commissionRate: order.commissionRate,
      commissionAmount: order.commissionAmount,
    );
    await InvoicePdfService.downloadOrShare(data);
  } catch (error) {
    logInvoiceError(error);
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not generate the invoice. Please try again.')),
      );
    }
  }
}

class _OrderDetailSheet extends StatelessWidget {
  final CreatorOrder order;
  final CreatorProfile profile;

  const _OrderDetailSheet({required this.order, required this.profile});

  @override
  Widget build(BuildContext context) {
    final next = OrderStatus.next(order.status);
    final nextStatus = next != null ? OrderStatus.storedValue(next) : null;
    final canAdvance = nextStatus != null;
    final isTerminal = OrderStatus.isDelivered(order.status) ||
        OrderStatus.isRejectedOrCancelled(order.status);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.shortId}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B261D),
                        ),
                      ),
                      Text(
                        'Placed ${DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF8B261D)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    OrderStatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 16),
                _infoSection('Customer Details', [
                  _infoRow('Name', order.buyerName),
                  _infoRow('Phone', order.buyerPhone),
                  _infoRow('Address', order.deliveryAddress),
                ]),
                const SizedBox(height: 16),
                _infoSection('Order Items', [
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} × ${item.quantity}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '₹${item.total}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B261D),
                            ),
                          ),
                        ],
                      ),
                    ),
                ]),
                if (order.consignmentNumber != null || order.carrierName != null) ...[
                  const SizedBox(height: 16),
                  _infoSection('Dispatch & Tracking', [
                    if (order.carrierName != null)
                      _infoRow('Carrier', order.carrierName!),
                    if (order.consignmentNumber != null)
                      _infoRow('Consignment #', order.consignmentNumber!),
                  ]),
                ],
                const SizedBox(height: 16),
                _infoSection('Financial Summary', [
                  _infoRow('Subtotal', '₹${order.totalAmount}'),
                  _infoRow('Platform Fee', '₹${order.platformFee}'),
                  _infoRow('Net Payout', '₹${order.creatorNetAmount}', isBold: true),
                ]),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadBuyerInvoice(context, order),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF8B261D)),
                          foregroundColor: const Color(0xFF8B261D),
                        ),
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: const Text('Buyer Invoice'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadSellerInvoice(context, order),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF8B261D)),
                          foregroundColor: const Color(0xFF8B261D),
                        ),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Seller Invoice'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isTerminal) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final rejected = await _rejectOrder(context, order);
                        if (rejected && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Reject Order'),
                    ),
                  ),
                  if (canAdvance) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _advanceStatus(context, nextStatus),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF8B261D),
                        ),
                        child: Text(
                          OrderStatus.isDelivered(nextStatus)
                              ? 'Mark as delivered'
                              : 'Mark as $nextStatus',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _advanceStatus(BuildContext context, String nextStatus) {
    if (nextStatus == 'In-Transit') {
      _showConsignmentDialog(context);
    } else if (OrderStatus.isDelivered(nextStatus)) {
      _confirmDelivered(context, nextStatus);
    } else {
      context.read<CreatorBloc>().add(
            CreatorUpdateOrderStatus(
              orderId: order.id,
              status: nextStatus,
              consignmentNumber: order.consignmentNumber,
              carrierName: order.carrierName,
            ),
          );
      Navigator.pop(context);
    }
  }

  /// Delivery can't be undone and releases the payout, so the creator must
  /// tick a statement before the order is marked as delivered.
  Future<void> _confirmDelivered(BuildContext context, String nextStatus) async {
    final bloc = context.read<CreatorBloc>();
    final navigator = Navigator.of(context);
    var confirmed = false;
    var showError = false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFFFAF6EE),
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Confirm delivery',
            style: TextStyle(color: Color(0xFF8B261D)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Only mark this order as delivered once the buyer has received it. This cannot be undone.',
                style: TextStyle(fontSize: 13),
              ),
              CheckboxListTile(
                value: confirmed,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFF8B261D),
                title: const Text(
                  'The buyer has received this order.',
                  style: TextStyle(fontSize: 13),
                ),
                onChanged: (value) => setDialogState(() {
                  confirmed = value ?? false;
                  showError = false;
                }),
              ),
              if (showError)
                const Text(
                  'Please confirm the statement above to continue.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B261D),
              ),
              onPressed: () {
                if (!confirmed) {
                  setDialogState(() => showError = true);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Mark delivered'),
            ),
          ],
        ),
      ),
    );

    if (proceed != true) return;
    bloc.add(
      CreatorUpdateOrderStatus(
        orderId: order.id,
        status: nextStatus,
        consignmentNumber: order.consignmentNumber,
        carrierName: order.carrierName,
      ),
    );
    navigator.pop();
  }

  void _showConsignmentDialog(BuildContext context) {
    final consignmentController = TextEditingController(
      text: order.consignmentNumber ?? '',
    );
    final confirmConsignmentController = TextEditingController(
      text: order.consignmentNumber ?? '',
    );
    String? selectedCourier = kCourierOptions.contains(order.carrierName)
        ? order.carrierName
        : null;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFAF6EE),
            scrollable: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            title: const Text(
              'Enter Dispatch Details',
              style: TextStyle(color: Color(0xFF8B261D)),
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please enter consignment details and select a courier partner to move this order to In-Transit.',
                    style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: consignmentController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Consignment / Reference Number *',
                      hintText: 'e.g. SP123456789IN',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) {
                      final trimmed = v?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Consignment number is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmConsignmentController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Consignment Number *',
                      hintText: 'Re-enter consignment number',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) {
                      final trimmed = v?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Please confirm consignment number.';
                      }
                      if (trimmed != consignmentController.text.trim()) {
                        return 'Consignment numbers do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedCourier,
                    decoration: const InputDecoration(
                      labelText: 'Courier / Carrier Partner *',
                      hintText: 'Select Courier Partner',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: kCourierOptions.map((courier) {
                      return DropdownMenuItem<String>(
                        value: courier,
                        child: Text(
                          courier,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedCourier = val;
                      });
                    },
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please select a courier partner.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    context.read<CreatorBloc>().add(
                          CreatorUpdateOrderStatus(
                            orderId: order.id,
                            status: 'In-Transit',
                            consignmentNumber:
                                consignmentController.text.trim(),
                            carrierName: selectedCourier,
                          ),
                        );
                    Navigator.pop(dialogContext);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B261D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: const Text('Confirm & Move to In-Transit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8B261D).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B261D),
              fontSize: 14,
            ),
          ),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? const Color(0xFF8B261D) : AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
