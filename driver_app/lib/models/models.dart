export 'user.dart';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../providers/settings_provider.dart';

class Lat {
  final double latitude;
  final double longitude;

  Lat(this.latitude, this.longitude);

  Map<String, dynamic> toJson() => {'lat': latitude, 'lng': longitude};

  @override
  String toString() => '$latitude,$longitude';
}

class ServiceType {
  final int id;
  final String name;
  final String code;
  final int category;
  final String? icon;

  ServiceType({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    this.icon,
  });

  factory ServiceType.fromJson(Map<String, dynamic> json) => ServiceType(
        id: json['id'] as int,
        name: json['name'] as String,
        code: json['code'] as String,
        category: json['category'] as int? ?? 0,
        icon: json['icon'] as String?,
      );
}

class VehicleType {
  final int id;
  final String name;
  final String code;
  final int category;
  final String? icon;
  final double baseFare;
  final double perKm;
  final double perMinute;
  final double minFare;
  final int capacity;
  final double surgeMultiplier;

  VehicleType({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    this.icon,
    required this.baseFare,
    required this.perKm,
    required this.perMinute,
    required this.minFare,
    required this.capacity,
    this.surgeMultiplier = 1.0,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) => VehicleType(
        id: json['id'] as int,
        name: json['name'] as String,
        code: json['code'] as String,
        category: json['category'] as int? ?? 0,
        icon: json['icon'] as String?,
        baseFare: double.tryParse(json['base_fare']?.toString() ?? '0') ?? 0,
        perKm: double.tryParse(json['per_km']?.toString() ?? '0') ?? 0,
        perMinute: double.tryParse(json['per_minute']?.toString() ?? '0') ?? 0,
        minFare: double.tryParse(json['min_fare']?.toString() ?? '0') ?? 0,
        capacity: json['capacity'] as int? ?? 4,
        surgeMultiplier:
            double.tryParse(json['surge_multiplier']?.toString() ?? '1') ?? 1,
      );
}

class Driver {
  final int id;
  final int userId;
  final String? name;
  final String? phone;
  final String? photo;
  final bool isOnline;
  final bool isAvailable;
  final bool isVerified;
  final double ratingAvg;
  final int ratingCount;
  final int tripsCount;
  final double totalEarnings;
  final double commissionRate;
  final String? vehicleType;
  final double? currentLat;
  final double? currentLng;

  Driver({
    required this.id,
    required this.userId,
    this.name,
    this.phone,
    this.photo,
    required this.isOnline,
    required this.isAvailable,
    required this.isVerified,
    required this.ratingAvg,
    required this.ratingCount,
    required this.tripsCount,
    required this.totalEarnings,
    required this.commissionRate,
    this.vehicleType,
    this.currentLat,
    this.currentLng,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return Driver(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      name: user is Map ? user['name'] as String? : null,
      phone: user is Map ? user['phone']?.toString() : null,
      photo: user is Map ? user['avatar_url'] as String? : null,
      isOnline: json['is_online'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      ratingAvg: double.tryParse(json['rating_avg']?.toString() ?? '0') ?? 0,
      ratingCount: json['rating_count'] as int? ?? 0,
      tripsCount: json['trips_count'] as int? ?? 0,
      totalEarnings: double.tryParse(json['total_earnings']?.toString() ?? '0') ?? 0,
      commissionRate: double.tryParse(json['commission_rate']?.toString() ?? '0') ?? 0,
      vehicleType: json['vehicle_type'] as String?,
      currentLat: json['current_latitude'] != null
          ? double.tryParse(json['current_latitude'].toString())
          : null,
      currentLng: json['current_longitude'] != null
          ? double.tryParse(json['current_longitude'].toString())
          : null,
    );
  }
}

class VehicleInfo {
  final int? typeId;
  final String? typeName;
  final String? typeCode;
  final String? make;
  final String? model;
  final String? color;
  final String? plateNumber;
  final int seats;

  VehicleInfo({
    this.typeId,
    this.typeName,
    this.typeCode,
    this.make,
    this.model,
    this.color,
    this.plateNumber,
    this.seats = 4,
  });

  factory VehicleInfo.fromJson(Map<String, dynamic> json) => VehicleInfo(
        typeId: json['type_id'] as int?,
        typeName: json['type_name'] as String?,
        typeCode: json['type_code'] as String?,
        make: json['make'] as String?,
        model: json['model'] as String?,
        color: json['color'] as String?,
        plateNumber: json['plate_number'] as String?,
        seats: json['seats'] as int? ?? 4,
      );

  String get fullName => [make, model].whereType<String>().join(' ');
}

class NearbyDriver {
  final int id;
  final String? name;
  final String? photo;
  final double ratingAvg;
  final int ratingCount;
  final int tripsCount;
  final double lat;
  final double lng;
  final double distance;
  final int etaMinutes;
  final String? vehicleType;
  final VehicleInfo? vehicle;

  NearbyDriver({
    required this.id,
    this.name,
    this.photo,
    required this.ratingAvg,
    required this.ratingCount,
    required this.tripsCount,
    required this.lat,
    required this.lng,
    required this.distance,
    required this.etaMinutes,
    this.vehicleType,
    this.vehicle,
  });

  factory NearbyDriver.fromJson(Map<String, dynamic> json) {
    final v = json['vehicle'];
    return NearbyDriver(
      id: json['id'] as int,
      name: json['name'] as String?,
      photo: json['photo'] as String?,
      ratingAvg: double.tryParse(json['rating_avg']?.toString() ?? '0') ?? 0,
      ratingCount: json['rating_count'] as int? ?? 0,
      tripsCount: json['trips_count'] as int? ?? 0,
      lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0,
      lng: double.tryParse(json['lng']?.toString() ?? '0') ?? 0,
      distance: double.tryParse(json['distance']?.toString() ?? '0') ?? 0,
      etaMinutes: json['eta_minutes'] as int? ?? 1,
      vehicleType: json['vehicle_type'] as String?,
      vehicle: v is Map ? VehicleInfo.fromJson(Map<String, dynamic>.from(v)) : null,
    );
  }
}

class ChatMessageItem {
  final int id;
  final String body;
  final int senderId;
  final String? senderName;
  final int senderType;
  final bool isRead;
  final DateTime createdAt;

  ChatMessageItem({
    required this.id,
    required this.body,
    required this.senderId,
    this.senderName,
    required this.senderType,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    final s = json['sender'];
    return ChatMessageItem(
      id: json['id'] as int,
      body: json['body'] as String? ?? '',
      senderId: s is Map ? s['id'] as int? ?? 0 : (json['sender_id'] as int? ?? 0),
      senderName: s is Map ? s['name'] as String? : null,
      senderType: s is Map ? s['user_type'] as int? ?? 0 : 0,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class Trip {
  final int id;
  final String tripNumber;
  final int status;
  final int paymentMethod;
  final int paymentStatus;
  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? dropoffAddress;
  final double? distanceKm;
  final int? durationMinutes;
  final double? estimatedFare;
  final double? actualFare;
  final double platformFee;
  final double driverEarnings;
  final int? driverId;
  final double? currentLat;
  final double? currentLng;
  final DateTime? scheduledAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? cancelReason;
  final String? cancelReasonText;
  final String? shareCode;
  final bool isScheduled;
  final ServiceType? serviceType;
  final Driver? driver;
  final VehicleInfo? vehicle;
  final Map<String, dynamic>? raw;
  final int? otpCode;
  final String? customerName;
  final String? customerAvatar;
  final String? customerPhone;

  Trip({
    required this.id,
    required this.tripNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.dropoffAddress,
    this.distanceKm,
    this.durationMinutes,
    this.estimatedFare,
    this.actualFare,
    required this.platformFee,
    required this.driverEarnings,
    this.driverId,
    this.currentLat,
    this.currentLng,
    this.scheduledAt,
    this.acceptedAt,
    this.completedAt,
    this.cancelReason,
    this.cancelReasonText,
    this.shareCode,
    required this.isScheduled,
    this.serviceType,
    this.driver,
    this.vehicle,
    this.raw,
    this.otpCode,
    this.customerName,
    this.customerAvatar,
    this.customerPhone,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    final st = json['service_type'];
    final drv = json['driver'];
    return Trip(
      id: json['id'] as int,
      tripNumber: json['trip_number'] as String? ?? '',
      status: json['status'] as int? ?? 0,
      paymentMethod: json['payment_method'] as int? ?? 0,
      paymentStatus: json['payment_status'] as int? ?? 0,
      pickupLat: double.tryParse(json['pickup_lat']?.toString() ?? '0') ?? 0,
      pickupLng: double.tryParse(json['pickup_lng']?.toString() ?? '0') ?? 0,
      pickupAddress: json['pickup_address'] as String? ?? '',
      dropoffLat: json['dropoff_lat'] != null ? double.tryParse(json['dropoff_lat'].toString()) : null,
      dropoffLng: json['dropoff_lng'] != null ? double.tryParse(json['dropoff_lng'].toString()) : null,
      dropoffAddress: json['dropoff_address'] as String?,
      distanceKm: json['distance_km'] != null ? double.tryParse(json['distance_km'].toString()) : null,
      durationMinutes: json['duration_minutes'] != null ? int.tryParse(json['duration_minutes'].toString()) : null,
      estimatedFare: json['estimated_fare'] != null ? double.tryParse(json['estimated_fare'].toString()) : null,
      actualFare: json['actual_fare'] != null ? double.tryParse(json['actual_fare'].toString()) : null,
      platformFee: double.tryParse(json['platform_fee']?.toString() ?? '0') ?? 0,
      driverEarnings: double.tryParse(json['driver_earnings']?.toString() ?? '0') ?? 0,
      driverId: json['driver_id'] as int?,
      currentLat: json['current_lat'] != null
          ? double.tryParse(json['current_lat'].toString())
          : null,
      currentLng: json['current_lng'] != null
          ? double.tryParse(json['current_lng'].toString())
          : null,
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse(json['scheduled_at']) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.tryParse(json['accepted_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at']) : null,
      cancelReason: json['cancel_reason'] as String?,
      cancelReasonText: json['cancel_reason_text'] as String?,
      shareCode: json['share_code'] as String?,
      isScheduled: json['is_scheduled'] as bool? ?? false,
      otpCode: json['otp_code'] != null
          ? int.tryParse(json['otp_code'].toString())
          : null,
      customerName: (json['customer'] is Map)
          ? (json['customer'] as Map)['name'] as String?
          : null,
      customerAvatar: (json['customer'] is Map)
          ? (json['customer'] as Map)['avatar_url'] as String?
          : null,
      customerPhone: (json['customer'] is Map)
          ? (json['customer'] as Map)['phone']?.toString()
          : null,
      serviceType: st is Map ? ServiceType.fromJson(Map<String, dynamic>.from(st)) : null,
      driver: drv is Map ? Driver.fromJson(Map<String, dynamic>.from(drv)) : null,
      vehicle: _parseVehicle(json['vehicle']),
      raw: json,
    );
  }

  static VehicleInfo? _parseVehicle(dynamic json) {
    if (json is Map && json.isNotEmpty) {
      return VehicleInfo.fromJson(Map<String, dynamic>.from(json));
    }
    return null;
  }

  LatLng? get driverLive {
    final d = driver;
    final lat = currentLat ?? d?.currentLat;
    final lng = currentLng ?? d?.currentLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String get statusLabel {
    switch (status) {
      case 0:
        return L10n.t('st_pending');
      case 1:
        return L10n.t('st_searching');
      case 2:
        return L10n.t('st_accepted');
      case 3:
        return L10n.t('st_arrived');
      case 4:
        return L10n.t('st_in_progress');
      case 5:
        return L10n.t('st_completed');
      case 6:
        return L10n.t('st_cancelled');
      default:
        return L10n.t('st_expired');
    }
  }
}

class WalletTransaction {
  final int id;
  final double amount;
  final double balanceAfter;
  final int type;
  final String? description;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.type,
    this.description,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as int,
        amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
        balanceAfter: double.tryParse(json['balance_after']?.toString() ?? '0') ?? 0,
        type: json['type'] as int? ?? 0,
        description: json['description'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}

class Complaint {
  final int id;
  final int category;
  final String? subject;
  final String description;
  final int status;
  final int? tripId;
  final String? resolution;
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.category,
    this.subject,
    required this.description,
    required this.status,
    this.tripId,
    this.resolution,
    required this.createdAt,
  });

  String get categoryLabel {
    const labels = {
      0: 'other',
      1: 'cat_driver_behavior',
      2: 'cat_route',
      3: 'cat_pricing',
      4: 'cat_safety',
      5: 'cat_app',
      6: 'cat_support',
    };
    return L10n.t(labels[category] ?? 'other');
  }

  String get statusLabel {
    const labels = ['cs_open', 'cs_reviewing', 'cs_resolved', 'cs_closed'];
    return status >= 0 && status < labels.length
        ? L10n.t(labels[status])
        : L10n.t('cs_open');
  }

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
        id: json['id'] as int,
        category: json['category'] as int? ?? 0,
        subject: json['subject'] as String?,
        description: json['description'] as String? ?? '',
        status: json['status'] as int? ?? 0,
        tripId: json['trip_id'] as int?,
        resolution: json['resolution'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}

class FavoritePlace {
  final int id;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final int type;

  FavoritePlace({
    required this.id,
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    required this.type,
  });

  String get typeLabel {
    const labels = ['home', 'work', 'other'];
    return type >= 0 && type < labels.length
        ? L10n.t(labels[type])
        : L10n.t('other');
  }

  IconData get icon {
    switch (type) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.work;
      default:
        return Icons.place;
    }
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> json) => FavoritePlace(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        address: json['address'] as String?,
        lat: double.tryParse(json['lat']?.toString() ?? '0') ?? 0,
        lng: double.tryParse(json['lng']?.toString() ?? '0') ?? 0,
        type: json['type'] as int? ?? 2,
      );
}

class CouponItem {
  final int id;
  final String code;
  final String? title;
  final String? description;
  final int type;
  final double value;
  final double? maxDiscount;
  final double minOrderAmount;

  CouponItem({
    required this.id,
    required this.code,
    this.title,
    this.description,
    required this.type,
    required this.value,
    this.maxDiscount,
    required this.minOrderAmount,
  });

  bool get isPercent => type == 1;

  String get discountLabel => isPercent
      ? L10n.f('offer_discount_percent', {'p': '${value.round()}'})
      : L10n.f('offer_discount_amount', {'v': '${value.round()}'});

  factory CouponItem.fromJson(Map<String, dynamic> json) => CouponItem(
        id: json['id'] as int,
        code: json['code'] as String? ?? '',
        title: json['title'] as String?,
        description: json['description'] as String?,
        type: json['type'] as int? ?? 0,
        value: double.tryParse(json['value']?.toString() ?? '0') ?? 0,
        maxDiscount: json['max_discount'] == null
            ? null
            : double.tryParse(json['max_discount'].toString()),
        minOrderAmount:
            double.tryParse(json['min_order_amount']?.toString() ?? '0') ?? 0,
      );
}

class Ad {
  final int id;
  final String? title;
  final String? subtitle;
  final String imageUrl;
  final String? linkUrl;
  final int target;
  final int mediaType;
  final double? ratio;
  final int? duration;

  Ad({
    required this.id,
    this.title,
    this.subtitle,
    required this.imageUrl,
    this.linkUrl,
    this.target = 0,
    this.mediaType = 0,
    this.ratio,
    this.duration,
  });

  bool get hasLink => (linkUrl ?? '').trim().isNotEmpty;
  bool get isImage => mediaType == 0;
  bool get isVideo => mediaType == 1;
  bool get isYoutube => mediaType == 2;

  String? get youtubeId {
    if (!isYoutube) return null;
    final m = RegExp(
      r'(?:youtu\.be/|youtube\.com/(?:watch\?v=|embed/|shorts/|v/))([A-Za-z0-9_-]{11})',
    ).firstMatch(imageUrl);
    return m?.group(1);
  }

  factory Ad.fromJson(Map<String, dynamic> json) => Ad(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        imageUrl: json['image_url'] as String? ?? '',
        linkUrl: json['link_url'] as String?,
        target: json['target'] as int? ?? 0,
        mediaType: json['media_type'] as int? ?? 0,
        ratio: (json['ratio'] as num?)?.toDouble(),
        duration: (json['duration'] as num?)?.toInt(),
      );
}

class FavoriteDriverItem {
  final int driverId;
  final String? name;
  final String? photo;
  final double ratingAvg;
  final int ratingCount;
  final int tripsCount;
  final bool isOnline;
  final bool isAvailable;
  final String? vehicleType;

  FavoriteDriverItem({
    required this.driverId,
    this.name,
    this.photo,
    required this.ratingAvg,
    required this.ratingCount,
    required this.tripsCount,
    required this.isOnline,
    required this.isAvailable,
    this.vehicleType,
  });

  factory FavoriteDriverItem.fromJson(Map<String, dynamic> json) =>
      FavoriteDriverItem(
        driverId: json['driver_id'] as int,
        name: json['name'] as String?,
        photo: json['photo'] as String?,
        ratingAvg: double.tryParse(json['rating_avg']?.toString() ?? '0') ?? 0,
        ratingCount: json['rating_count'] as int? ?? 0,
        tripsCount: json['trips_count'] as int? ?? 0,
        isOnline: json['is_online'] as bool? ?? false,
        isAvailable: json['is_available'] as bool? ?? false,
        vehicleType: json['vehicle_type'] as String?,
      );
}

class TripStatusEvent {
  final int fromStatus;
  final int toStatus;
  final String? note;
  final String? actorType;
  final DateTime createdAt;

  TripStatusEvent({
    required this.fromStatus,
    required this.toStatus,
    this.note,
    this.actorType,
    required this.createdAt,
  });

  String get label {
    switch (toStatus) {
      case 0:
        return L10n.t('se_waiting');
      case 1:
        return L10n.t('se_searching');
      case 2:
        return L10n.t('se_accepted');
      case 3:
        return L10n.t('se_arrived');
      case 4:
        return L10n.t('se_ontheway');
      case 5:
        return L10n.t('se_completed');
      case 6:
        return L10n.t('se_cancelled');
      case 7:
        return L10n.t('se_waiting_payment');
      default:
        return L10n.f('unknown_status', {'n': '$toStatus'});
    }
  }

  factory TripStatusEvent.fromJson(Map<String, dynamic> json) =>
      TripStatusEvent(
        fromStatus: json['from_status'] as int? ?? 0,
        toStatus: json['to_status'] as int? ?? 0,
        note: json['note'] as String?,
        actorType: json['actor_type'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}

class CallMaskInfo {
  final String relayCode;
  final String relayPhone;
  final String message;

  CallMaskInfo({
    required this.relayCode,
    required this.relayPhone,
    required this.message,
  });

  factory CallMaskInfo.fromJson(Map<String, dynamic> json) => CallMaskInfo(
        relayCode: json['relay_code'] as String? ?? '',
        relayPhone: json['relay_phone'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );
}

class DriverVehicle {
  final int id;
  final String make;
  final String model;
  final String? color;
  final String plateNumber;
  final int seats;
  final bool isActive;
  final String? typeName;

  DriverVehicle({
    required this.id,
    required this.make,
    required this.model,
    this.color,
    required this.plateNumber,
    required this.seats,
    required this.isActive,
    this.typeName,
  });

  String get fullName => [typeName, make, model, color]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' · ');

  factory DriverVehicle.fromJson(Map<String, dynamic> json) {
    final vt = json['vehicle_type'];
    return DriverVehicle(
      id: json['id'] as int,
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      color: json['color'] as String?,
      plateNumber: json['plate_number'] as String? ?? '',
      seats: json['seats'] as int? ?? 4,
      isActive: json['is_active'] as bool? ?? false,
      typeName: vt is Map ? vt['name'] as String? : null,
    );
  }
}

class WithdrawalItem {
  final int id;
  final double amount;
  final String? status;
  final String? paymentMethod;
  final DateTime createdAt;

  WithdrawalItem({
    required this.id,
    required this.amount,
    this.status,
    this.paymentMethod,
    required this.createdAt,
  });

  String get statusLabel {
    const labels = ['wd_pending', 'wd_paid', 'wd_rejected'];
    final s = int.tryParse(status ?? '0') ?? 0;
    return s < labels.length ? L10n.t(labels[s]) : status ?? '';
  }

  factory WithdrawalItem.fromJson(Map<String, dynamic> json) =>
      WithdrawalItem(
        id: json['id'] as int,
        amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
        status: json['status']?.toString(),
        paymentMethod: json['payment_method'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}

class Coupon {
  final int id;
  final String code;
  final String? title;
  final String? description;
  final int type;
  final double value;
  final double? maxDiscount;
  final double minOrderAmount;

  Coupon({
    required this.id,
    required this.code,
    this.title,
    this.description,
    required this.type,
    required this.value,
    this.maxDiscount,
    required this.minOrderAmount,
  });

  String get discountLabel => type == 1
      ? '${value.toStringAsFixed(0)}%'
      : L10n.f('egp_amount', {'n': value.toStringAsFixed(0)});

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        id: json['id'] as int,
        code: json['code'] as String? ?? '',
        title: json['title'] as String?,
        description: json['description'] as String?,
        type: json['type'] as int? ?? 0,
        value: double.tryParse(json['value']?.toString() ?? '0') ?? 0,
        maxDiscount: json['max_discount'] != null
            ? double.tryParse(json['max_discount'].toString())
            : null,
        minOrderAmount:
            double.tryParse(json['min_order_amount']?.toString() ?? '0') ?? 0,
      );
}