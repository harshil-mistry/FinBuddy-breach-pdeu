import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import 'package:intl/intl.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: user == null
            ? const Center(child: Text('Please login to see stats'))
            : StreamBuilder<List<TransactionModel>>(
                stream: FirestoreService().getMonthlyTransactions(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final transactions = snapshot.data ?? [];
                  final expenses = transactions
                      .where((t) => t.type == 'expense' && t.category != 'Settlements')
                      .toList();

                  if (expenses.isEmpty) {
                    return _buildEmptyState();
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statistics',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMMM yyyy').format(DateTime.now()),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSummaryCards(expenses),
                        const SizedBox(height: 24),
                        _buildWantNeedChart(expenses),
                        const SizedBox(height: 24),
                        _buildCategoryChart(expenses),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSummaryCards(List<TransactionModel> expenses) {
    double needTotal = 0;
    double wantTotal = 0;

    for (final t in expenses) {
      if (t.tag == 'Need') {
        needTotal += t.amount;
      } else {
        wantTotal += t.amount;
      }
    }

    final total = needTotal + wantTotal;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Total Spent',
            '₹${total.toStringAsFixed(0)}',
            Icons.account_balance_wallet_rounded,
            AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            'Needs',
            '₹${needTotal.toStringAsFixed(0)}',
            Icons.home_rounded,
            AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            'Wants',
            '₹${wantTotal.toStringAsFixed(0)}',
            Icons.shopping_bag_rounded,
            AppColors.warningOrange,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              size: 48,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No expenses yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add some expenses to see\nyour spending insights here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWantNeedChart(List<TransactionModel> expenses) {
    double needTotal = 0;
    double wantTotal = 0;

    for (final t in expenses) {
      if (t.tag == 'Need') {
        needTotal += t.amount;
      } else {
        wantTotal += t.amount;
      }
    }

    final total = needTotal + wantTotal;
    if (total == 0) return const SizedBox.shrink();

    final needPercent = (needTotal / total * 100).round();
    final wantPercent = (wantTotal / total * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Need vs Want',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 150,
            height: 150,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: AppColors.primaryBlue,
                    value: needTotal,
                    title: '$needPercent%',
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    radius: 50,
                  ),
                  PieChartSectionData(
                    color: AppColors.warningOrange,
                    value: wantTotal,
                    title: '$wantPercent%',
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    radius: 50,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem('Need', '₹${needTotal.toStringAsFixed(0)}', AppColors.primaryBlue),
              const SizedBox(width: 24),
              _legendItem('Want', '₹${wantTotal.toStringAsFixed(0)}', AppColors.warningOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(List<TransactionModel> expenses) {
    final Map<String, double> categoryTotals = {};
    final List<String> mainCategories = [
      'Food & Dining',
      'Transport',
      'Shopping',
      'Entertainment',
      'Groceries',
      'Utilities',
      'Subscriptions',
      'Travel',
      'Settlements',
      'Transfers',
    ];

    for (final t in expenses) {
      if (mainCategories.contains(t.category)) {
        categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
      } else {
        categoryTotals['Other'] = (categoryTotals['Other'] ?? 0) + t.amount;
      }
    }

    if (categoryTotals.isEmpty) return const SizedBox.shrink();

    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = sortedEntries.fold<double>(0, (sum, e) => sum + e.value);

    final colors = [
      const Color(0xFF2A84FF),
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFFFFE66D),
      const Color(0xFF95E1D3),
      const Color(0xFFDDA0DD),
      const Color(0xFF98D8C8),
      const Color(0xFFF7DC6F),
      const Color(0xFF808080),
      const Color(0xFFA0522D),
    ];

    final sections = <PieChartSectionData>[];

    for (var i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final percent = (entry.value / total * 100).round();
      final color = colors[i % colors.length];

      sections.add(PieChartSectionData(
        color: color,
        value: entry.value,
        title: '$percent%',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 50,
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Category Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.darkBlue,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 150,
            height: 150,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < sortedEntries.length; i++)
                _legendItem(
                  sortedEntries[i].key,
                  '₹${sortedEntries[i].value.toStringAsFixed(0)}',
                  colors[i % colors.length],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBlue,
          ),
        ),
      ],
    );
  }
}
