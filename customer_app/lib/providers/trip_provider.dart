import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../core/fcm/fcm_service.dart';
import '../../models/models.dart';

class ServiceProvider extends ChangeNotifier {
  List<VehicleType> _vehicleTypes = [];
  List<ServiceType> _serviceTypes = [];
  List<CouponItem> _offers = [];
  bool _loading = false;
  bool _offersLoaded = false;

  List<VehicleType> get vehicleTypes => _vehicleTypes;
  List<ServiceType> get serviceTypes => _serviceTypes;
  List<CouponItem> get offers => _offers;
  bool get loading => _loading;

  Future<void> loadHomeData() async {
    if (_loading || _vehicleTypes.isNotEmpty) return;
    _loading = true;
    notifyListeners();
    try {
      final vt = await ApiClient.instance.get('/vehicle-types');
      final st = await ApiClient.instance.get('/service-types');
      _vehicleTypes = (vt['vehicle_types'] as List)
          .map((e) => VehicleType.fromJson(e as Map<String, dynamic>))
          .toList();
      _serviceTypes = (st['service_types'] as List)
          .map((e) => ServiceType.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadOffers() async {
    if (_offersLoaded) return;
    try {
      final data = await ApiClient.instance.get('/offers');
      _offers = (data['offers'] as List)
          .map((e) => CouponItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _offersLoaded = true;
      notifyListeners();
    } catch (_) {}
  }
}

class TripProvider extends ChangeNotifier {
  Trip? _activeTrip;
  bool _loading = false;
  Timer? _pollTimer;
  Timer? _driversTimer;
  List<NearbyDriver> _nearbyDrivers = [];

  TripProvider() {
    FcmService.onEvent.listen((event) {
      if (event.type == 'trip' && event.relatedId != null) {
        refreshActive();
      }
    });
  }

  Trip? get activeTrip => _activeTrip;
  bool get loading => _loading;
  List<NearbyDriver> get nearbyDrivers => _nearbyDrivers;

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      refreshActive();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void startDriversPolling(Lat location,
      {Lat? dropoff, int? serviceTypeId}) {
    _driversTimer?.cancel();
    _driversTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      refreshNearbyDrivers(location,
          dropoff: dropoff, serviceTypeId: serviceTypeId);
    });
  }

  void stopDriversPolling() {
    _driversTimer?.cancel();
    _driversTimer = null;
  }

  static const double nearbyRadiusKm = 3;

  Future<void> refreshNearbyDrivers(Lat location,
      {Lat? dropoff, int? serviceTypeId}) async {
    try {
      final data = await ApiClient.instance.get('/nearby-drivers', query: {
        'lat': location.latitude,
        'lng': location.longitude,
        'radius': nearbyRadiusKm,
        if (dropoff != null) 'dropoff_lat': dropoff.latitude,
        if (dropoff != null) 'dropoff_lng': dropoff.longitude,
        if (serviceTypeId != null) 'service_type_id': serviceTypeId,
      });
      _nearbyDrivers = _mergeFares((data['drivers'] as List)
          .map((e) => NearbyDriver.fromJson(e as Map<String, dynamic>))
          .toList());
      notifyListeners();
    } catch (_) {}
  }

  List<NearbyDriver> _mergeFares(List<NearbyDriver> parsed) {
    final prev = {for (final d in _nearbyDrivers) d.id: d.fare};
    return parsed.map((d) {
      if (d.fare == null && prev[d.id] != null) {
        return d.copyWith(fare: prev[d.id]);
      }
      return d;
    }).toList();
  }

  Future<void> refreshActive() async {
    try {
      final data = await ApiClient.instance.get('/trips/active');
      final trip = data['trip'];
      if (trip == null && _activeTrip != null && _activeTrip!.status == 5) {
        return;
      }
      _activeTrip = trip != null
          ? Trip.fromJson(trip as Map<String, dynamic>)
          : null;
      notifyListeners();
    } catch (_) {}
  }

  void clearActiveTrip() {
    _activeTrip = null;
    notifyListeners();
  }

  Future<Trip> requestTrip({
    required Lat pickup,
    required String pickupAddress,
    required Lat dropoff,
    required String dropoffAddress,
    int? serviceTypeId,
    int? driverId,
    int paymentMethod = 0,
    String? notes,
    bool isScheduled = false,
    DateTime? scheduledAt,
    String? couponCode,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.post('/trips/request', data: {
        'pickup_lat': pickup.latitude,
        'pickup_lng': pickup.longitude,
        'pickup_address': pickupAddress,
        'dropoff_lat': dropoff.latitude,
        'dropoff_lng': dropoff.longitude,
        'dropoff_address': dropoffAddress,
        if (serviceTypeId != null) 'service_type_id': serviceTypeId,
        if (driverId != null) 'driver_id': driverId,
        'payment_method': paymentMethod,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'is_scheduled': isScheduled,
        if (isScheduled && scheduledAt != null)
          'scheduled_at': scheduledAt.toIso8601String(),
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
      });
      final trip = Trip.fromJson(data['trip'] as Map<String, dynamic>);
      if (isScheduled) {
        _activeTrip = null;
      } else {
        _activeTrip = trip;
      }
      notifyListeners();
      return trip;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> cancelTrip(int tripId,
      {String? reason, String? reasonText}) async {
    await ApiClient.instance.post('/trips/$tripId/cancel', data: {
      if (reason != null) 'cancel_reason': reason,
      if (reasonText != null) 'cancel_reason_text': reasonText,
    });
    await refreshActive();
  }

  Future<String?> shareTrip(int tripId) async {
    final data = await ApiClient.instance.get('/trips/$tripId/share');
    return data['share_code'] as String?;
  }

  Future<void> updateDriverStatus(
    int tripId,
    int status, {
    double? actualFare,
    double? currentLat,
    double? currentLng,
    String? otp,
  }) async {
    await ApiClient.instance.post('/trips/$tripId/status', data: {
      'status': status,
      'otp_code': otp == null ? null : int.tryParse(otp),
      if (actualFare != null) 'actual_fare': actualFare,
      if (currentLat != null) 'current_lat': currentLat,
      if (currentLng != null) 'current_lng': currentLng,
    });
    await refreshActive();
  }

  Future<void> rateTrip(int tripId, int rating, String? comment, {double tip = 0}) async {
    await ApiClient.instance.post('/trips/$tripId/rate', data: {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (tip > 0) 'tip': tip,
    });
  }

  Future<List<Trip>> history() async {
    final data = await ApiClient.instance.get('/trips/history');
    return (data['trips'] as List)
        .map((e) => Trip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Trip>> upcoming() async {
    final data = await ApiClient.instance.get('/trips/upcoming');
    return (data['trips'] as List)
        .map((e) => Trip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TripStatusEvent>> statusHistory(int tripId) async {
    final data = await ApiClient.instance.get('/trips/$tripId/status-history');
    return (data['statuses'] as List)
        .map((e) => TripStatusEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Trip>> incoming() async {
    final data = await ApiClient.instance.get('/driver/incoming');
    return (data['trips'] as List)
        .map((e) => Trip.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptTrip(int tripId) async {
    await ApiClient.instance.post('/driver/trips/$tripId/accept');
    await refreshActive();
  }

  Future<void> rejectTrip(int tripId) async {
    await ApiClient.instance.post('/driver/trips/$tripId/reject');
  }

  Future<List<ChatMessageItem>> fetchMessages(int tripId) async {
    final data = await ApiClient.instance.get('/trips/$tripId/conversation');
    return (data['messages'] as List)
        .map((e) => ChatMessageItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendMessage(int tripId, String body) async {
    await ApiClient.instance.post('/trips/$tripId/messages', data: {'body': body});
  }

  Future<void> markMessagesRead(int tripId) async {
    try {
      await ApiClient.instance.post('/trips/$tripId/messages/read', data: {});
    } catch (_) {}
  }
}