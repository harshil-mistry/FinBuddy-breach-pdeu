import 'package:flutter/material.dart';
import '../../models/pool_model.dart';
import '../../models/shared_expense_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/debt_simplifier.dart';

class SettleUpScreen extends StatefulWidget {
  final PoolModel pool;

  const SettleUpScreen({super.key, required this.pool});

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
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
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: const Text('Settle Payments', style: TextStyle(color: AppColors.darkBlue, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkBlue),
      ),
      body: _isLoadingMembers
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<SharedExpenseModel>>(
              stream: FirestoreService().getSharedExpenses(widget.pool.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final expenses = snapshot.data ?? [];
                
                if (expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 80, color: AppColors.successGreen.withAlpha(100)),
                        const SizedBox(height: 16),
                        const Text('No debts to settle!', style: TextStyle(color: AppColors.textLight, fontSize: 16)),
                      ],
                    ),
                  );
                }

                // Run the debt simplification algorithm
                final transfers = DebtSimplifier.calculateSettlements(expenses);

                if (transfers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 80, color: AppColors.successGreen.withAlpha(200)),
                        const SizedBox(height: 16),
                        const Text('Everyone is fully settled up!', style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primaryBlue.withAlpha(30)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlue, size: 30),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Optimized Settlements', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.darkBlue)),
                                  const SizedBox(height: 4),
                                  const Text('We calculated the minimum number of transactions needed.', style: TextStyle(fontSize: 12, color: AppColors.textDark)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Who owes whom:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.darkBlue),
                      ),
                      const SizedBox(height: 16),
                      ...transfers.map((t) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.darkBlue.withAlpha(10),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _memberNames[t.from] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.errorRed),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(Icons.arrow_forward_rounded, color: AppColors.textLight, size: 20),
                              ),
                              Expanded(
                                child: Text(
                                  _memberNames[t.to] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.successGreen),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '₹${t.amount.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlue),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
