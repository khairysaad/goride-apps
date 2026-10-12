import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../providers/settings_provider.dart';
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  late final Dio _fallbackDio;
  String? _token;
  bool _useFallback = false;
  int _consecutivePrimaryFails = 0;

  ApiClient._() {
    Dio _build(String baseUrl) => Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Accept': 'application/json'},
          ),
        );
    _dio = _build(ApiConfig.primaryBaseUrl);
    _fallbackDio = _build(ApiConfig.fallbackBaseUrl);
    void _auth(Dio dio) => dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (_token != null) {
                options.headers['Authorization'] = 'Bearer $_token';
              }
              handler.next(options);
            },
          ),
        );
    _auth(_dio);
    _auth(_fallbackDio);
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    instance._token = prefs.getString('auth_token');
    debugPrint('ApiClient init, token=${instance._token != null}');
  }

  String? get token => _token;

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('auth_token');
    } else {
      await prefs.setString('auth_token', token);
    }
  }

  Future<Response> _send(Dio dio, RequestOptions opts) =>
      dio.fetch(opts);

  RequestOptions _opts(String method, String path,
      {Object? data, Map<String, dynamic>? query}) {
    return RequestOptions(
      method: method,
      baseUrl: (_useFallback ? ApiConfig.fallbackBaseUrl : ApiConfig.primaryBaseUrl),
      path: path,
      data: data,
      queryParameters: query,
      headers: {'Accept': 'application/json'},
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 30),
    );
  }

  void _setFallback(bool v) {
    _useFallback = v;
    ApiConfig.useFallback = v;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _send(
          _useFallback ? _fallbackDio : _dio, _opts('GET', path, query: query));
      _consecutivePrimaryFails = 0;
      _setFallback(false);
      return res.data;
    } on DioException catch (e) {
      return _handleRetry(e, path);
    }
  }

  Future<dynamic> post(String path,
      {Map<String, dynamic>? data, bool formData = false}) async {
    try {
      final body = formData ? FormData.fromMap(data!) : data;
      final res = await _send(_useFallback ? _fallbackDio : _dio,
          _opts('POST', path, data: body));
      _consecutivePrimaryFails = 0;
      _setFallback(false);
      return res.data;
    } on DioException catch (e) {
      return _handleRetry(e, path, data: data, formData: formData);
    }
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? data}) async {
    try {
      final res = await _send(_useFallback ? _fallbackDio : _dio,
          _opts('PUT', path, data: data));
      _consecutivePrimaryFails = 0;
      _setFallback(false);
      return res.data;
    } on DioException catch (e) {
      return _handleRetry(e, path, data: data);
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final res = await _send(
          _useFallback ? _fallbackDio : _dio, _opts('DELETE', path));
      _consecutivePrimaryFails = 0;
      _setFallback(false);
      return res.data;
    } on DioException catch (e) {
      return _handleRetry(e, path);
    }
  }

  Future<dynamic> _handleRetry(DioException e, String path,
      {Map<String, dynamic>? data, bool formData = false}) async {
    if (!_useFallback && e.response == null) {
      _consecutivePrimaryFails++;
      if (_consecutivePrimaryFails >= 1) {
        _setFallback(true);
        try {
          final res = await _send(_fallbackDio,
              _opts(formData ? 'POST' : e.requestOptions.method, path,
                  data: formData ? FormData.fromMap(data!) : data,
                  query: e.requestOptions.queryParameters));
          return res.data;
        } on DioException catch (f) {
          throw _handleError(f);
        }
      }
    }
    throw _handleError(e);
  }

  ApiException _handleError(DioException e) {
    if (e.response?.statusCode == 401) {
      setToken(null);
    }
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return ApiException(data['message'].toString(),
          statusCode: e.response?.statusCode);
    }
    if (data is Map && data['errors'] != null) {
      final errors = data['errors'] as Map;
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        return ApiException(first.first.toString(),
            statusCode: e.response?.statusCode);
      }
    }
    if (e.response == null) {
      return ApiException(L10n.t('err_network'));
    }
    return ApiException(L10n.t('err_unexpected'), statusCode: e.response?.statusCode);
  }
}