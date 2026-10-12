import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';

class WalletProvider extends ChangeNotifier {
  Future<Map<String, dynamic>?> driverEarnings() async {
    try {
      return await ApiClient.instance.get('/driver/earnings');
    } catch (_) {
      return null;
    }
  }

  Future<void> withdraw(double amount, String method,
      {String? walletNumber, String? bankAccount}) async {
    await ApiClient.instance.post('/driver/earnings/withdraw', data: {
      'amount': amount,
      'payment_method': method,
      if (walletNumber != null) 'wallet_number': walletNumber,
      if (bankAccount != null) 'bank_account': bankAccount,
    });
  }
}