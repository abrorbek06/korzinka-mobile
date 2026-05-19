import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../services/users_service.dart';
import '../theme/app_theme.dart';

class TransitionSheet extends StatefulWidget {
  final OrderDetail order;
  final AuthenticatedUser currentUser;
  final OrderStatus? initialTarget;

  const TransitionSheet({
    super.key,
    required this.order,
    required this.currentUser,
    this.initialTarget,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderDetail order,
    required AuthenticatedUser user,
    OrderStatus? initialTarget,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => TransitionSheet(
        order: order,
        currentUser: user,
        initialTarget: initialTarget,
      ),
    );
  }

  @override
  State<TransitionSheet> createState() => _TransitionSheetState();
}

class _TransitionSheetState extends State<TransitionSheet> {
  final _trolleyIdController = TextEditingController();
  final _notesController = TextEditingController();
  TransitionDefinition? _selected;
  bool _submitting = false;
  List<PickerUser> _pickers = [];
  PickerUser? _selectedPicker;
  bool _loadingPickers = false;

  List<TransitionDefinition> get _available =>
      availableTransitions(widget.order.status, widget.currentUser.role.name);

  @override
  void initState() {
    super.initState();
    if (widget.initialTarget != null) {
      try {
        _selected = _available.firstWhere((t) => t.to == widget.initialTarget);
      } catch (_) {
        // If the target is not available for this role, leave it null
      }
    }
    _loadPickers();
  }

  Future<void> _loadPickers() async {
    if (!_available.any((t) => t.requiresPickerId)) return;

    setState(() => _loadingPickers = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final usersService = UsersService(token: authProvider.token!);
      final pickers = await usersService.getPickers(
        branchId: widget.order.branchId,
      );
      setState(() {
        _pickers = pickers;
        _loadingPickers = false;
      });
    } catch (e) {
      print('[TransitionSheet] Failed to load pickers: $e');
      setState(() => _loadingPickers = false);
    }
  }

  @override
  void dispose() {
    _trolleyIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    if (_selected!.requiresPickerId && _selectedPicker == null) {
      _showError('Please select a picker for this transition.');
      return;
    }
    if (_selected!.requiresTrolleyId &&
        _trolleyIdController.text.trim().isEmpty) {
      _showError('Trolley ID is required for this transition.');
      return;
    }

    setState(() => _submitting = true);
    final provider = context.read<OrdersProvider>();

    final success = await provider.performTransition(
      orderId: widget.order.id,
      nextStatus: _selected!.to,
      pickerId: _selected!.requiresPickerId ? _selectedPicker!.id : null,
      trolleyId: _selected!.requiresTrolleyId
          ? _trolleyIdController.text.trim()
          : null,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
    } else {
      _showError(provider.error ?? 'Transition failed.');
      provider.clearError();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transitions = _available;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Actions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.order.code ?? 'Draft Order',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: widget.order.status),
                ],
              ),
            ),

            const Divider(height: 20),

            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (transitions.isEmpty) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: AppTheme.onSurfaceMuted,
                              size: 32,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No transitions available\nfor your role at this stage.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.onSurfaceMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'MOVE TO',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 10),

                      // Transition options
                      ...transitions.map(
                        (t) => _TransitionOption(
                          definition: t,
                          selected: _selected == t,
                          onTap: () => setState(() => _selected = t),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Picker selection dropdown (conditional)
                      if (_selected?.requiresPickerId == true) ...[
                        _loadingPickers
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : DropdownButtonFormField<PickerUser>(
                                value: _selectedPicker,
                                decoration: const InputDecoration(
                                  labelText: 'Select Picker *',
                                  prefixIcon: Icon(
                                    Icons.person_search_outlined,
                                  ),
                                ),
                                items: _pickers.map((picker) {
                                  return DropdownMenuItem<PickerUser>(
                                    value: picker,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          picker.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${picker.username} (${picker.activeAssignmentsCount} active)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.onSurfaceMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (picker) {
                                  setState(() => _selectedPicker = picker);
                                },
                              ),
                        const SizedBox(height: 12),
                      ],
                      if (_selected?.requiresTrolleyId == true) ...[
                        TextFormField(
                          controller: _trolleyIdController,
                          decoration: const InputDecoration(
                            labelText: 'Trolley ID *',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                            hintText: 'Enter trolley ID',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          prefixIcon: Icon(Icons.notes_outlined),
                          hintText: 'Add a note...',
                        ),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 20),

                      // Submit
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _selected == null || _submitting
                              ? null
                              : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.arrow_forward, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selected != null
                                          ? 'Move to ${_selected!.to.displayName}'
                                          : 'Select a transition',
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Payment actions
                    _PaymentActions(
                      order: widget.order,
                      currentUser: widget.currentUser,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransitionOption extends StatelessWidget {
  final TransitionDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  const _TransitionOption({
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final toStatus = definition.to;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? toStatus.color.withOpacity(0.12)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? toStatus.color : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              toStatus.icon,
              size: 20,
              color: selected ? toStatus.color : AppTheme.onSurfaceMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    toStatus.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? toStatus.color : AppTheme.onSurface,
                    ),
                  ),
                  if (definition.requiresPickerId ||
                      definition.requiresPaid ||
                      definition.requiresArrivedItemIds)
                    Text(
                      _requirementText(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 20, color: toStatus.color),
          ],
        ),
      ),
    );
  }

  String _requirementText() {
    final parts = <String>[];
    if (definition.requiresPickerId) parts.add('Requires picker');
    if (definition.requiresTrolleyId) parts.add('Requires trolley');
    if (definition.requiresPaid) parts.add('Requires PAID');
    if (definition.requiresArrivedItemIds) parts.add('Requires arrived items');
    return parts.join(' · ');
  }
}

class _PaymentActions extends StatefulWidget {
  final OrderDetail order;
  final AuthenticatedUser currentUser;

  const _PaymentActions({required this.order, required this.currentUser});

  @override
  State<_PaymentActions> createState() => _PaymentActionsState();
}

class _PaymentActionsState extends State<_PaymentActions> {
  bool _loading = false;

  bool get _canMarkPaid {
    // ADMIN/ACCOUNTANT for BANK; any non-PICKER/BASIC for CASH/CARD when READY
    final role = widget.currentUser.role;
    if (widget.order.paymentStatus == PaymentStatus.PAID) return false;
    if (widget.order.paymentType == PaymentType.BANK) {
      return role == UserRole.ADMIN || role == UserRole.ACCOUNTANT;
    }
    return role != UserRole.PICKER &&
        role != UserRole.BASIC &&
        widget.order.status == OrderStatus.READY;
  }

  bool get _canUnmarkPaid =>
      widget.currentUser.role == UserRole.ADMIN &&
      widget.order.paymentStatus == PaymentStatus.PAID;

  @override
  Widget build(BuildContext context) {
    if (!_canMarkPaid && !_canUnmarkPaid) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text('PAYMENT', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 10),
        if (_canMarkPaid)
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _action(mark: true),
            icon: const Icon(Icons.payment, size: 18),
            label: const Text('Mark as Paid'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF43A047),
              side: const BorderSide(color: Color(0xFF43A047)),
            ),
          ),
        if (_canUnmarkPaid) ...[
          if (_canMarkPaid) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _action(mark: false),
            icon: const Icon(Icons.money_off, size: 18),
            label: const Text('Unmark Paid'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF57C00),
              side: const BorderSide(color: Color(0xFFF57C00)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _action({required bool mark}) async {
    setState(() => _loading = true);
    final provider = context.read<OrdersProvider>();
    final ok = mark
        ? await provider.markPaid(widget.order.id)
        : await provider.unmarkPaid(widget.order.id);
    if (mounted) {
      setState(() => _loading = false);
      if (ok) Navigator.of(context).pop();
    }
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 5),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }
}
