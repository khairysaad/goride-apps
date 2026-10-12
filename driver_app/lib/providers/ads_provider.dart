import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/models.dart';

class AdsProvider extends ChangeNotifier {
  List<Ad> _ads = [];
  bool _loading = false;

  List<Ad> get ads => _ads;
  bool get loading => _loading;

  Future<void> load({String? target}) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get(
        '/ads',
        query: {if (target != null) 'target': target},
      );
      _ads = (data['ads'] as List)
          .map((e) => Ad.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
