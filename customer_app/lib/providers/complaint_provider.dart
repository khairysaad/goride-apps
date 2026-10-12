import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';

class ComplaintProvider extends ChangeNotifier {
  List<Complaint> _list = [];
  bool _loading = false;

  List<Complaint> get list => _list;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/complaints');
      _list = (data['complaints'] as List)
          .map((e) => Complaint.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> submit({
    required int category,
    String? subject,
    required String description,
    int? tripId,
  }) async {
    await ApiClient.instance.post('/complaints', data: {
      'category': category,
      if (subject != null && subject.isNotEmpty) 'subject': subject,
      'description': description,
      if (tripId != null) 'trip_id': tripId,
    });
    await load();
  }
}