import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/day_selector.dart';

class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: StreamBuilder<UserModel?>(
          stream: FirestoreService().getUserStream(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = snapshot.data;
            if (user == null) {
              return const Center(child: Text('User data not found'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recurring',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontSize: 22,
                          color: AppColors.darkBlue,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your fixed monthly income & expenses',
                    style:
                        TextStyle(color: AppColors.textLight, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // ─── Recurring Income ──────────────────────────
                  _buildSectionHeader(
                    context,
                    title: 'Recurring Income',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.successGreen,
                    onAdd: () => _showIncomeSheet(context, user),
                  ),
                  const SizedBox(height: 12),
                  if (user.recurringIncomes.isEmpty)
                    _emptyState('No recurring income set up.'),
                  ...List.generate(user.recurringIncomes.length, (index) {
                    final inc = user.recurringIncomes[index];
                    return _buildTile(
                      icon: Icons.trending_up_rounded,
                      iconColor: AppColors.successGreen,
                      title: inc.source,
                      subtitle:
                          '₹${inc.amount.toStringAsFixed(0)} · Day ${inc.dayOfMonth}',
                      onTap: () =>
                          _showIncomeSheet(context, user, editIndex: index),
                      onDelete: () => _deleteIncome(context, user, index),
                    );
                  }),
                  const SizedBox(height: 28),

                  // ─── Recurring Expenses ───────────────────────
                  _buildSectionHeader(
                    context,
                    title: 'Recurring Expenses',
                    icon: Icons.trending_down_rounded,
                    color: AppColors.errorRed,
                    onAdd: () => _showExpenseSheet(context, user),
                  ),
                  const SizedBox(height: 12),
                  if (user.recurringExpenses.isEmpty)
                    _emptyState('No recurring expenses set up.'),
                  ...List.generate(user.recurringExpenses.length, (index) {
                    final exp = user.recurringExpenses[index];
                    return _buildTile(
                      icon: Icons.trending_down_rounded,
                      iconColor: AppColors.errorRed,
                      title: exp.name,
                      subtitle:
                          '₹${exp.amount.toStringAsFixed(0)} · ${exp.tag} · Day ${exp.dayOfMonth}',
                      onTap: () =>
                          _showExpenseSheet(context, user, editIndex: index),
                      onDelete: () => _deleteExpense(context, user, index),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onAdd}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkBlue,
            ),
          ),
        ),
        IconButton(
          onPressed: onAdd,
          icon: Icon(Icons.add_circle_outline_rounded, color: color),
          tooltip: 'Add $title',
        ),
      ],
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textLight, fontSize: 14),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.textLight),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.errorRed),
          ),
        ],
      ),
    );
  }

  void _showIncomeSheet(BuildContext context, UserModel user, {int? editIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IncomeSheet(user: user, editIndex: editIndex),
    );
  }

  void _showExpenseSheet(BuildContext context, UserModel user, {int? editIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseSheet(user: user, editIndex: editIndex),
    );
  }

  void _deleteIncome(BuildContext context, UserModel user, int index) {
    final incomes = List<RecurringIncome>.from(user.recurringIncomes);
    incomes.removeAt(index);
    FirestoreService().updateRecurringIncomes(user.uid, incomes);
  }

  void _deleteExpense(BuildContext context, UserModel user, int index) {
    final expenses = List<RecurringExpense>.from(user.recurringExpenses);
    expenses.removeAt(index);
    FirestoreService().updateRecurringExpenses(user.uid, expenses);
  }
}

// ─── Income Sheet ────────────────────────────────────────────────
class _IncomeSheet extends StatefulWidget {
  final UserModel user;
  final int? editIndex;

  const _IncomeSheet({required this.user, this.editIndex});

  @override
  State<_IncomeSheet> createState() => _IncomeSheetState();
}

class _IncomeSheetState extends State<_IncomeSheet> {
  final _sourceController = TextEditingController();
  final _amountController = TextEditingController();
  int _dayOfMonth = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editIndex != null) {
      final inc = widget.user.recurringIncomes[widget.editIndex!];
      _sourceController.text = inc.source;
      _amountController.text = inc.amount.toStringAsFixed(0);
      _dayOfMonth = inc.dayOfMonth;
    }
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_sourceController.text.isEmpty || _amountController.text.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final income = RecurringIncome(
        source: _sourceController.text.trim(),
        amount: amount,
        dayOfMonth: _dayOfMonth,
      );

      final incomes = List<RecurringIncome>.from(widget.user.recurringIncomes);
      if (widget.editIndex != null) {
        incomes[widget.editIndex!] = income;
      } else {
        incomes.add(income);
      }

      await FirestoreService().updateRecurringIncomes(widget.user.uid, incomes);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheetWrapper(
      title: widget.editIndex == null ? 'Add Recurring Income' : 'Edit Recurring Income',
      isSaving: _isSaving,
      onSave: _save,
      children: [
        TextField(
          controller: _sourceController,
          decoration: const InputDecoration(
            hintText: 'Source (e.g., Salary)',
            prefixIcon: Icon(Icons.work_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Amount (₹)',
            prefixIcon: Icon(Icons.currency_rupee_rounded),
          ),
        ),
        const SizedBox(height: 12),
        DaySelector(
          selectedDay: _dayOfMonth,
          onDaySelected: (val) => setState(() => _dayOfMonth = val),
        ),
      ],
    );
  }
}

// ─── Expense Sheet ───────────────────────────────────────────────
class _ExpenseSheet extends StatefulWidget {
  final UserModel user;
  final int? editIndex;

  const _ExpenseSheet({required this.user, this.editIndex});

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _tag = 'Need';
  int _dayOfMonth = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editIndex != null) {
      final exp = widget.user.recurringExpenses[widget.editIndex!];
      _nameController.text = exp.name;
      _amountController.text = exp.amount.toStringAsFixed(0);
      _tag = exp.tag;
      _dayOfMonth = exp.dayOfMonth;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) return;
    setState(() => _isSaving = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final expense = RecurringExpense(
        name: _nameController.text.trim(),
        amount: amount,
        tag: _tag,
        dayOfMonth: _dayOfMonth,
      );

      final expenses = List<RecurringExpense>.from(widget.user.recurringExpenses);
      if (widget.editIndex != null) {
        expenses[widget.editIndex!] = expense;
      } else {
        expenses.add(expense);
      }

      await FirestoreService().updateRecurringExpenses(widget.user.uid, expenses);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheetWrapper(
      title: widget.editIndex == null ? 'Add Recurring Expense' : 'Edit Recurring Expense',
      isSaving: _isSaving,
      onSave: _save,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Name (e.g., Rent)',
            prefixIcon: Icon(Icons.receipt_long_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Amount (₹)',
            prefixIcon: Icon(Icons.currency_rupee_rounded),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Need', label: Text('Need')),
            ButtonSegment(value: 'Want', label: Text('Want')),
          ],
          selected: {_tag},
          onSelectionChanged: (val) => setState(() => _tag = val.first),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.primaryBlue.withAlpha(30),
            selectedForegroundColor: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 12),
        DaySelector(
          selectedDay: _dayOfMonth,
          onDaySelected: (val) => setState(() => _dayOfMonth = val),
        ),
      ],
    );
  }
}

// ─── Base Sheet Wrapper ──────────────────────────────────────────
class _BaseSheetWrapper extends StatelessWidget {
  final String title;
  final bool isSaving;
  final VoidCallback onSave;
  final List<Widget> children;

  const _BaseSheetWrapper({
    required this.title,
    required this.isSaving,
    required this.onSave,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 20,
                    color: AppColors.darkBlue,
                  ),
            ),
            const SizedBox(height: 20),
            ...children,
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isSaving ? null : onSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }
}
