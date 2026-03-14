import 'package:flutter/material.dart';
import '../../models/pool_model.dart';
import '../../models/shared_expense_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddSharedExpenseSheet extends StatefulWidget {
  final PoolModel pool;
  final double? prefilledAmount;
  final String? prefilledDescription;
  /// If editing, pass the existing expense here.
  final SharedExpenseModel? existingExpense;

  const AddSharedExpenseSheet({
    super.key,
    required this.pool,
    this.prefilledAmount,
    this.prefilledDescription,
    this.existingExpense,
  });

  @override
  State<AddSharedExpenseSheet> createState() => _AddSharedExpenseSheetState();
}

class _AddSharedExpenseSheetState extends State<AddSharedExpenseSheet> {
  final _descController   = TextEditingController();
  final _amountController = TextEditingController();

  String _paidByUid = '';
  String _splitType = 'Equal'; // Equal, Exact, Percentage

  Map<String, double> _splitValues     = {};
  Set<String>         _selectedParticipants = {};
  final Map<String, TextEditingController> _controllers = {};

  Map<String, String> _memberNames      = {};
  bool _isLoadingMembers = true;
  bool _isSaving         = false;

  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();

    final ex = widget.existingExpense;

    _paidByUid = ex?.paidBy ??
        FirebaseAuth.instance.currentUser?.uid ?? '';

    // Prefill from existing expense
    _descController.text = ex?.description ??
        widget.prefilledDescription ?? '';

    if (ex != null) {
      _amountController.text = ex.amount.toStringAsFixed(2);
      _selectedParticipants  = Set.from(ex.splits.keys);
    } else {
      if (widget.prefilledAmount != null) {
        _amountController.text = widget.prefilledAmount!.toStringAsFixed(2);
      }
      _selectedParticipants = Set.from(widget.pool.members);
    }

    for (String uid in widget.pool.members) {
      _splitValues[uid]  = ex?.splits[uid] ?? 0.0;
      _controllers[uid]  = TextEditingController(
        text: ex != null ? (ex.splits[uid] ?? 0.0).toStringAsFixed(2) : '',
      );
    }

    // Guess split type from loaded expense
    if (ex != null) {
      _splitType = 'Exact';
    }

    _amountController.addListener(_onAmountChanged);
    _loadMemberNames();
  }

  Future<void> _loadMemberNames() async {
    for (String uid in widget.pool.members) {
      UserModel? user = await FirestoreService().getUser(uid);
      if (mounted) {
        setState(() {
          _memberNames[uid] = user != null && user.displayName.isNotEmpty
              ? user.displayName
              : 'User ($uid)';
        });
      }
    }
    if (mounted) setState(() => _isLoadingMembers = false);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _descController.dispose();
    _amountController.dispose();
    for (var c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  void _onAmountChanged() {
    if (_splitType == 'Equal') return;
    _recalculateSplits();
  }

  void _recalculateSplits() {
    if (_selectedParticipants.isEmpty) return;
    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (_splitType == 'Exact') {
      double splitAmount = totalAmount / _selectedParticipants.length;
      for (var uid in widget.pool.members) {
        if (_selectedParticipants.contains(uid)) {
          _splitValues[uid] = splitAmount;
          _controllers[uid]!.text = splitAmount.toStringAsFixed(2);
        } else {
          _splitValues[uid] = 0.0;
          _controllers[uid]!.text = '0.00';
        }
      }
    } else if (_splitType == 'Percentage') {
      double splitPercent = 100.0 / _selectedParticipants.length;
      for (var uid in widget.pool.members) {
        if (_selectedParticipants.contains(uid)) {
          _splitValues[uid] = splitPercent;
          _controllers[uid]!.text = splitPercent.toStringAsFixed(2);
        } else {
          _splitValues[uid] = 0.0;
          _controllers[uid]!.text = '0.00';
        }
      }
    }
    setState(() {});
  }

  void _onSplitValueChanged(String changedUid, String value) {
    if (_splitType == 'Equal') return;

    double val = double.tryParse(value) ?? 0.0;
    _splitValues[changedUid] = val;

    List<String> active = _selectedParticipants.toList();
    if (active.length > 1) {
      int changedIndex = active.indexOf(changedUid);
      if (changedIndex != -1) {
        int targetIndex  = (changedIndex + 1) % active.length;
        String targetUid = active[targetIndex];

        double currentTotal = 0;
        if (_splitType == 'Exact') {
          double maxTotal = double.tryParse(_amountController.text) ?? 0.0;
          for (String uid in active) {
            if (uid != targetUid) currentTotal += _splitValues[uid] ?? 0;
          }
          double remainder = (maxTotal - currentTotal).clamp(0.0, double.infinity);
          _splitValues[targetUid] = remainder;
          _controllers[targetUid]!.text = remainder.toStringAsFixed(2);
        } else if (_splitType == 'Percentage') {
          for (String uid in active) {
            if (uid != targetUid) currentTotal += _splitValues[uid] ?? 0;
          }
          double remainder = (100.0 - currentTotal).clamp(0.0, double.infinity);
          _splitValues[targetUid] = remainder;
          _controllers[targetUid]!.text = remainder.toStringAsFixed(2);
        }
      }
    }
  }

  Future<void> _saveExpense() async {
    if (_descController.text.trim().isEmpty ||
        _amountController.text.trim().isEmpty) return;

    double totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (totalAmount <= 0) return;

    setState(() => _isSaving = true);

    Map<String, double> finalSplits = {};

    try {
      if (_selectedParticipants.isEmpty) {
        throw Exception('Please select at least one participant.');
      }

      if (_splitType == 'Equal') {
        double splitAmount = totalAmount / _selectedParticipants.length;
        for (String uid in widget.pool.members) {
          if (_selectedParticipants.contains(uid)) {
            finalSplits[uid] = splitAmount;
          }
        }
      } else if (_splitType == 'Exact') {
        double sum = 0;
        _splitValues.forEach((key, value) {
          if (_selectedParticipants.contains(key)) sum += value;
        });
        if ((sum - totalAmount).abs() > 0.1) {
          throw Exception('Exact amounts must sum to ₹$totalAmount. Current: ₹$sum');
        }
        for (String uid in _selectedParticipants) {
          finalSplits[uid] = _splitValues[uid] ?? 0.0;
        }
      } else if (_splitType == 'Percentage') {
        double sum = 0;
        _splitValues.forEach((key, value) {
          if (_selectedParticipants.contains(key)) sum += value;
        });
        if ((sum - 100).abs() > 0.1) {
          throw Exception('Percentages must sum to 100%. Current: $sum%');
        }
        for (String uid in _selectedParticipants) {
          finalSplits[uid] = totalAmount * (_splitValues[uid]! / 100.0);
        }
      }

      if (_isEditing) {
        final updated = SharedExpenseModel(
          id:          widget.existingExpense!.id,
          poolId:      widget.existingExpense!.poolId,
          description: _descController.text.trim(),
          amount:      totalAmount,
          paidBy:      _paidByUid,
          date:        widget.existingExpense!.date, // keep original date
          splits:      finalSplits,
        );
        await FirestoreService().updateSharedExpense(
          updated, widget.existingExpense!.amount);
      } else {
        final expense = SharedExpenseModel(
          id:          '',
          poolId:      widget.pool.id,
          description: _descController.text.trim(),
          amount:      totalAmount,
          paidBy:      _paidByUid,
          date:        DateTime.now(),
          splits:      finalSplits,
        );
        await FirestoreService().addSharedExpense(expense);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMembers) {
      return Container(
        height: 300,
        decoration: const BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28), topRight: Radius.circular(28)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              _isEditing ? 'Edit Expense' : 'Add Shared Expense',
              style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold,
                color: AppColors.darkBlue),
            ),
            const SizedBox(height: 20),

            // Description
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                hintText: 'What was it for? (e.g. Dinner)',
                prefixIcon: Icon(Icons.receipt_long_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'Total Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
            ),
            const SizedBox(height: 20),

            // Paid By
            const Text('Paid by',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkBlue)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _paidByUid,
                  isExpanded: true,
                  items: widget.pool.members.map((uid) {
                    return DropdownMenuItem(
                      value: uid,
                      child: Text(_memberNames[uid] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _paidByUid = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // For whom?
            const Text('For whom?',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkBlue)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.pool.members.map((uid) {
                final isSelected = _selectedParticipants.contains(uid);
                return FilterChip(
                  label: Text(_memberNames[uid] ?? 'Unknown'),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue.withAlpha(40),
                  checkmarkColor: AppColors.primaryBlue,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primaryBlue : AppColors.textDark,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedParticipants.add(uid);
                      } else {
                        _selectedParticipants.remove(uid);
                      }
                      _recalculateSplits();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Split type
            const Text('How to split?',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkBlue)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Equal', label: Text('Equally', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 'Exact', label: Text('Exact Amt', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 'Percentage', label: Text('Percentage', style: TextStyle(fontSize: 12))),
              ],
              selected: {_splitType},
              onSelectionChanged: (val) {
                setState(() => _splitType = val.first);
                _recalculateSplits();
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primaryBlue.withAlpha(20),
                selectedForegroundColor: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),

            // Manual split inputs (when not Equal)
            if (_splitType != 'Equal')
              ...widget.pool.members
                  .where((uid) => _selectedParticipants.contains(uid))
                  .map((uid) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(_memberNames[uid] ?? 'Unknown')),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _controllers[uid],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixIcon: _splitType == 'Exact'
                                ? const Icon(Icons.currency_rupee_rounded, size: 16)
                                : null,
                            suffixIcon: _splitType == 'Percentage'
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: Text('%'))
                                : null,
                            isDense: true,
                          ),
                          onChanged: (val) => _onSplitValueChanged(uid, val),
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveExpense,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: AppColors.pureWhite,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      _isEditing
                          ? 'Save Changes'
                          : 'Save Shared Expense',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
