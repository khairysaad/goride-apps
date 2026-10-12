import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../core/fcm/fcm_service.dart';
import '../../models/models.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _items = [];
  bool _loading = false;

  List<NotificationItem> get items => _items;
  bool get loading => _loading;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  NotificationProvider() {
    FcmService.onEvent.listen((_) => load());
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/notifications');
      _items = (data['notifications'] as List)
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(int id) async {
    await ApiClient.instance.post('/notifications/$id/read', data: {});
    await load();
  }

  Future<void> markAllRead() async {
    for (final n in _items.where((n) => !n.isRead)) {
      try {
        await ApiClient.instance.post('/notifications/${n.id}/read', data: {});
      } catch (_) {}
    }
    await load();
  }
}