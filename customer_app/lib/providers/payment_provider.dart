import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';

class PaymentProvider extends ChangeNotifier {
  List<PaymentChannel> _channels = [];
  bool _loading = false;
  bool _loaded = false;

  List<PaymentChannel> get channels => _channels;
  List<PaymentChannel> get tripMethods => _channels.where((c) => c.isTrip).toList();
  List<PaymentChannel> get topupMethods => _channels.where((c) => c.isTopup).toList();
  bool get loading => _loading;
  bool get loaded => _loaded;

  static final List<PaymentChannel> fallback = [
    PaymentChannel(key: 'cash', nameAr: 'كاش', icon: 'cash', enumValue: 0, isTrip: true),
    PaymentChannel(key: 'wallet', nameAr: 'محفظة التطبيق', icon: 'wallet', enumValue: 1, isTrip: true),
  ];

  Future<void> load() async {
    if (_loaded && _channels.isNotEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/payment-methods');
      final raw = data['payment_methods'] as List? ?? const [];
      _channels = raw
          .map((e) => PaymentChannel.fromJson(e as Map<String, dynamic>))
          .where((c) => c.isTrip || c.isTopup)
          .toList();
      _loaded = true;
    } catch (_) {
      if (_channels.isEmpty) {
        _channels = List.of(fallback);
      }
    }
    _loading = false;
    notifyListeners();
  }
}