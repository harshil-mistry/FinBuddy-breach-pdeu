import 'package:flutter/material.dart';
import '../../models/pool_model.dart';
import '../../models/shared_expense_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'invite_screen.dart';
import 'add_expense_sheet.dart';
import 'settle_up_screen.dart';
import 'expense_detail_sheet.dart';

class PoolDetailScreen extends StatefulWidget {
  final String poolId;

  const PoolDetailScreen({super.key, required this.poolId});

  @override
  State<PoolDetailScreen> createState() => _PoolDetailScreenState();
}

class _PoolDetailScreenState extends State<PoolDetailScreen> {
  final _firestoreService = FirestoreService();
  Map<String, String> _memberNames = {};

  // Filter state
  String? _filterPaidBy; // uid
  String? _filterPaidFor; // uid (any split containing this uid)
  DateTime? _filterFromDate;
  DateTime? _filterToDate;

  void _showAddExpenseSheet(BuildContext context, PoolModel pool) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSharedExpenseSheet(pool: pool),
    );
  }

  Future<void> _loadMemberNames(List<String> members) async {
    for (String uid in members) {
      if (!_memberNames.containsKey(uid)) {
        UserModel? user = await _firestoreService.getUser(uid);
        if (mounted) {
          setState(() {
            _memberNames[uid] = user != null && user.displayName.isNotEmpty
                ? user.displayName
                : 'User';
          });
        }
      }
    }
  }

  List<SharedExpenseModel> _applyFilters(List<SharedExpenseModel> expenses) {
    return expenses.where((ex) {
      if (_filterPaidBy != null && ex.paidBy != _filterPaidBy) return false;
      if (_filterPaidFor != null && !ex.splits.containsKey(_filterPaidFor)) return false;
      if (_filterFromDate != null && ex.date.isBefore(_filterFromDate!)) return false;
      if (_filterToDate != null) {
        final endOfDay = DateTime(_filterToDate!.year, _filterToDate!.month, _filterToDate!.day, 23, 59, 59);
        if (ex.date.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();
  }

  void _showFilters(BuildContext context, PoolModel pool) {
    String? tempPaidBy = _filterPaidBy;
    String? tempPaidFor = _filterPaidFor;
    DateTime? tempFrom = _filterFromDate;
    DateTime? tempTo = _filterToDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Filter Expenses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkBlue)),
                const SizedBox(height: 20),

                // Paid By
                const Text('Paid By', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: tempPaidBy,
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.pureWhite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Anyone')),
                    ...pool.members.map((uid) => DropdownMenuItem(
                      value: uid,
                      child: Text(_memberNames[uid] ?? uid),
                    )),
                  ],
                  onChanged: (v) => setModalState(() => tempPaidBy = v),
                ),
                const SizedBox(height: 16),

                // Paid For
                const Text('Includes (paid for)', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: tempPaidFor,
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.pureWhite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight)),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Anyone')),
                    ...pool.members.map((uid) => DropdownMenuItem(
                      value: uid,
                      child: Text(_memberNames[uid] ?? uid),
                    )),
                  ],
                  onChanged: (v) => setModalState(() => tempPaidFor = v),
                ),
                const SizedBox(height: 16),

                // Date Range
                const Text('Date Range', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: tempFrom ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setModalState(() => tempFrom = date);
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(tempFrom != null ? DateFormat('dd MMM').format(tempFrom!) : 'From'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: tempTo ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setModalState(() => tempTo = date);
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(tempTo != null ? DateFormat('dd MMM').format(tempTo!) : 'To'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _filterPaidBy = null;
                            _filterPaidFor = null;
                            _filterFromDate = null;
                            _filterToDate = null;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _filterPaidBy = tempPaidBy;
                            _filterPaidFor = tempPaidFor;
                            _filterFromDate = tempFrom;
                            _filterToDate = tempTo;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _filterPaidBy != null || _filterPaidFor != null || _filterFromDate != null || _filterToDate != null;

  void _showGroupActions(BuildContext context, PoolModel pool) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = pool.ownerId == currentUid;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(pool.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkBlue), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('${pool.members.length} members', style: const TextStyle(color: AppColors.textLight), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (!isOwner)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmLeavePool(context, pool, currentUid!);
                  },
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: const Text('Leave Group'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.errorRed.withAlpha(20),
                    foregroundColor: AppColors.errorRed,
                    elevation: 0,
                    side: BorderSide(color: AppColors.errorRed.withAlpha(80)),
                  ),
                ),
              if (isOwner) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDeletePool(context, pool);
                  },
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Delete Group'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.errorRed,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLeavePool(BuildContext context, PoolModel pool, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Group', style: TextStyle(color: AppColors.darkBlue, fontWeight: FontWeight.bold)),
        content: const Text('You will be removed from this group. Existing debts between members will remain unchanged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.leavePool(pool.id, uid);
              if (mounted) Navigator.of(context).pop(); // go back to pools list
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePool(BuildContext context, PoolModel pool) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Group', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
        content: Text('This will permanently delete "${pool.name}" and ALL its expenses. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.deletePool(pool.id);
              if (mounted) Navigator.of(context).pop(); // go back to pools list
            },
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PoolModel?>(
      stream: _firestoreService.getPoolStream(widget.poolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final pool = snapshot.data;
        if (pool == null) {
          return const Scaffold(body: Center(child: Text('Pool not found')));
        }

        // Trigger member name loading whenever pool updates
        _loadMemberNames(pool.members);

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
              // Filter button with badge when active
              Stack(
                children: [
                  IconButton(
                    onPressed: () => _showFilters(context, pool),
                    icon: const Icon(Icons.filter_list_rounded, color: AppColors.primaryBlue),
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
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
              IconButton(
                onPressed: () => _showGroupActions(context, pool),
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.darkBlue),
              ),
              const SizedBox(width: 4),
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

              // Filter chips if active
              if (_hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_filterPaidBy != null)
                          _filterChip('By: ${_memberNames[_filterPaidBy!] ?? '...'}', () => setState(() => _filterPaidBy = null)),
                        if (_filterPaidFor != null)
                          _filterChip('For: ${_memberNames[_filterPaidFor!] ?? '...'}', () => setState(() => _filterPaidFor = null)),
                        if (_filterFromDate != null)
                          _filterChip('From: ${DateFormat('dd MMM').format(_filterFromDate!)}', () => setState(() => _filterFromDate = null)),
                        if (_filterToDate != null)
                          _filterChip('To: ${DateFormat('dd MMM').format(_filterToDate!)}', () => setState(() => _filterToDate = null)),
                      ],
                    ),
                  ),
                ),

              // Expenses List
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  ),
                  child: StreamBuilder<List<SharedExpenseModel>>(
                    stream: _firestoreService.getSharedExpenses(widget.poolId),
                    builder: (context, expenseSnapshot) {
                      if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allExpenses = expenseSnapshot.data ?? [];
                      final expenses = _applyFilters(allExpenses);

                      if (allExpenses.isEmpty) {
                        return const Center(child: Text('No expenses yet. Add one!', style: TextStyle(color: AppColors.textLight)));
                      }

                      if (expenses.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.filter_list_off_rounded, size: 60, color: AppColors.textLight),
                              const SizedBox(height: 16),
                              const Text('No expenses match your filters.', style: TextStyle(color: AppColors.textLight)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => setState(() {
                                  _filterPaidBy = null;
                                  _filterPaidFor = null;
                                  _filterFromDate = null;
                                  _filterToDate = null;
                                }),
                                child: const Text('Clear Filters'),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final ex = expenses[index];
                          final dateStr = DateFormat('MMM d, y').format(ex.date);

                          return GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => ExpenseDetailSheet(expense: ex, pool: pool),
                              );
                            },
                            child: Container(
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
                                      color: ex.description == 'Debt Settlement'
                                          ? AppColors.successGreen.withAlpha(20)
                                          : AppColors.errorRed.withAlpha(20),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      ex.description == 'Debt Settlement'
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.receipt_long_rounded,
                                      color: ex.description == 'Debt Settlement'
                                          ? AppColors.successGreen
                                          : AppColors.errorRed,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ex.description, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'by ${_memberNames[ex.paidBy] ?? '...'} · $dateStr',
                                          style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text('₹${ex.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.darkBlue)),
                                ],
                              ),
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

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
        backgroundColor: AppColors.lightBlue,
        deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppColors.primaryBlue),
        onDeleted: onRemove,
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
