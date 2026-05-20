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
  String? _errorMessage;
  List<PickerUser> _pickers = [];
  PickerUser? _selectedPicker;
  bool _loadingPickers = false;
  final Set<String> _selectedBackorderedItemIds = {};
  final Map<String, TextEditingController> _backorderedQuantityControllers = {};
  final Set<String> _selectedArrivedItemIds = {};

  List<TransitionDefinition> get _available {
    // Base available transitions according to the static role map.
    final base = availableTransitions(
      widget.order.status,
      widget.currentUser.role.name,
    );

    // If nothing is available via the static map, and the current user is
    // a picker, merge-in any transitions that explicitly list PICKER as a
    // role for this from-status. This allows the assigned picker to act
    // on picker-scoped transitions (e.g. IN_COLLECTION -> PARTIAL) even
    // if other role checks differ elsewhere.
    if (base.isEmpty && widget.currentUser.role == UserRole.PICKER) {
      final pickerRules = kTransitionRules.where((t) {
        return t.from == widget.order.status && t.roles.contains('PICKER');
      }).toList();
      return [...base, ...pickerRules];
    }

    return base;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialTarget != null) {
      try {
        _selected = _available.firstWhere((t) => t.to == widget.initialTarget);
        if (_selected?.requiresArrivedItemIds == true) {
          _selectedArrivedItemIds.addAll(
            widget.order.items
                .where((i) => i.status == ItemStatus.BACKORDERED)
                .map((i) => i.id),
          );
        }
      } catch (_) {
        // If the target is not available for this role, leave it null
      }
    }
    // If the transition requires a picker and the current user is the
    // assigned picker, pre-select them so they don't need to re-select.
    if (_selected?.requiresPickerId == true &&
        widget.order.pickerId != null &&
        widget.order.pickerId == widget.currentUser.id) {
      _selectedPicker = PickerUser(
        id: widget.currentUser.id,
        username: widget.currentUser.username,
        name: widget.currentUser.username,
        activeAssignmentsCount: 0,
      );
    }

    _loadPickers();

    // Debug: show computed available transitions and current role once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final role = widget.currentUser.role.name;
      final names = _available.map((t) => '${t.from.name}->${t.to.name}').join(', ');
      final msg = 'role=$role available=[$names]';
      debugPrint('[TransitionSheet] $msg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
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
      debugPrint('[TransitionSheet] Failed to load pickers: $e');
      setState(() => _loadingPickers = false);
    }
  }

  @override
  void dispose() {
    _trolleyIdController.dispose();
    _notesController.dispose();
    for (final controller in _backorderedQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    // Debug: show which transition is being submitted and current computed availability
    final submitMsg = 'Submitting transition ${_selected!.from.name}->${_selected!.to.name} for role=${widget.currentUser.role.name}';
    debugPrint('[TransitionSheet] $submitMsg');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(submitMsg), duration: const Duration(seconds: 3)),
      );
    }
    setState(() => _errorMessage = null);
    if (_selected!.requiresPickerId && _selectedPicker == null) {
      _showError('Please select a picker for this transition.');
      return;
    }
    if (_selected!.requiresTrolleyId &&
        _trolleyIdController.text.trim().isEmpty) {
      _showError('Trolley ID is required for this transition.');
      return;
    }
    if (_selected!.requiresPaid &&
        widget.order.paymentStatus != PaymentStatus.PAID) {
      _showError('Order must be marked PAID before this transition.');
      return;
    }
    // Some transitions require a backorder quantity selection.
    if (_selected!.requiresBackorderedItems) {
      if (_selectedBackorderedItemIds.isEmpty) {
        _showError('Please select at least one item to mark as backordered.');
        return;
      }
      for (final itemId in _selectedBackorderedItemIds) {
        final item = widget.order.items.firstWhere((i) => i.id == itemId);
        final text = _backorderedQuantityControllers[itemId]?.text.trim() ?? '';
        final available = int.tryParse(text);
        if (available == null || available < 0 || available > item.quantity) {
          _showError(
            'Enter a valid available quantity for ${item.productName} (0..${item.quantity}).',
          );
          return;
        }
        if (available == item.quantity) {
          _showError(
            'Enter a valid available quantity for ${item.productName} (0..${item.quantity - 1}).',
          );
          return;
        }
      }
    }
    // PARTIAL → READY requires arrivedItemIds payload
    if (_selected!.requiresArrivedItemIds) {
      if (_selectedArrivedItemIds.isEmpty) {
        _showError('Please mark all backordered items as arrived.');
        return;
      }
      final backorderedIds = widget.order.items
          .where((i) => i.status == ItemStatus.BACKORDERED)
          .map((i) => i.id)
          .toSet();
      if (_selectedArrivedItemIds.length != backorderedIds.length ||
          !_selectedArrivedItemIds.every(backorderedIds.contains)) {
        _showError(
          'All backordered items must be marked arrived before moving to READY.',
        );
        return;
      }
    }

    setState(() => _submitting = true);
    final provider = context.read<OrdersProvider>();

    // Build backorderedItems payload
    List<Map<String, dynamic>>? backorderedItemsPayload;
    if (_selected!.requiresBackorderedItems &&
        _selectedBackorderedItemIds.isNotEmpty) {
      backorderedItemsPayload = _selectedBackorderedItemIds.map((itemId) {
        final item = widget.order.items.firstWhere((i) => i.id == itemId);
        final text = _backorderedQuantityControllers[itemId]?.text.trim() ?? '';
        final available = int.tryParse(text) ?? item.quantity.toInt();
        final missing = item.quantity.toInt() - available;
        return {'itemId': itemId, 'backorderedQuantity': missing};
      }).toList();
    }

    final isInCollectionToPartial =
        _selected!.from == OrderStatus.IN_COLLECTION &&
        _selected!.to == OrderStatus.PARTIAL;

    if (isInCollectionToPartial) {
      // Send item-level backorder declarations before the transition.
      for (final itemId in _selectedBackorderedItemIds) {
        final item = widget.order.items.firstWhere((i) => i.id == itemId);
        final available = int.parse(
          _backorderedQuantityControllers[itemId]!.text.trim(),
        );
        final missing = item.quantity.toInt() - available;
        final itemSuccess = await provider.updateOrderItem(
          orderId: widget.order.id,
          itemId: itemId,
          status: ItemStatus.BACKORDERED.name.toLowerCase(),
          backorderedQuantity: missing.toDouble(),
        );
        if (!itemSuccess) {
          _showError(provider.error ?? 'Failed to declare backordered item.');
          provider.clearError();
          setState(() => _submitting = false);
          return;
        }
      }
    }

    // Ensure pickers include their id as pickerId in the request so the
    // server can validate assigned-picker transitions even when the
    // transition definition doesn't require an explicit pickerId.
    final effectivePickerId = _selected!.requiresPickerId
      ? _selectedPicker!.id
      : (widget.currentUser.role == UserRole.PICKER
        ? widget.currentUser.id
        : null);

    final success = await provider.performTransition(
      orderId: widget.order.id,
      nextStatus: _selected!.to,
      pickerId: effectivePickerId,
      trolleyId: _selected!.requiresTrolleyId
        ? _trolleyIdController.text.trim()
        : null,
      backorderedItems: isInCollectionToPartial
        ? null
        : backorderedItemsPayload,
      arrivedItemIds: _selected!.requiresArrivedItemIds
        ? _selectedArrivedItemIds.toList()
        : null,
      notes: _notesController.text.trim().isNotEmpty
        ? _notesController.text.trim()
        : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      setState(() => _errorMessage = null);
      Navigator.of(context).pop();
    } else {
      _showError(provider.error ?? 'Transition failed.');
      provider.clearError();
    }
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
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

            if (_errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF2C0C0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 20,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB71C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

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
                        'Statusni tanlang',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),

                      // Transition options
                      ...transitions.map(
                        (t) => _TransitionOption(
                          definition: t,
                          selected: _selected == t,
                          onTap: () => setState(() {
                            _errorMessage = null;
                            _selected = t;
                            _selectedBackorderedItemIds.clear();
                            _selectedArrivedItemIds.clear();
                            for (final controller
                                in _backorderedQuantityControllers.values) {
                              controller.dispose();
                            }
                            _backorderedQuantityControllers.clear();
                            if (t.requiresArrivedItemIds) {
                              _selectedArrivedItemIds.addAll(
                                widget.order.items
                                    .where(
                                      (i) => i.status == ItemStatus.BACKORDERED,
                                    )
                                    .map((i) => i.id),
                              );
                            }
                          }),
                        ),
                      ),

                      // const SizedBox(height: 18),

                      // if (_selected != null) ...[
                      //   Container(
                      //     width: double.infinity,
                      //     padding: const EdgeInsets.all(14),
                      //     decoration: BoxDecoration(
                      //       color: AppTheme.surfaceVariant,
                      //       borderRadius: BorderRadius.circular(16),
                      //       border: Border.all(color: AppTheme.border),
                      //     ),
                      //     child: Column(
                      //       crossAxisAlignment: CrossAxisAlignment.start,
                      //       children: [
                      //         Text(
                      //           _selected!.requiresBackorderedItems
                      //               ? 'Tayyor qilish uchun yetishmayotgan mahsulotlarni tanlang.'
                      //               : _selected!.requiresArrivedItemIds
                      //               ? 'Tayyor qilish uchun barcha backordered mahsulotlar mavjud bo‘lishi kerak.'
                      //               : 'Bu holatga o‘tish uchun qo‘shimcha ma’lumot kerak emas.',
                      //           style: Theme.of(context).textTheme.bodyMedium
                      //               ?.copyWith(
                      //                 color: AppTheme.onSurface,
                      //                 height: 1.4,
                      //               ),
                      //         ),
                      //         if (_selected!.requiresBackorderedItems) ...[
                      //           const SizedBox(height: 12),
                      //           Row(
                      //             children: [
                      //               Container(
                      //                 padding: const EdgeInsets.all(8),
                      //                 decoration: BoxDecoration(
                      //                   shape: BoxShape.circle,
                      //                   color: const Color(0xFFDDEEFF),
                      //                 ),
                      //                 child: const Icon(
                      //                   Icons.check,
                      //                   size: 16,
                      //                   color: Color(0xFF1E88E5),
                      //                 ),
                      //               ),
                      //               const SizedBox(width: 10),
                      //               Expanded(
                      //                 child: Text(
                      //                   'Backordered mahsulotlar soni: ${_selectedBackorderedItemIds.length}',
                      //                   style: Theme.of(context)
                      //                       .textTheme
                      //                       .bodyMedium
                      //                       ?.copyWith(
                      //                         fontWeight: FontWeight.w600,
                      //                       ),
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //         ],
                      //       ],
                      //     ),
                      //   ),
                      //   const SizedBox(height: 16),
                      // ],

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
                                initialValue: _selectedPicker,
                                decoration: const InputDecoration(
                                  labelText: 'Picker ni tanlang *',
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
                                          '${picker.username} (${picker.activeAssignmentsCount} ta faol)',
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
                            labelText: 'Arava ID *',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                            hintText: 'Arava ID kiriting',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_selected?.requiresArrivedItemIds == true) ...[
                        Text(
                          'Barcha backordered mahsulotlar mavjud bo‘lishi kerak.',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 140),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: widget.order.items
                                .where(
                                  (i) => i.status == ItemStatus.BACKORDERED,
                                )
                                .length,
                            itemBuilder: (context, index) {
                              final item = widget.order.items
                                  .where(
                                    (i) => i.status == ItemStatus.BACKORDERED,
                                  )
                                  .toList()[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                leading: const Icon(
                                  Icons.check_circle_outline,
                                  color: Color(0xFF4338CA),
                                ),
                                title: Text(item.productName),
                                subtitle: Text(
                                  'Miqdor: ${item.quantity.toInt()} dona',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_selected?.requiresBackorderedItems == true) ...[
                        Text(
                          'BOR MAHSULOTLAR',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            children: List.generate(widget.order.items.length, (
                              index,
                            ) {
                              final item = widget.order.items[index];
                              final isSelected = _selectedBackorderedItemIds
                                  .contains(item.id);
                              final controller = _backorderedQuantityControllers
                                  .putIfAbsent(
                                    item.id,
                                    () => TextEditingController(
                                      text: (item.quantity.toInt() - 1)
                                          .clamp(0, item.quantity.toInt())
                                          .toString(),
                                    ),
                                  );
                              return Column(
                                children: [
                                  CheckboxListTile(
                                    title: Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Kerak: ${item.quantity.toInt()} dona',
                                    ),
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedBackorderedItemIds.add(
                                            item.id,
                                          );
                                        } else {
                                          _selectedBackorderedItemIds.remove(
                                            item.id,
                                          );
                                        }
                                      });
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  if (isSelected) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        16,
                                      ),
                                      child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3F4F6),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: const Icon(
                                                      Icons.remove,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      int current =
                                                          int.tryParse(
                                                            controller.text,
                                                          ) ??
                                                          0;
                                                      int next = current - 1;
                                                      final min = 0;
                                                      final max = item.quantity
                                                          .toInt();
                                                      if (next < min) {
                                                        next = min;
                                                      }
                                                      if (next > max) {
                                                        next = max;
                                                      }
                                                      controller.text = next
                                                          .toString();
                                                      setState(() {});
                                                    },
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    width: 36,
                                                    child: Text(
                                                      controller.text,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: const Icon(
                                                      Icons.add,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      int current =
                                                          int.tryParse(
                                                            controller.text,
                                                          ) ??
                                                          1;
                                                      int next = current + 1;
                                                      final min = 1;
                                                      final max = item.quantity
                                                          .toInt();
                                                      if (next < min) {
                                                        next = min;
                                                      }
                                                      if (next > max) {
                                                        next = max;
                                                      }
                                                      controller.text = next
                                                          .toString();
                                                      setState(() {});
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                      
                                      
                                      // Container(
                                      //   padding: const EdgeInsets.symmetric(
                                      //     horizontal: 12,
                                      //     vertical: 10,
                                      //   ),
                                      //   decoration: BoxDecoration(
                                      //     color: Colors.white,
                                      //     borderRadius: BorderRadius.circular(
                                      //       14,
                                      //     ),
                                      //     border: Border.all(
                                      //       color: const Color(0xFFE5E7EB),
                                      //     ),
                                      //   ),
                                      //   child: Row(
                                      //     children: [
                                      //       // Expanded(
                                      //       //   child: Column(
                                      //       //     crossAxisAlignment:
                                      //       //         CrossAxisAlignment.start,
                                      //       //     children: [
                                      //       //       // Text(
                                      //       //       //   'Yetishmayotgan soni',
                                      //       //       //   style: Theme.of(
                                      //       //       //     context,
                                      //       //       //   ).textTheme.bodyMedium,
                                      //       //       // ),
                                      //       //       const SizedBox(height: 6),
                                      //       //       Text(
                                      //       //         'Mavjud:',
                                      //       //         style: Theme.of(context)
                                      //       //             .textTheme
                                      //       //             .bodySmall
                                      //       //             ?.copyWith(
                                      //       //               color: AppTheme
                                      //       //                   .onSurfaceMuted,
                                      //       //             ),
                                      //       //       ),
                                      //       //     ],
                                      //       //   ),
                                      //       // ),
                                      //       // const SizedBox(width: 12),
                                      //     ],
                                      //   ),
                                      // ),
                                    ),
                                  ],
                                ],
                              );
                            }),
                          ),
                        ),
                        // const SizedBox(height: 16),
                        // Container(
                        //   padding: const EdgeInsets.symmetric(
                        //     horizontal: 16,
                        //     vertical: 14,
                        //   ),
                        //   decoration: BoxDecoration(
                        //     color: const Color(0xFFF7F9FF),
                        //     borderRadius: BorderRadius.circular(16),
                        //   ),
                        //   child: Row(
                        //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //     children: [
                        //       Column(
                        //         crossAxisAlignment: CrossAxisAlignment.start,
                        //         children: [
                        //           Text(
                        //             'Tanlangan mahsulotlar',
                        //             style: Theme.of(context).textTheme.bodySmall
                        //                 ?.copyWith(
                        //                   color: AppTheme.onSurfaceMuted,
                        //                 ),
                        //           ),
                        //           const SizedBox(height: 4),
                        //           Text(
                        //             '${_selectedBackorderedItemIds.length} tur',
                        //             style: const TextStyle(
                        //               fontWeight: FontWeight.w700,
                        //               fontSize: 14,
                        //             ),
                        //           ),
                        //         ],
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        const SizedBox(height: 16),
                      ], // Submit
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _selected == null || _submitting
                              ? null
                              : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
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
                                          ? '${_selected!.to.displayNameUz} holatiga o‘tkazish'
                                          : 'Holatni tanlang',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'Bekor qilish',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6366F1),
                            ),
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
              ? toStatus.color.withAlpha((0.12 * 255).round())
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
                  const SizedBox(height: 4),
                  Text(
                    _statusDescription(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.onSurfaceMuted,
                    ),
                  ),
                  if (definition.requiresPickerId ||
                      definition.requiresPaid ||
                      definition.requiresArrivedItemIds)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _requirementText(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceMuted,
                        ),
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

  String _statusDescription() {
    switch (definition.to) {
      case OrderStatus.READY:
        return 'Barcha mahsulotlar mavjud';
      case OrderStatus.PARTIAL:
        return 'Ba’zi mahsulotlar yetishmayapti';
      case OrderStatus.CANCELLED:
        return 'Buyurtma bekor qilinadi';
      case OrderStatus.IN_COLLECTION:
        return 'Yig‘ish jarayonida';
      case OrderStatus.CONFIRMED:
        return 'Buyurtma tasdiqlangan';
      default:
        return '';
    }
  }

  String _requirementText() {
    final parts = <String>[];
    if (definition.requiresPickerId) parts.add('Picker tanlash kerak');
    if (definition.requiresTrolleyId) parts.add('Arava ID kerak');
    if (definition.requiresBackorderedItems) {
      parts.add('Yetishmayotgan miqdor kerak');
    }
    if (definition.requiresPaid) parts.add('Buyurtma PAID bo‘lishi kerak');
    if (definition.requiresArrivedItemIds) {
      parts.add('Barcha backordered mahsulotlar yetishi kerak');
    }
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
        color: status.color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: status.color.withAlpha((0.4 * 255).round())),
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
