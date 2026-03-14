import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../models/pool_model.dart';
import 'pool_detail_screen.dart';
import 'qr_scanner_screen.dart';
import 'dart:math';

class PoolsScreen extends StatelessWidget {
  const PoolsScreen({super.key});

  void _showCreateOrJoinSheet(BuildContext context, String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateOrJoinSheet(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pools',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 22,
                              color: AppColors.darkBlue,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Shared expenses & group trips',
                        style: TextStyle(color: AppColors.textLight, fontSize: 14),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _showCreateOrJoinSheet(context, uid),
                    icon: const Icon(Icons.add_circle_rounded),
                    color: AppColors.primaryBlue,
                    iconSize: 32,
                  )
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<PoolModel>>(
                stream: FirestoreService().getPools(uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final pools = snapshot.data ?? [];

                  if (pools.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_off_rounded, size: 60, color: AppColors.borderLight),
                          const SizedBox(height: 16),
                          Text(
                            'You aren\'t in any pools yet',
                            style: TextStyle(fontSize: 16, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _showCreateOrJoinSheet(context, uid),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create or Join a Pool'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: pools.length,
                    itemBuilder: (context, index) {
                      final pool = pools[index];
                      return _PoolCard(pool: pool);
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
}

class _PoolCard extends StatelessWidget {
  final PoolModel pool;

  const _PoolCard({required this.pool});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PoolDetailScreen(poolId: pool.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkBlue.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group_rounded, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pool.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pool.members.length} member${pool.members.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
              ],
            ),
            if (pool.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                pool.description,
                style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: AppColors.borderLight),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Expenses:',
                  style: TextStyle(color: AppColors.textLight, fontSize: 13),
                ),
                Text(
                  '₹${pool.totalExpenses.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.darkBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateOrJoinSheet extends StatefulWidget {
  final String uid;

  const _CreateOrJoinSheet({required this.uid});

  @override
  State<_CreateOrJoinSheet> createState() => _CreateOrJoinSheetState();
}

class _CreateOrJoinSheetState extends State<_CreateOrJoinSheet> {
  bool _isCreating = true; // Toggle between Create/Join
  bool _isLoading = false;

  // Create Form
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  // Join Form
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      6,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      if (_isCreating) {
        if (_nameController.text.trim().isEmpty) return;
        
        final pool = PoolModel(
          id: '', // Generated by Firestore
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          inviteCode: _generateInviteCode(),
          ownerId: widget.uid,
          members: [widget.uid],
          createdAt: DateTime.now(),
        );

        await FirestoreService().createPool(pool);
      } else {
        if (_codeController.text.trim().isEmpty) return;
        
        final success = await FirestoreService().joinPool(
          _codeController.text.trim().toUpperCase(), 
          widget.uid
        );

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid Invite Code')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Toggle
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Create Pool')),
                ButtonSegment(value: false, label: Text('Join Pool')),
              ],
              selected: {_isCreating},
              onSelectionChanged: (val) => setState(() => _isCreating = val.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primaryBlue.withAlpha(30),
                selectedForegroundColor: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),

            if (_isCreating) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Pool Name (e.g., Goa Trip)',
                  prefixIcon: Icon(Icons.group_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  hintText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description_rounded),
                ),
                maxLines: 2,
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Enter 6-digit Invite Code',
                  prefixIcon: Icon(Icons.key_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final String? scannedCode = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
                    );

                    if (scannedCode != null && scannedCode.isNotEmpty) {
                      _codeController.text = scannedCode.trim().toUpperCase();
                      _submit(); // Auto-submit when scanned
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryBlue),
                  label: const Text(
                    'Scan QR Code',
                    style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isCreating ? 'Create Pool' : 'Join Pool'),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }
}
