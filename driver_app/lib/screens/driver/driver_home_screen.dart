import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../core/service/request_alert.dart';
import '../../core/widgets/app_tile_layer.dart';
import '../../providers/ads_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/trip_provider.dart';
import '../widgets/ads_banner.dart';
import 'driver_apply_screen.dart';
import 'driver_requests_screen.dart';
import 'driver_active_trip_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_vehicles_screen.dart';
import 'driver_profile_screen.dart';
import 'about_screen.dart';
import '../auth/login_screen.dart';
import '../../providers/settings_provider.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final MapController _mapController = MapController();
  LatLng? _current;
  Timer? _locationTimer;
  Timer? _incomingTimer;
  Timer? _alertTimer;
  final Set<int> _seenRequests = {};
  bool _pollingIncoming = false;
  Trip? _alertTrip;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().loadProfile();
      context.read<TripProvider>().refreshActive();
      context.read<AdsProvider>().load(target: 'driver');
      _startLocation();
      _startIncomingPoll();
    });
  }

  void _startIncomingPoll() {
    _pollIncoming();
    _incomingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _pollIncoming();
    });
  }

  Future<void> _pollIncoming() async {
    if (_pollingIncoming) return;
    _pollingIncoming = true;
    try {
      final trips = await context.read<TripProvider>().incoming();
      if (!mounted) return;
      final online = context.read<DriverProvider>().driver?.isOnline ?? false;
      final trip = context.read<TripProvider>().activeTrip;
      final busy = trip != null && const [2, 3, 4].contains(trip.status);
      Trip? fresh;
      if (_alertTrip == null && trips.isNotEmpty) {
        for (final t in trips) {
          if (!_seenRequests.contains(t.id)) {
            fresh = t;
            break;
          }
        }
      }
      for (final t in trips) {
        _seenRequests.add(t.id);
      }
      if (!online || busy || trips.isEmpty || fresh == null) {
        if (_alertTrip != null && mounted) {
          setState(() => _alertTrip = null);
        }
        return;
      }
      setState(() => _alertTrip = fresh);
      RequestAlert.ring();
      _alertTimer?.cancel();
      _alertTimer = Timer(const Duration(seconds: 20), () {
        if (mounted) setState(() => _alertTrip = null);
      });
    } catch (_) {} finally {
      _pollingIncoming = false;
    }
  }

  void _openIncoming() {
    setState(() => _alertTrip = null);
    _alertTimer?.cancel();
    _incomingTimer?.cancel();
    _incomingTimer = null;
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const DriverRequestsScreen()),
        )
        .then((_) {
      context.read<TripProvider>().refreshActive();
      if (_incomingTimer == null) {
        _startIncomingPoll();
      }
    });
  }

  Future<void> _startLocation() async {
    await _locate();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _locate();
    });
  }

  Future<bool> _ensureLocationPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    final denied = perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever ||
        !await Geolocator.isLocationServiceEnabled();
    if (mounted && denied != _permissionDenied) {
      setState(() => _permissionDenied = denied);
    }
    return !denied;
  }

  Future<void> _locate() async {
    if (!await _ensureLocationPermission()) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _current = LatLng(pos.latitude, pos.longitude);
        _permissionDenied = false;
      });
      _moveToCurrent();
      _reportLocation();
    } catch (_) {
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (!mounted) return;
        if (pos != null) {
          setState(() {
            _current = LatLng(pos.latitude, pos.longitude);
          });
          _moveToCurrent();
          _reportLocation();
        }
      } catch (_) {}
    }
  }

  void _moveToCurrent() {
    final c = _current;
    if (c == null) return;
    _mapController.move(c, 15);
  }

  void _reportLocation() {
    final c = _current;
    if (c == null) return;
    context
        .read<DriverProvider>()
        .updateLocation(c.latitude, c.longitude);
  }

  void _openSettings() async {
    await Geolocator.openAppSettings();
    if (mounted) {
      setState(() {
        _permissionDenied = false;
      });
      await _locate();
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _incomingTimer?.cancel();
    _alertTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleBusy() async {
    try {
      await context.read<DriverProvider>().toggleAvailability();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>().driver;
    final trip = context.watch<TripProvider>().activeTrip;
    final hasActiveTrip = trip != null && const [2, 3, 4].contains(trip.status);

    if (driver == null || driver.isVerified != true) {
      return const DriverApplyScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('خط سيري سائق'),
        actions: [
          IconButton(
            tooltip: L10n.t('earnings_withdrawals'),
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DriverEarningsScreen()),
            ),
          ),
          IconButton(
            tooltip: L10n.t('vehicles'),
            icon: const Icon(Icons.directions_car),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DriverVehiclesScreen()),
            ),
          ),
          IconButton(
            tooltip: L10n.t('about_app'),
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _current ?? const LatLng(30.0444, 31.2357),
              initialZoom: 4,
            ),
            children: [
              const AppTileLayer(),
              if (_current != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _current!,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.local_taxi,
                          color: Colors.blue, size: 40),
                    ),
                  ],
                ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: _current == null
                ? Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _permissionDenied
                          ? AppColors.danger
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_permissionDenied)
                          IconButton(
                            onPressed: _openSettings,
                            color: Colors.white,
                            icon: const Icon(Icons.settings),
                            tooltip: 'افتح الإعدادات',
                          ),
                        Flexible(
                          child: Text(
                            _permissionDenied
                                ? 'تعذر تحديد موقعك — فعّل خدمات تحديد الموقع للتطبيق'
                                : 'جارٍ تحديد موقعك على الخريطة…',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            top: 64,
            left: 16,
            right: 16,
            child: _alertTrip != null
                ? Material(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openIncoming,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active,
                                color: AppColors.danger),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    L10n.t('new_request'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    L10n.t('arrival_notice'),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() => _alertTrip = null);
                              },
                              icon: const Icon(Icons.close, size: 20),
                              tooltip: 'إخفاء',
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer<AdsProvider>(
                    builder: (context, ads, _) => ads.ads.isEmpty
                        ? const SizedBox.shrink()
                        : const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: AdsBanner(target: 'driver', height: 120),
                          ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DriverProfileScreen(),
                      ),
                    ),
                    child: Row(
                      children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.skyLight,
                        child: const Icon(Icons.person,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver.name ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (driver.vehicleType != null)
                              Text(
                                driver.vehicleType!,
                                style: TextStyle(
                                    color: context.onSurfaceVariant,
                                    fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            L10n.t('rating'),
                            style:
                                TextStyle(color: context.onSurfaceVariant),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: AppColors.secondary, size: 20),
                              Text(
                                '${driver.ratingAvg}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _toggleBusy,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: driver.isOnline
                            ? AppColors.danger
                            : AppColors.primary,
                      ),
                      icon: Icon(
                        driver.isOnline
                            ? Icons.power_settings_new
                            : Icons.power,
                      ),
                      label: Text(
                        driver.isOnline
                            ? L10n.t('go_offline')
                            : L10n.t('go_online'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: hasActiveTrip
                        ? ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DriverActiveTripScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: AppColors.primaryDark,
                            ),
                            icon: const Icon(Icons.navigation),
                            label: Text(
                              L10n.f('active_trip_title',
                                  {'status': trip.statusLabel}),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const DriverRequestsScreen(),
                                    ),
                                  )
                                  .then((_) => context
                                      .read<TripProvider>()
                                      .refreshActive());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.08),
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                            icon: const Icon(Icons.notifications_outlined),
                            label: Text(L10n.t('view_requests')),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}