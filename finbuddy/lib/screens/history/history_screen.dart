import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                'Transaction History',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 22,
                      color: AppColors.darkBlue,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'All your past transactions',
                style: TextStyle(color: AppColors.textLight, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            if (user != null)
              Expanded(
                child: StreamBuilder<List<TransactionModel>>(
                  stream: FirestoreService().getRecentTransactions(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final transactions = snapshot.data ?? [];
                    if (transactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded,
                                size: 56, color: AppColors.borderLight),
                            const SizedBox(height: 12),
                            const Text('No transactions yet',
                                style: TextStyle(
                                    color: AppColors.textLight, fontSize: 15)),
                          ],
                        ),
                      );
                    }

                    // Group by date
                    final Map<String, List<TransactionModel>> grouped = {};
                    for (final t in transactions) {
                      final key = DateFormat('MMM d, yyyy').format(t.date);
                      grouped.putIfAbsent(key, () => []).add(t);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final dateKey = grouped.keys.elementAt(index);
                        final items = grouped[dateKey]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 16, bottom: 8),
                              child: Text(
                                dateKey,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                            ...items.map((t) => _buildTile(context, t)),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, TransactionModel t) {
    final isExpense = t.type == 'expense';
    return Dismissible(
      key: Key(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.errorRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => FirestoreService().deleteTransaction(t.id),
      child: GestureDetector(
        onTap: () => _showEditSheet(context, t),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isExpense
                          ? AppColors.errorRed
                          : AppColors.successGreen)
                      .withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isExpense
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  color:
                      isExpense ? AppColors.errorRed : AppColors.successGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (t.type != 'income')
                      Row(
                        children: [
                          Text(t.category,
                              style: const TextStyle(
                                  color: AppColors.textLight, fontSize: 12)),
                          if (isExpense) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: t.tag == 'Need'
                                    ? AppColors.primaryBlue.withAlpha(20)
                                    : AppColors.warningOrange.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t.tag,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: t.tag == 'Need'
                                      ? AppColors.primaryBlue
                                      : AppColors.warningOrange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              Text(
                '${isExpense ? '-' : '+'}₹${t.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color:
                      isExpense ? AppColors.errorRed : AppColors.successGreen,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, TransactionModel t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTransactionSheet(transaction: t),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Edit Personal Transaction Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditTransactionSheet extends StatefulWidget {
  final TransactionModel transaction;
  const _EditTransactionSheet({required this.transaction});

  @override
  State<_EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<_EditTransactionSheet> {
  late final TextEditingController _descCtrl;
  late final TextEditingController _amountCtrl;
  late String _category;
  late String _type;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _descCtrl   = TextEditingController(text: widget.transaction.description);
    _amountCtrl = TextEditingController(
        text: widget.transaction.amount.toStringAsFixed(2));
    _category   = TransactionModel.allCategories.contains(widget.transaction.category)
        ? widget.transaction.category
        : 'Other';
    _type       = widget.transaction.type;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final desc   = _descCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (desc.isEmpty || amount <= 0) return;

    setState(() => _isSaving = true);
    try {
      final String finalCategory;
      final String finalTag;
      
      if (_category == 'Other') {
        finalCategory = widget.transaction.category;
        finalTag = widget.transaction.tag;
      } else {
        finalCategory = _category;
        finalTag = TransactionModel.getTagForCategory(_category);
      }

      final updated = TransactionModel(
        id:          widget.transaction.id,
        uid:         widget.transaction.uid,
        description: desc,
        amount:      amount,
        category:    finalCategory,
        tag:         finalTag,
        type:        _type,
        poolId:      widget.transaction.poolId,
        date:        widget.transaction.date,
        createdAt:   widget.transaction.createdAt,
      );
      await FirestoreService().updateTransaction(updated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Edit Transaction',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBlue)),
            const SizedBox(height: 20),

            // Description
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                hintText: 'Description',
                prefixIcon: Icon(Icons.receipt_long_rounded),
              ),
            ),
            const SizedBox(height: 16),

            // Amount
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
            ),
            const SizedBox(height: 20),

            // Type
            const Text('Type',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.darkBlue)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income',  label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primaryBlue.withAlpha(20),
                selectedForegroundColor: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),

            // Category (only for expense)
            if (_type == 'expense') ...[
              const Text('Category',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.darkBlue)),
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
                    value: _category,
                    isExpanded: true,
                    items: TransactionModel.allCategories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _category = val);
                    },
                ),
              ),
            ),
            ],
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
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
                  : const Text('Save Changes',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
