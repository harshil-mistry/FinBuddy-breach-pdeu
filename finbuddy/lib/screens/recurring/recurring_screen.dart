import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  UserModel? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final user = await FirestoreService().getUser(uid);
    if (mounted) {
      setState(() {
        _userData = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
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
                      style: TextStyle(
                          color: AppColors.textLight, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    // ─── Recurring Income ──────────────────────────
                    _sectionHeader('Recurring Income',
                        Icons.trending_up_rounded, AppColors.successGreen),
                    const SizedBox(height: 12),
                    if (_userData?.recurringIncomes.isEmpty ?? true)
                      _emptyState('No recurring income set up.'),
                    if (_userData != null)
                      ...(_userData!.recurringIncomes.map((inc) => _tile(
                            icon: Icons.trending_up_rounded,
                            iconColor: AppColors.successGreen,
                            title: inc.source,
                            subtitle:
                                '₹${inc.amount.toStringAsFixed(0)} · Day ${inc.dayOfMonth}',
                          ))),
                    const SizedBox(height: 28),

                    // ─── Recurring Expenses ───────────────────────
                    _sectionHeader('Recurring Expenses',
                        Icons.trending_down_rounded, AppColors.errorRed),
                    const SizedBox(height: 12),
                    if (_userData?.recurringExpenses.isEmpty ?? true)
                      _emptyState('No recurring expenses set up.'),
                    if (_userData != null)
                      ...(_userData!.recurringExpenses.map((exp) => _tile(
                            icon: Icons.trending_down_rounded,
                            iconColor: AppColors.errorRed,
                            title: exp.name,
                            subtitle:
                                '₹${exp.amount.toStringAsFixed(0)} · ${exp.tag} · Day ${exp.dayOfMonth}',
                          ))),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
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
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.darkBlue,
          ),
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
        style: TextStyle(color: AppColors.textLight, fontSize: 14),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
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
                    style:
                        TextStyle(color: AppColors.textLight, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
