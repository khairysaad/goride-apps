import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';

class WalletProvider extends ChangeNotifier {
  double _balance = 0;
  String _currency = 'EGP';
  List<WalletTransaction> _transactions = [];
  bool _loading = false;

  double get balance => _balance;
  String get currency => _currency;
  List<WalletTransaction> get transactions => _transactions;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/profile/wallet');
      _balance = (data['balance'] as num?)?.toDouble() ?? 0;
      _currency = data['currency'] as String? ?? 'EGP';
      _transactions = (data['transactions'] as List)
          .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> topup(double amount, {String? method}) async {
    final data = await ApiClient.instance
        .post('/profile/wallet/topup', data: {'amount': amount, if (method != null) 'method': method});
    await load();
    return data;
  }

  Future<Map<String, dynamic>?> driverEarnings() async {
    try {
      return await ApiClient.instance.get('/driver/earnings');
    } catch (_) {
      return null;
    }
  }

  Future<void> withdraw(double amount, String method, {String? walletNumber, String? bankAccount}) async {
    await ApiClient.instance.post('/driver/earnings/withdraw', data: {
      'amount': amount,
      'payment_method': method,
      if (walletNumber != null) 'wallet_number': walletNumber,
      if (bankAccount != null) 'bank_account': bankAccount,
    });
    await load();
  }
}