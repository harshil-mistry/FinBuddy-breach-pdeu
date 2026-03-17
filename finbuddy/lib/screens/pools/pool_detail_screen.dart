import 'package:flutter/material.dart';
import '../../models/pool_model.dart';
import '../../models/shared_expense_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'invite_screen.dart';
import 'add_expense_sheet.dart';
import 'settle_up_screen.dart';
import 'expense_detail_sheet.dart';
import '../../utils/debt_simplifier.dart';
import '../../services/pool_pdf_service.dart';
import 'voice_recorder_sheet.dart';

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

  void _showAddExpenseSheet(BuildContext context, PoolModel pool, {double? prefilledAmount, String? prefilledDescription}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSharedExpenseSheet(
        pool: pool,
        prefilledAmount: prefilledAmount,
        prefilledDescription: prefilledDescription,
      ),
    );
  }

  /// Pick or capture a receipt image and send to backend for AI scanning
  Future<void> _scanReceipt(BuildContext context, PoolModel pool) async {
    // Let user choose camera or gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scan Receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkBlue)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryBlue),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryBlue),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile == null) return;

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryBlue),
                SizedBox(height: 16),
                Text('Scanning receipt...', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Use local PC IP for physical device debugging
      // const serverUrl = 'http://10.118.66.183:3000/api/scan-receipt';
      const serverUrl = 'https://finbuddy-breach-pdeu.onrender.com/api/scan-receipt';

      final request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath('image', pickedFile.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      // Dismiss loading dialog
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          final amount = (data['amount'] as num).toDouble();
          final description = data['description'] as String;

          if (mounted) {
            _showAddExpenseSheet(context, pool, prefilledAmount: amount, prefilledDescription: description);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not read receipt. Please try again or add manually.')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      // Dismiss loading dialog if still open
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to scan receipt: $e')),
        );
      }
    }
  }

  Future<void> _loadMemberNames(List<String> members, [List<String>? joinRequests]) async {
    final allUids = [...members, ...?joinRequests];
    for (String uid in allUids) {
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

  void _showGroupActions(BuildContext context, PoolModel initialPool) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StreamBuilder<PoolModel?>(
        stream: _firestoreService.getPoolStream(initialPool.id),
        builder: (ctx, snapshot) {
          final pool = snapshot.data ?? initialPool;
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final isOwner = pool.ownerId == currentUid;
          
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
        builder: (ctx, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Group Management', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkBlue)),
                    if (isOwner)
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: AppColors.errorRed),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDeletePool(context, pool);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // --- JOIN REQUESTS (admin only) ---
                      if (isOwner && pool.joinRequests.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text('Pending Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkBlue)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(10)),
                              child: Text('${pool.joinRequests.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...pool.joinRequests.map((reqUid) {
                          final name = _memberNames[reqUid] ?? reqUid;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.pureWhite,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.lightBlue,
                                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                IconButton(
                                  icon: const Icon(Icons.check_circle_rounded, color: AppColors.successGreen),
                                  tooltip: 'Approve',
                                  onPressed: () async {
                                    await _firestoreService.approveJoinRequest(pool.id, reqUid);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel_rounded, color: AppColors.errorRed),
                                  tooltip: 'Deny',
                                  onPressed: () async {
                                    await _firestoreService.denyJoinRequest(pool.id, reqUid);
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(height: 32),
                      ],

                      // --- MEMBERS LIST ---
                      Text('Members (${pool.members.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkBlue)),
                      const SizedBox(height: 8),
                      ...pool.members.map((memberUid) {
                        final name = _memberNames[memberUid] ?? 'Loading...';
                        final isThisOwner = memberUid == pool.ownerId;
                        final isMe = memberUid == currentUid;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.lightBlue : AppColors.pureWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isMe ? AppColors.primaryBlue.withAlpha(60) : AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isThisOwner ? AppColors.primaryBlue : AppColors.lightBlue,
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(color: isThisOwner ? Colors.white : AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    if (isThisOwner)
                                      const Text('Admin', style: TextStyle(color: AppColors.primaryBlue, fontSize: 12)),
                                    if (isMe && !isThisOwner)
                                      const Text('You', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                                  ],
                                ),
                              ),
                              // Kick button — admin can kick anyone except themselves
                              if (isOwner && !isMe && !isThisOwner)
                                IconButton(
                                  icon: const Icon(Icons.person_remove_rounded, color: AppColors.errorRed),
                                  tooltip: 'Remove Member',
                                  onPressed: () => _confirmKickMember(ctx, pool, memberUid, name),
                                ),
                            ],
                          ),
                        );
                      }),

                      const Divider(height: 32),

                      // Leave / action button for non-owner
                      if (!isOwner)
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmLeavePool(context, pool, currentUid!);
                          },
                          icon: const Icon(Icons.exit_to_app_rounded),
                          label: const Text('Leave Group'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.errorRed.withAlpha(20),
                            foregroundColor: AppColors.errorRed,
                            elevation: 0,
                            side: BorderSide(color: AppColors.errorRed.withAlpha(80)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
     },
    ),
   );
  }

  void _confirmKickMember(BuildContext ctx, PoolModel pool, String uid, String name) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Member', style: TextStyle(color: AppColors.darkBlue, fontWeight: FontWeight.bold)),
        content: Text('Remove $name from "${pool.name}"? Their expense records will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _firestoreService.kickMember(pool.id, uid);
            },
            child: const Text('Remove'),
          ),
        ],
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

        // Trigger member name loading whenever pool updates (including join requesters)
        _loadMemberNames(pool.members, pool.joinRequests);

        return DefaultTabController(
          length: 2,
          child: Scaffold(
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
                tooltip: 'Export to PDF',
                onPressed: () async {
                  // We need the latest list of expenses to generate the report
                  final allExpenses = await _firestoreService
                      .getSharedExpenses(widget.poolId)
                      .first;
                  if (!context.mounted) return;
                  await PoolPdfService.exportPoolPdf(
                    context: context,
                    pool: pool,
                    expenses: allExpenses,
                    memberNames: _memberNames,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.errorRed),
              ),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    onPressed: () => _showGroupActions(context, pool),
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.darkBlue),
                  ),
                  if (pool.ownerId == FirebaseAuth.instance.currentUser?.uid && pool.joinRequests.isNotEmpty)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
                      ),
                    ),
                ],
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
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Group Expenses', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text(
                            '₹${pool.totalExpenses.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 50, color: Colors.white24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Members', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text(
                            '${pool.members.length}',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
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

              const TabBar(
                labelColor: AppColors.primaryBlue,
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: AppColors.primaryBlue,
                indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                tabs: [
                  Tab(text: 'Balances'),
                  Tab(text: 'History'),
                ],
              ),
              
              // Expenses & Balances List
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.pureWhite,
                  ),
                  child: StreamBuilder<List<SharedExpenseModel>>(
                    stream: _firestoreService.getSharedExpenses(widget.poolId),
                    builder: (context, expenseSnapshot) {
                      if (expenseSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allExpenses = expenseSnapshot.data ?? [];
                      final expenses = _applyFilters(allExpenses);

                      return TabBarView(
                        children: [
                          _buildBalancesTab(allExpenses), // Balances doesn't use filters typically
                          _buildHistoryTab(expenses, pool),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                heroTag: 'scan_receipt',
                backgroundColor: AppColors.pureWhite,
                onPressed: () => _scanReceipt(context, pool),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 10),
              FloatingActionButton(
                heroTag: 'voice_expense',
                backgroundColor: AppColors.pureWhite,
                onPressed: () => showVoiceRecorderSheet(context, pool),
                child: const Icon(Icons.mic_rounded, color: AppColors.errorRed),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.extended(
                heroTag: 'add_expense',
                backgroundColor: AppColors.primaryBlue,
                onPressed: () => _showAddExpenseSheet(context, pool),
                icon: const Icon(Icons.add_rounded, color: AppColors.pureWhite),
                label: const Text('Add Expense', style: TextStyle(color: AppColors.pureWhite, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildBalancesTab(List<SharedExpenseModel> expenses) {
    if (expenses.isEmpty) {
      return const Center(child: Text('No balances to show.', style: TextStyle(color: AppColors.textLight)));
    }

    Map<String, double> balances = DebtSimplifier.calculateBalances(expenses);
    
    // Sort balances so largest creditors (positive) are top
    var sortedMembers = balances.keys.toList()
      ..sort((a, b) => (balances[b] ?? 0).compareTo(balances[a] ?? 0));

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sortedMembers.length,
      itemBuilder: (context, index) {
        String uid = sortedMembers[index];
        double balance = balances[uid] ?? 0.0;
        
        bool isPositive = balance > 0.01;
        bool isNegative = balance < -0.01;
        
        final name = _memberNames[uid] ?? uid;
        String prefixText = name.isNotEmpty ? name[0].toUpperCase() : '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.lightBlue,
                child: Text(prefixText, style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              Text(
                '${isPositive ? '+' : ''}${isNegative ? '-' : ''}₹${balance.abs().toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18,
                  color: isPositive ? AppColors.successGreen : (isNegative ? AppColors.errorRed : AppColors.textLight)
                )
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildHistoryTab(List<SharedExpenseModel> expenses, PoolModel pool) {
    if (expenses.isEmpty) {
      if (_hasActiveFilters) {
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
      return const Center(child: Text('No expenses yet. Add one!', style: TextStyle(color: AppColors.textLight)));
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
