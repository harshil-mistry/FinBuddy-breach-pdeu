import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/pool_model.dart';
import '../../theme/app_colors.dart';

class InviteScreen extends StatelessWidget {
  final PoolModel pool;

  const InviteScreen({super.key, required this.pool});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: const Text('Invite Members', style: TextStyle(color: AppColors.darkBlue)),
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkBlue),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                pool.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan this QR code to join',
                style: TextStyle(color: AppColors.textLight, fontSize: 16),
              ),
              const SizedBox(height: 40),
              
              // QR CODE GENERATOR
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLight, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withAlpha(20),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: QrImageView(
                  data: pool.inviteCode,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: AppColors.pureWhite,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.darkBlue,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: AppColors.darkBlue,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              const Text(
                'Or use this invite code',
                style: TextStyle(color: AppColors.textLight, fontSize: 14),
              ),
              const SizedBox(height: 12),
              
              // INVITE CODE DISPLAY & COPY
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: pool.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite Code copied to clipboard!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pool.inviteCode,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.copy_rounded, color: AppColors.primaryBlue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
