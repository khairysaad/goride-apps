import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../core/network/route_service.dart';
import '../../core/widgets/app_tile_layer.dart';
import '../../models/models.dart';
import '../../providers/driver_provider.dart';
import '../../providers/trip_provider.dart';
import '../../core/navigation/voice_guidance.dart';
import 'chat_screen.dart';
import '../../providers/settings_provider.dart';

class DriverActiveTripScreen extends StatefulWidget {
  const DriverActiveTripScreen({super.key});

  @override
  State<DriverActiveTripScreen> createState() => _DriverActiveTripScreenState();
}

class _DriverActiveTripScreenState extends State<DriverActiveTripScreen> {
  final MapController _mapController = MapController();
  final _otpController = TextEditingController();
  bool _sending = false;
  bool _loadingRoute = false;
  List<LatLng>? _route;
  double _routeDistance = 0;
  int _routeDuration = 0;
  LatLng? _current;
  bool _follow = true;
  Timer? _locationTimer;
  RouteResult? _lastRoute;
  LatLng? _lastRerouteAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().startPolling();
      context.read<TripProvider>().refreshActive();
      VoiceGuidance.instance.init();
      _loadRoute();
      _startLocation();
    });
  }

  @override
  void dispose() {
    context.read<TripProvider>().stopPolling();
    _locationTimer?.cancel();
    _otpController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _startLocation() async {
    await _locate();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _locate();
    });
  }

  Future<void> _locate() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever ||
        !await Geolocator.isLocationServiceEnabled()) {
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final ll = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _current = ll;
      });
      final trip = context.read<TripProvider>().activeTrip;
      final inProgress = trip?.status == 4;
      VoiceGuidance.instance.onLocationChanged(ll, inProgress ? _lastRoute : null);
      try {
        await context.read<DriverProvider>().updateLocation(ll.latitude, ll.longitude);
      } catch (_) {}
      if (_follow && mounted) {
        _mapController.move(ll, _mapController.camera.zoom);
      }
      if (trip != null && const [2, 3, 4].contains(trip.status)) {
        _rerouteIfNeeded(ll, trip);
      }
    } catch (_) {
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          final ll = LatLng(pos.latitude, pos.longitude);
          if (!mounted) return;
          setState(() {
            _current = ll;
          });
          final trip = context.read<TripProvider>().activeTrip;
          VoiceGuidance.instance
              .onLocationChanged(ll, trip?.status == 4 ? _lastRoute : null);
          try {
            await context.read<DriverProvider>().updateLocation(ll.latitude, ll.longitude);
          } catch (_) {}
          if (_follow && mounted) {
            _mapController.move(ll, _mapController.camera.zoom);
          }
        }
      } catch (_) {}
    }
  }

  void _rerouteIfNeeded(LatLng from, Trip trip) async {
    final end = (trip.dropoffLat != null && trip.dropoffLng != null)
        ? LatLng(trip.dropoffLat!, trip.dropoffLng!)
        : null;
    if (end == null) return;
    final last = _lastRerouteAt;
    if (last != null) {
      final dx = (from.latitude - last.latitude).abs();
      final dy = (from.longitude - last.longitude).abs();
      if (dx + dy < 0.0012) return;
    }
    _lastRerouteAt = from;
    try {
      final result = await RouteService.getRoute(from, end);
      if (!mounted) return;
      setState(() {
        _route = result.points;
        _routeDistance = result.distanceKm;
        _routeDuration = result.durationMinutes;
        _lastRoute = result;
      });
      VoiceGuidance.instance.onRoute(result);
    } catch (_) {}
  }

  Future<void> _loadRoute() async {
    final trip = context.read<TripProvider>().activeTrip;
    if (trip == null || trip.dropoffLat == null || trip.dropoffLng == null) {
      return;
    }
    if (_loadingRoute) return;
    setState(() => _loadingRoute = true);
    final pickup = LatLng(trip.pickupLat, trip.pickupLng);
    final dropoff = LatLng(trip.dropoffLat!, trip.dropoffLng!);
    try {
      final result = await RouteService.getRoute(pickup, dropoff);
      if (!mounted) return;
      setState(() {
        _route = result.points;
        _routeDistance = result.distanceKm;
        _routeDuration = result.durationMinutes;
        _lastRoute = result;
        _loadingRoute = false;
      });
      VoiceGuidance.instance.onRoute(result);
      _fitRoute();
    } catch (_) {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _fitRoute() {
    final points = _route;
    if (points == null || points.length < 2) return;
    try {
      _mapController.fitCamera(CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(40, 60, 40, 80),
      ));
    } catch (_) {}
  }

  Future<void> _update(int status, {String? otp}) async {
    final trip = context.read<TripProvider>().activeTrip;
    if (trip == null) return;
    setState(() => _sending = true);
    try {
      final updated = await context.read<TripProvider>().updateDriverStatus(
            trip.id,
            status,
            otp: otp,
          );
      if (status == 5) {
        if (mounted) _showCompletionSummary(updated);
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) _loadRoute();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _cancelTrip() async {
    final trip = context.read<TripProvider>().activeTrip;
    if (trip == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('cancel_trip')),
        content: Text(L10n.t('cancel_trip_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.t('cancel_trip')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await context.read<TripProvider>().cancelActiveTrip(trip.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showCompletionSummary(Map<String, dynamic>? trip) {
    if (trip == null) return;
    final actual = double.tryParse(trip['actual_fare']?.toString() ?? '') ??
        double.tryParse(trip['estimated_fare']?.toString() ?? '');
    final earned = double.tryParse(trip['driver_earnings']?.toString() ?? '');
    final fee = double.tryParse(trip['platform_fee']?.toString() ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle,
            color: AppColors.success, size: 40),
        title: Text(
          L10n.t('trip_completed_title'),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actual != null)
              _summaryRow(L10n.t('final_fare'),
                  L10n.f('egp_amount', {'n': actual.toStringAsFixed(2)})),
            if (earned != null)
              _summaryRow(
                  L10n.t('your_earnings'),
                  L10n.f('egp_amount', {'n': earned.toStringAsFixed(2)}),
                  highlight: true),
            if (fee != null)
              _summaryRow(L10n.t('platform_fee'),
                  L10n.f('egp_amount', {'n': fee.toStringAsFixed(2)})),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.t('done')),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.onSurfaceVariant)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: highlight ? 18 : 15,
              color: highlight ? AppColors.success : context.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>().activeTrip;

    if (trip == null || !const [2, 3, 4].contains(trip.status)) {
      return Scaffold(
        appBar: AppBar(title: Text(L10n.t('trip'))),
        body: Center(
          child: Text(
            L10n.t('no_active_trip'),
            style: TextStyle(color: context.onSurfaceVariant),
          ),
        ),
      );
    }

    final pickup = LatLng(trip.pickupLat, trip.pickupLng);
    final dropoff = trip.dropoffLat != null && trip.dropoffLng != null
        ? LatLng(trip.dropoffLat!, trip.dropoffLng!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(L10n.f('active_trip_title', {'status': trip.statusLabel})),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pickup,
                initialZoom: 13,
                onMapEvent: (e) {
                  if (e is MapEventMove &&
                      const [
                        MapEventSource.dragStart,
                        MapEventSource.onDrag,
                        MapEventSource.dragEnd,
                        MapEventSource.flingAnimationController,
                      ].contains(e.source) &&
                      _follow) {
                    setState(() => _follow = false);
                  }
                },
              ),
              children: [
                const AppTileLayer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pickup,
                      width: 38,
                      height: 38,
                      child: Icon(Icons.trip_origin,
                          color: Theme.of(context).colorScheme.primary,
                          size: 34),
                    ),
                    if (dropoff != null)
                      Marker(
                        point: dropoff,
                        width: 38,
                        height: 38,
                        child: const Icon(Icons.place,
                            color: AppColors.secondary, size: 34),
                      ),
                    if (_current != null)
                      Marker(
                        point: _current!,
                        width: 42,
                        height: 42,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary, width: 2),
                          ),
                          child: Icon(Icons.local_taxi,
                              color: Theme.of(context).colorScheme.primary,
                              size: 22),
                        ),
                      ),
                  ],
                ),
                if (_route != null && _route!.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _route!,
                        color: AppColors.secondary,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
              ],
            ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: IconButton(
                      tooltip: L10n.t('recenter'),
                      icon: Icon(
                        _follow ? Icons.my_location : Icons.my_location_outlined,
                        color: _follow
                            ? Theme.of(context).colorScheme.primary
                            : context.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() => _follow = true);
                        if (_current != null) {
                          _mapController.move(
                            _current!,
                            _mapController.camera.zoom,
                          );
                        } else if (_route != null && _route!.isNotEmpty) {
                          _fitRoute();
                        } else {
                          _mapController.move(
                            pickup,
                            _mapController.camera.zoom,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(Icons.place, trip.pickupAddress),
                  const SizedBox(height: 8),
                  _row(Icons.location_on,
                      trip.dropoffAddress ?? L10n.t('no_dropoff')),
                  const SizedBox(height: 8),
                  if (trip.distanceKm != null || _routeDistance > 0)
                    Row(
                      children: [
                        Text(
                          L10n.f('dist_dur', {
                            'dist': (trip.distanceKm ?? _routeDistance)
                                .toStringAsFixed(1),
                            'dur':
                                '${trip.durationMinutes ?? _routeDuration}',
                          }),
                          style:
                              TextStyle(color: context.onSurfaceVariant),
                        ),
                        const Spacer(),
                        Text(
                          L10n.f('trip_cost', {
                            'fare':
                                (trip.estimatedFare ?? 0).toStringAsFixed(0),
                          }),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      L10n.t('loading_route'),
                      style: TextStyle(
                          color: context.onSurfaceVariant, fontSize: 13),
                    ),
                  const SizedBox(height: 16),
                  if (trip.customerName != null) _customerRow(trip),
                  const SizedBox(height: 12),
                  if (trip.status == 2)
                    ElevatedButton(
                      onPressed: _sending ? null : () => _update(3),
                      child: Text(L10n.t('drv_arrived')),
                    )
                  else if (trip.status == 3)
                    _otpPanel(trip)
                  else if (trip.status == 4)
                    ElevatedButton(
                      onPressed: _sending
                          ? null
                          : () => _update(5),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      child: _sending
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(L10n.t('complete_trip')),
                    ),
                  const SizedBox(height: 8),
                  if (const [2, 3].contains(trip.status))
                    OutlinedButton.icon(
                      onPressed: _sending ? null : _cancelTrip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(L10n.t('cancel_trip')),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TripChatScreen(
                          tripId: trip.id,
                          title: L10n.t('chat_customer'),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble, size: 18),
                    label: Text(L10n.t('chat_customer')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerRow(Trip trip) {
    final phone = trip.raw?['customer'] is Map
        ? (trip.raw?['customer'] as Map)['phone']?.toString()
        : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.skyLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (trip.customerAvatar != null && trip.customerAvatar!.isNotEmpty)
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(trip.customerAvatar!),
            )
          else
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: Icon(Icons.person,
                  color: Theme.of(context).colorScheme.primary),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.t('customer_info'),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  trip.customerName!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                if (trip.customerPhone != null &&
                    trip.customerPhone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        trip.customerPhone!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (phone != null && phone.isNotEmpty)
            IconButton(
              tooltip: L10n.t('chat_customer'),
              icon: const Icon(Icons.chat_bubble, color: AppColors.primary),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TripChatScreen(
                    tripId: trip.id,
                    title: L10n.t('chat_customer'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _otpPanel(Trip trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 4,
          decoration: InputDecoration(
            hintText: L10n.t('otp_input'),
            isDense: true,
            counterText: '',
            prefixIcon: const Icon(Icons.password, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _sending
              ? null
              : () => _update(4, otp: _otpController.text),
          child: _sending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(L10n.t('drv_started')),
        ),
      ],
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}