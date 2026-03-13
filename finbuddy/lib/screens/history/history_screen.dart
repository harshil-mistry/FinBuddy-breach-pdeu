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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                            Text('No transactions yet',
                                style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 15)),
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
                                style: TextStyle(
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
                color:
                    (isExpense ? AppColors.errorRed : AppColors.successGreen)
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
                  Row(
                    children: [
                      Text(t.category,
                          style: TextStyle(
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
          ],
        ),
      ),
    );
  }
}
