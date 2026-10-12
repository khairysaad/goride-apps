import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/notification_provider.dart';
import '../../providers/settings_provider.dart';
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load();
    });
  }

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return L10n.t('now');
    if (diff.inHours < 1) {
      return L10n.f('since_min', {'n': '${diff.inMinutes}'});
    }
    if (diff.inDays < 1) {
      return L10n.f('since_hours', {'n': '${diff.inHours}'});
    }
    return L10n.f('since_days', {'n': '${diff.inDays}'});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.f('notif_count', {'n': '${provider.unreadCount}'})),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () => context.read<NotificationProvider>().markAllRead(),
              child: Text(L10n.t('mark_all_read')),
            ),
        ],
      ),
      body: provider.loading && provider.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<NotificationProvider>().load(),
              child: provider.items.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 120),
                        Icon(Icons.notifications_off,
                            size: 56, color: context.onSurfaceVariant),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            L10n.t('no_notifications'),
                            style: TextStyle(color: context.onSurfaceVariant),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final n = provider.items[i];
                        return Card(
                          child: InkWell(
                            onTap: () =>
                                context.read<NotificationProvider>().markRead(n.id),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: BoxDecoration(
                                      color: n.isRead
                                          ? context.onSurfaceVariant
                                          : AppColors.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                n.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _relative(n.createdAt),
                                              style: TextStyle(
                                                  color: context.onSurfaceVariant,
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          n.body,
                                          style: TextStyle(
                                              color: context.onSurfaceVariant,
                                              fontSize: 13),
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
            ),
    );
  }
}