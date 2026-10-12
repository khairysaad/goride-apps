import 'package:flutter/foundation.dart';

import 'dart:async';

import '../../core/network/api_client.dart';
import '../core/fcm/fcm_service.dart';
import '../../models/models.dart';

class AuthProvider extends ChangeNotifier {
  bool _initializing = true;
  User? _user;
  bool _isLoading = false;

  bool get initializing => _initializing;
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    await ApiClient.init();
    _listenForPushTokenRefresh();
    final token = ApiClient.instance.token;
    if (token != null) {
      try {
        final data = await ApiClient.instance.get('/auth/me');
        _user = User.fromJson(data['user'] as Map<String, dynamic>);
        unawaited(_syncPushToken());
      } catch (e) {
        await ApiClient.instance.setToken(null);
      }
    }
    _initializing = false;
    notifyListeners();
  }

  Future<void> login(String phone, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.post('/auth/login', data: {
        'phone': phone,
        'password': password,
      });
      final token = data['token'] as String;
      await ApiClient.instance.setToken(token);
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      unawaited(_syncPushToken());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.post('/auth/register', data: {
        'name': name,
        'phone': phone,
        'password': password,
        'password_confirmation': password,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      final token = data['token'] as String;
      await ApiClient.instance.setToken(token);
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      unawaited(_syncPushToken());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.post('/auth/logout');
    } catch (_) {}
    await ApiClient.instance.setToken(null);
    _user = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final data = await ApiClient.instance.get('/auth/me');
      _user = User.fromJson(data['user'] as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateProfile({String? name, String? email}) async {
    await ApiClient.instance.put('/profile', data: {
      if (name != null && name.isNotEmpty) 'name': name,
      if (email != null) 'email': email,
    });
    await refresh();
  }

  Future<void> _syncPushToken() async {
    try {
      await FcmService.registerWithApi();
    } catch (_) {}
  }

  void _listenForPushTokenRefresh() {
    FcmService.onTokenRefresh.listen((_) => unawaited(_syncPushToken()));
  }
}