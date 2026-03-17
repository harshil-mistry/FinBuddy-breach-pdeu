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
                      .where((t) => t.type == 'expense')
                      .toList();

                  if (expenses.isEmpty) {
                    return _buildEmptyState();
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statistics',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 22,
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
                        _buildWantNeedChart(expenses),
                        const SizedBox(height: 32),
                        _buildCategoryChart(expenses),
                      ],
                    ),
                  );
                },
              ),
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
            decoration: BoxDecoration(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Need vs Want',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
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
            ),
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendItem('Need', '₹${needTotal.toStringAsFixed(0)}', AppColors.primaryBlue),
                const SizedBox(height: 12),
                _legendItem('Want', '₹${wantTotal.toStringAsFixed(0)}', AppColors.warningOrange),
              ],
            ),
          ],
        ),
      ],
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
      const Color(0xFFBDC3C7),
    ];

    final sections = <PieChartSectionData>[];
    final legendItems = <Widget>[];

    for (var i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final percent = (entry.value / total * 100).round();
      final color = colors[i % colors.length];

      sections.add(PieChartSectionData(
        color: color,
        value: entry.value,
        title: '$percent%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 50,
      ));

      legendItems.add(_legendItem(
        entry.key,
        '₹${entry.value.toStringAsFixed(0)}',
        color,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category Breakdown',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBlue,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: sections,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: legendItems,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
