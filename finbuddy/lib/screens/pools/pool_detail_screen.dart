import 'package:flutter/material.dart';
import '../../models/pool_model.dart';
import '../../models/shared_expense_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';

import 'invite_screen.dart';
import 'add_expense_sheet.dart';
import 'settle_up_screen.dart';

class PoolDetailScreen extends StatelessWidget {
  final String poolId;

  const PoolDetailScreen({super.key, required this.poolId});

  void _showAddExpenseSheet(BuildContext context, PoolModel pool) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSharedExpenseSheet(pool: pool),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PoolModel?>(
      stream: FirestoreService().getPoolStream(poolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final pool = snapshot.data;
        if (pool == null) {
          return const Scaffold(body: Center(child: Text('Pool not found')));
        }

        return Scaffold(
          backgroundColor: AppColors.backgroundWhite,
          appBar: AppBar(
            backgroundColor: AppColors.backgroundWhite,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.darkBlue),
            title: Text(
              pool.name,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.darkBlue),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => InviteScreen(pool: pool)),
                  );
                },
                icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primaryBlue),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettleUpScreen(pool: pool)),
                  );
                },
                icon: const Icon(Icons.payments_rounded, color: AppColors.successGreen),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Summary Header
              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.darkBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withAlpha(40),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Group Expenses', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      '₹${pool.totalExpenses.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.group_rounded, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Text('${pool.members.length} Members', style: const TextStyle(color: Colors.white70)),
                      ],
                    )
                  ],
                ),
              ),

              // Transactions List
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  ),
                  child: StreamBuilder<List<SharedExpenseModel>>(
                    stream: FirestoreService().getSharedExpenses(poolId),
                    builder: (context, expenseSnapshot) {
                      if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final expenses = expenseSnapshot.data ?? [];

                      if (expenses.isEmpty) {
                        return const Center(child: Text('No expenses yet. Add one!', style: TextStyle(color: AppColors.textLight)));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final ex = expenses[index];
                          final dateStr = DateFormat('MMM d, y').format(ex.date);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.pureWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorRed.withAlpha(20),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded, color: AppColors.errorRed),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ex.description, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text(dateStr, style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Text('₹${ex.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.darkBlue)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primaryBlue,
            onPressed: () => _showAddExpenseSheet(context, pool),
            icon: const Icon(Icons.add_rounded, color: AppColors.pureWhite),
            label: const Text('Add Expense', style: TextStyle(color: AppColors.pureWhite, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}

