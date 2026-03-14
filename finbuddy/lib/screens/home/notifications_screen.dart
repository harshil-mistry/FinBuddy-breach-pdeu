import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: AppColors.darkBlue, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.backgroundWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkBlue),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: FirestoreService().getNotifications(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 80, color: AppColors.textLight.withAlpha(100)),
                  const SizedBox(height: 16),
                  const Text('No new notifications', style: TextStyle(color: AppColors.textLight, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _buildNotificationCard(context, notif);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationModel notif) {
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        FirestoreService().deleteNotification(notif.id);
      },
      background: Container(
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.errorRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          if (!notif.isRead) {
            FirestoreService().markNotificationAsRead(notif.id);
          }
          // Optionally, navigate to the pool using notif.poolId here
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notif.isRead ? Colors.white : AppColors.lightBlue.withAlpha(150),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notif.isRead ? AppColors.borderLight : AppColors.primaryBlue.withAlpha(50),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: notif.isRead ? AppColors.borderLight.withAlpha(50) : AppColors.primaryBlue.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notif.type == 'nudge' ? Icons.waving_hand_rounded : Icons.notifications_rounded,
                  color: notif.isRead ? AppColors.textLight : AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.type == 'nudge' ? 'Payment Reminder' : 'Notification',
                      style: TextStyle(
                        fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                        color: AppColors.darkBlue,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.type == 'nudge' 
                          ? 'Someone nudged you to settle up ₹${notif.amount.toStringAsFixed(0)}.'
                          : 'You have a new notification.',
                      style: TextStyle(
                        color: notif.isRead ? AppColors.textLight : AppColors.textDark,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMM d, h:mm a').format(notif.createdAt),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notif.isRead)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
