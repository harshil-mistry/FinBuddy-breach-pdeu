import 'package:flutter/material.dart';
import '../../models/pool_model.dart';
import '../../models/shared_expense_model.dart';
import '../../models/user_model.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/debt_simplifier.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class SettleUpScreen extends StatefulWidget {
  final PoolModel pool;

  const SettleUpScreen({super.key, required this.pool});

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  Map<String, String> _memberNames = {};
  Map<String, String> _memberUpiIds = {};
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
          _memberUpiIds[uid] = user?.upiId ?? '';
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
                        final bool isMePaying = t.from == FirebaseAuth.instance.currentUser?.uid;
                        final String upiId = _memberUpiIds[t.to] ?? '';
                        final bool canPayViaUpi = isMePaying && upiId.isNotEmpty;

                        final bool canSettle = isMePaying || t.to == FirebaseAuth.instance.currentUser?.uid;
                        final bool isMeOwed = t.to == FirebaseAuth.instance.currentUser?.uid;

                        return GestureDetector(
                          onTap: canSettle
                              ? () => _showSettlementOptions(t, canPayViaUpi, upiId, isMeOwed, isMePaying)
                              : null,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.pureWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: canSettle ? AppColors.primaryBlue : AppColors.borderLight,
                                width: canSettle ? 2 : 1,
                              ),
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

  void _showSettlementOptions(SettlementTransfer t, bool canPayViaUpi, String upiId, bool isMeOwed, bool isMePaying) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Settle Debt',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 20,
                        color: AppColors.darkBlue,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '${_memberNames[t.to] ?? 'Unknown'} is owed ₹${t.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, color: AppColors.textDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (canPayViaUpi) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _launchUpi(t, upiId);
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Pay via UPI App'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: AppColors.pureWhite,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _recordManualSettlement(t);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Mark as Settled (Cash)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: AppColors.pureWhite,
                  ),
                ),

                if (isMeOwed && !isMePaying) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _sendNudge(t);
                    },
                    icon: const Icon(Icons.notifications_active_rounded),
                    label: const Text('Send Nudge'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.warningOrange,
                      foregroundColor: AppColors.pureWhite,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendNudge(SettlementTransfer t) async {
    try {
      await FirestoreService().sendNudge(
        fromUid: t.to,
        toUid: t.from,
        poolId: widget.pool.id,
        amount: t.amount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nudge sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  static const platform = MethodChannel('com.breachpdeu.finbuddy/upi');

  void _launchUpi(SettlementTransfer t, String upiId) async {
    final payeeName = Uri.encodeComponent(_memberNames[t.to] ?? 'FinBuddy User');
    final trId = 'FINB${DateTime.now().millisecondsSinceEpoch}';
    final uriStr = 'upi://pay?pa=$upiId&pn=$payeeName&tr=$trId&am=${t.amount.toStringAsFixed(2)}&cu=INR&tn=FinBuddy%20Settlement';
    try {
      final String result = await platform.invokeMethod('startUpiPayment', {'uri': uriStr});
      
      if (result == 'canceled') {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment cancelled or no response.')));
        }
        return;
      }

      if (result.contains('success') || result.contains('status=success') || result.contains('txn')) {
        _recordManualSettlement(t);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment did not succeed: $result')));
        }
      }
    } on PlatformException catch (e) {
      if (e.code == 'NO_APP_FOUND') {
        // Fallback to url_launcher if the platform channel fails
        final uri = Uri.parse(uriStr);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch UPI app: ${e.message}')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
        }
      }
    }
  }

  void _recordManualSettlement(SettlementTransfer t) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final firestore = FirestoreService();
      // 1. Add shared expense where 100% is split to the receiver, paid by the sender.
      // This zeroes out the debt automatically via the algorithm calculation.
      final settlementExpense = SharedExpenseModel(
        id: '', // FirestoreService handles doc generation
        poolId: widget.pool.id,
        description: 'Debt Settlement',
        amount: t.amount,
        paidBy: t.from,
        date: DateTime.now(),
        splits: {t.to: t.amount},
      );
      await firestore.addSharedExpense(settlementExpense);

      // 2. Add personal transaction for the current user
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && (t.from == currentUid || t.to == currentUid)) {
        final isPayer = t.from == currentUid;
        final userTransaction = TransactionModel(
          id: '',
          uid: currentUid,
          description: isPayer 
              ? 'Settled debt to ${_memberNames[t.to] ?? 'Unknown'}'
              : 'Received settlement from ${_memberNames[t.from] ?? 'Unknown'}',
          amount: t.amount,
          category: 'Transfers',
          tag: 'Need',
          type: isPayer ? 'expense' : 'income',
          date: DateTime.now(),
        );
        await firestore.addTransaction(userTransaction);
      }

      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debt successfully settled!'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }
}
