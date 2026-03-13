import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ─── Income Form State ──────────────────────────────────────────
  final List<Map<String, dynamic>> _incomes = [];
  final TextEditingController _incomeSourceController = TextEditingController();
  final TextEditingController _incomeAmountController = TextEditingController();
  int _incomeDayOfMonth = 1;

  // ─── Expense Form State ─────────────────────────────────────────
  final List<Map<String, dynamic>> _expenses = [];
  final TextEditingController _expenseNameController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();
  String _selectedExpenseTag = 'Need';
  int _expenseDayOfMonth = 1;

  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _incomeSourceController.dispose();
    _incomeAmountController.dispose();
    _expenseNameController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _addIncome() {
    if (_incomeSourceController.text.isEmpty ||
        _incomeAmountController.text.isEmpty) return;
    setState(() {
      _incomes.add({
        'source': _incomeSourceController.text.trim(),
        'amount': double.tryParse(_incomeAmountController.text) ?? 0,
        'dayOfMonth': _incomeDayOfMonth,
      });
      _incomeSourceController.clear();
      _incomeAmountController.clear();
      _incomeDayOfMonth = 1;
    });
  }

  void _removeIncome(int index) {
    setState(() => _incomes.removeAt(index));
  }

  void _addExpense() {
    if (_expenseNameController.text.isEmpty ||
        _expenseAmountController.text.isEmpty) return;
    setState(() {
      _expenses.add({
        'name': _expenseNameController.text.trim(),
        'amount': double.tryParse(_expenseAmountController.text) ?? 0,
        'tag': _selectedExpenseTag,
        'dayOfMonth': _expenseDayOfMonth,
      });
      _expenseNameController.clear();
      _expenseAmountController.clear();
      _selectedExpenseTag = 'Need';
      _expenseDayOfMonth = 1;
    });
  }

  void _removeExpense(int index) {
    setState(() => _expenses.removeAt(index));
  }

  Future<void> _completeSetup() async {
    setState(() => _isSaving = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = FirestoreService();
      final uid = authService.currentUser?.uid;

      if (uid == null) return;

      final recurringIncomes = _incomes
          .map((e) => RecurringIncome(
                source: e['source'],
                amount: e['amount'],
                dayOfMonth: e['dayOfMonth'],
              ))
          .toList();

      final recurringExpenses = _expenses
          .map((e) => RecurringExpense(
                name: e['name'],
                amount: e['amount'],
                tag: e['tag'],
                dayOfMonth: e['dayOfMonth'],
              ))
          .toList();

      await firestoreService.completeOnboarding(
        uid: uid,
        incomes: recurringIncomes,
        expenses: recurringExpenses,
      );

      // Refresh user data in AuthService
      await authService.refreshUserData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving setup: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: index <= _currentPage
                            ? AppColors.primaryBlue
                            : AppColors.borderLight,
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                children: [
                  _buildWelcomePage(),
                  _buildIncomePage(),
                  _buildExpensePage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Page 1: Welcome / Tutorial ─────────────────────────────────
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 64,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to FinBuddy!',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 28,
                  color: AppColors.darkBlue,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Let\'s set up your finances in 2 quick steps.\n\n'
            '📌 Add your monthly income sources\n'
            '📌 Add your fixed monthly expenses\n\n'
            'This helps FinBuddy auto-track your money\n'
            'so you don\'t have to think about it!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          _buildBottomButton('Let\'s Go!', _nextPage),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── Page 2: Recurring Incomes ──────────────────────────────────
  Widget _buildIncomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'Step 1: Monthly Income',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.darkBlue,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your recurring monthly income. E.g., salary, stipend, allowance.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          // Input Form
          _buildInputCard(
            children: [
              TextField(
                controller: _incomeSourceController,
                decoration: const InputDecoration(
                  hintText: 'Source (e.g., Salary)',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _incomeAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Day of month: ',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _incomeDayOfMonth,
                    items: List.generate(
                        28,
                        (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1}'),
                            )),
                    onChanged: (val) =>
                        setState(() => _incomeDayOfMonth = val ?? 1),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _addIncome,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Income list
          Expanded(
            child: _incomes.isEmpty
                ? Center(
                    child: Text(
                      'No income added yet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: _incomes.length,
                    itemBuilder: (context, index) {
                      final item = _incomes[index];
                      return _buildListTile(
                        icon: Icons.trending_up_rounded,
                        iconColor: AppColors.successGreen,
                        title: item['source'],
                        subtitle:
                            '₹${item['amount'].toStringAsFixed(0)} · Day ${item['dayOfMonth']}',
                        onDelete: () => _removeIncome(index),
                      );
                    },
                  ),
          ),
          // Nav buttons
          _buildNavRow(onBack: _prevPage, onNext: _nextPage),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Page 3: Recurring Expenses ─────────────────────────────────
  Widget _buildExpensePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            'Step 2: Fixed Expenses',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.darkBlue,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your recurring monthly expenses. E.g., rent, subscriptions, EMIs.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildInputCard(
            children: [
              TextField(
                controller: _expenseNameController,
                decoration: const InputDecoration(
                  hintText: 'Name (e.g., Rent)',
                  prefixIcon: Icon(Icons.receipt_long_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _expenseAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Tag selector
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Need', label: Text('Need')),
                      ButtonSegment(value: 'Want', label: Text('Want')),
                    ],
                    selected: {_selectedExpenseTag},
                    onSelectionChanged: (val) =>
                        setState(() => _selectedExpenseTag = val.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor:
                          AppColors.primaryBlue.withAlpha(30),
                      selectedForegroundColor: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Day of month: ',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _expenseDayOfMonth,
                    items: List.generate(
                        28,
                        (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('${i + 1}'),
                            )),
                    onChanged: (val) =>
                        setState(() => _expenseDayOfMonth = val ?? 1),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _addExpense,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _expenses.isEmpty
                ? Center(
                    child: Text(
                      'No expenses added yet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final item = _expenses[index];
                      return _buildListTile(
                        icon: Icons.trending_down_rounded,
                        iconColor: AppColors.errorRed,
                        title: item['name'],
                        subtitle:
                            '₹${item['amount'].toStringAsFixed(0)} · ${item['tag']} · Day ${item['dayOfMonth']}',
                        onDelete: () => _removeExpense(index),
                      );
                    },
                  ),
          ),
          // Finish / Back
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _buildNavRow(
                  onBack: _prevPage,
                  onNext: _completeSetup,
                  nextLabel: 'Finish Setup ✓',
                ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Shared Widgets ─────────────────────────────────────────────

  Widget _buildBottomButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.pureWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildNavRow({
    required VoidCallback onBack,
    required VoidCallback onNext,
    String nextLabel = 'Next',
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.borderLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.pureWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(nextLabel,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: AppColors.textLight, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.textLight,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
