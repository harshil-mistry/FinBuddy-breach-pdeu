import 'package:flutter/material.dart';
import '../../models/pool_model.dart';
import '../../models/shared_expense_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'add_expense_sheet.dart';

class ExpenseDetailSheet extends StatefulWidget {
  final SharedExpenseModel expense;
  final PoolModel pool;

  const ExpenseDetailSheet({super.key, required this.expense, required this.pool});

  @override
  State<ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends State<ExpenseDetailSheet> {
  Map<String, String> _memberNames = {};
  bool _isLoadingMembers = true;

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy - h:mm a').format(widget.expense.date);
    final paidByName = _memberNames[widget.expense.paidBy] ?? 'Loading...';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: _isLoadingMembers
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppColors.borderLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title & Date
                    Text(
                      widget.expense.description,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 24,
                            color: AppColors.darkBlue,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 14, color: AppColors.textLight),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Amount
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          const Text('Total Amount', style: TextStyle(color: AppColors.textLight, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(
                            '₹${widget.expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.darkBlue),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.account_circle_rounded, size: 20, color: AppColors.primaryBlue),
                              const SizedBox(width: 8),
                              Text(
                                'Paid by $paidByName',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Splits exactly
                    const Text(
                      'Split Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkBlue),
                    ),
                    const SizedBox(height: 16),
                    ...widget.expense.splits.entries.map((entry) {
                      final uid = entry.key;
                      final splitAmount = entry.value;
                      final name = _memberNames[uid] ?? 'Loading...';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.pureWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.lightBlue,
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 14, color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
                                ),
                              ],
                            ),
                            Text(
                              '₹${splitAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.errorRed),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: AppColors.pureWhite,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Close',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Edit button
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // close detail sheet
                            await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => AddSharedExpenseSheet(
                                pool: widget.pool,
                                existingExpense: widget.expense,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 18),
                            backgroundColor:
                                AppColors.primaryBlue.withAlpha(20),
                            foregroundColor: AppColors.primaryBlue,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: AppColors.primaryBlue.withAlpha(80)),
                            ),
                          ),
                          child: const Icon(Icons.edit_rounded),
                        ),
                        const SizedBox(width: 10),
                        // Delete button
                        ElevatedButton(
                          onPressed: () => _confirmDelete(context),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 18),
                            backgroundColor:
                                AppColors.errorRed.withAlpha(20),
                            foregroundColor: AppColors.errorRed,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: AppColors.errorRed.withAlpha(80)),
                            ),
                          ),
                          child: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Expense', style: TextStyle(color: AppColors.darkBlue, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${widget.expense.description}"? This will update the pool balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // close sheet
              try {
                await FirestoreService().deleteSharedExpense(widget.expense);
              } catch (e) {
                // Error silently as screen is already closed
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
