import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_theme.dart';
import '../../config/api_config.dart';
import '../../core/network/route_service.dart';
import '../../core/widgets/app_tile_layer.dart';
import '../../providers/trip_provider.dart';
import 'chat_screen.dart';
import 'sos_screen.dart';
import '../../providers/settings_provider.dart';
class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  int _rating = 5;
  double _tip = 0;
  final _comment = TextEditingController();
  final _customTipController = TextEditingController();
  final Set<String> _tags = {};
  static const _rateTags = [
    'tag_wrong_route',
    'tag_aggressive',
    'tag_late',
    'tag_dirty_car',
    'tag_unprofessional',
  ];
  List<LatLng> _routePoints = [];
  bool _follow = true;
  bool _mapReady = false;
  DateTime? _lastReroute;
  LatLng? _lastDriverPos;
  int _notifiedStatus = 0;
  bool _endedHandled = false;
  late final AnimationController _carAnim;
  LatLng? _carFrom;
  LatLng? _carTo;
  TripProvider? _tripProvider;

  @override
  void initState() {
    super.initState();
    _tripProvider = context.read<TripProvider>();
    _carAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _carAnim.addListener(_carTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tripProvider!.startPolling();
      _loadRoute();
      final trip = _tripProvider!.activeTrip;
      if (trip != null) _notifiedStatus = trip.status;
    });
    _tripProvider!.addListener(_onPoll);
  }

  @override
  void dispose() {
    _carAnim.dispose();
    _tripProvider?.removeListener(_onPoll);
    _tripProvider?.stopPolling();
    super.dispose();
  }

  LatLng? get _carShown {
    final to = _carTo;
    if (to == null) return null;
    if (_carAnim.isAnimating) {
      final from = _carFrom ?? to;
      final t = Curves.easeInOut.transform(_carAnim.value);
      return LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      );
    }
    return to;
  }

  void _carTick() {
    if (!mounted) return;
    setState(() {});
  }

  void _animateCarTo(LatLng target) {
    final shown = _carShown;
    _carFrom = shown ?? _lastDriverPos ?? target;
    _carTo = target;
    _carAnim.forward(from: 0);
  }

  void _onPoll() {
    if (!mounted) return;
    final trip = context.read<TripProvider>().activeTrip;
    if (trip == null) {
      _handleTripEnded();
      return;
    }
    if (!_mapReady) return;
    _notifyStatusChange(trip);
    final driver = trip.driverLive;
    if (driver == null || !const [2, 3, 4].contains(trip.status)) {
      _lastDriverPos = null;
      return;
    }
    if (_lastDriverPos == null ||
        _carTo == null ||
        (driver.latitude - _carTo!.latitude).abs() +
                (driver.longitude - _carTo!.longitude).abs() >
            0.000001) {
      _animateCarTo(driver);
    }
    if (_follow) {
      final shown = _carShown ?? driver;
      _mapController.move(shown, _mapController.camera.zoom);
    }
    if (trip.status == 4 && _lastDriverPos != null) {
      final moved = (driver.latitude - _lastDriverPos!.latitude).abs() +
          (driver.longitude - _lastDriverPos!.longitude).abs();
      final now = DateTime.now();
      final due = _lastReroute == null ||
          now.difference(_lastReroute!) > const Duration(seconds: 15);
      if (moved > 0.0003 && due) {
        _lastReroute = now;
        _reRouteToDropoff(driver);
      }
    }
    _lastDriverPos = driver;
  }

  void _handleTripEnded() {
    if (_endedHandled) return;
    _endedHandled = true;
    if (!mounted) return;
    final msg = _notifiedStatus == 5
        ? L10n.t('trip_finished')
        : L10n.t('trip_cancelled');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _notifyStatusChange(dynamic trip) {
    final status = trip.status as int;
    if (status == _notifiedStatus || _notifiedStatus == 0) {
      _notifiedStatus = status;
      return;
    }
    final changed = status != _notifiedStatus;
    _notifiedStatus = status;
    if (!changed) return;
    final key = switch (status) {
      2 => 'driver_accepted',
      3 => 'driver_arrived',
      4 => 'ride_started',
      _ => null,
    };
    if (key == null) return;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(L10n.t(key))),
          ],
        ),
      ));
  }

  Future<void> _reRouteToDropoff(LatLng from) async {
    final trip = context.read<TripProvider>().activeTrip;
    if (trip == null) return;
    final end = (trip.dropoffLat != null && trip.dropoffLng != null)
        ? LatLng(trip.dropoffLat!, trip.dropoffLng!)
        : null;
    if (end == null) return;
    final route = await RouteService.getRoute(from, end);
    if (!mounted) return;
    setState(() {
      _routePoints = route.points;
    });
  }

  Future<void> _loadRoute() async {
    final trip = context.read<TripProvider>().activeTrip;
    if (trip == null) return;
    final end = (trip.dropoffLat != null && trip.dropoffLng != null)
        ? LatLng(trip.dropoffLat!, trip.dropoffLng!)
        : null;
    final driver = trip.driverLive;
    final inProgress = trip.status == 4 && driver != null;
    final start = inProgress ? driver : LatLng(trip.pickupLat, trip.pickupLng);
    if (end == null) return;
    final route = await RouteService.getRoute(start, end);
    if (!mounted) return;
    setState(() {
      _routePoints = route.points;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>().activeTrip;

    if (trip == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline,
                    size: 48, color: context.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  L10n.t('trip_cancelled'),
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .popUntil((route) => route.isFirst),
                  child: Text(L10n.t('go_home')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final start = LatLng(trip.pickupLat, trip.pickupLng);
    final end = (trip.dropoffLat != null && trip.dropoffLng != null)
        ? LatLng(trip.dropoffLat!, trip.dropoffLng!)
        : null;
    final driver = trip.driverLive;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: L10n.t('back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              context.read<TripProvider>().clearActiveTrip();
            }
          },
        ),
        title: Text(L10n.t('my_trip')),
        actions: [
          IconButton(
            tooltip: L10n.t('share_trip'),
            icon: const Icon(Icons.share),
            onPressed: () => _shareTrip(trip),
          ),
          IconButton(
            tooltip: L10n.t('status_history'),
            icon: const Icon(Icons.timeline),
            onPressed: () => _showStatusHistory(trip),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: start,
                    initialZoom: 14,
                    onMapReady: () => _mapReady = true,
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
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: AppColors.secondary,
                            strokeWidth: 5,
                            borderStrokeWidth: 2,
                            borderColor: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        _marker(start, Icons.trip_origin, AppColors.primary),
                        if (end != null)
                          _marker(end, Icons.place, AppColors.secondary),
                        if ((_carShown ?? driver) != null &&
                            const [2, 3, 4].contains(trip.status))
                          Marker(
                            point: _carShown ?? driver!,
                            width: 42,
                            height: 42,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.secondary, width: 2),
                              ),
                              child: Icon(Icons.local_taxi,
                                  color: Theme.of(context).colorScheme.primary, size: 22),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _statusChip(trip),
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
                        _follow
                            ? Icons.my_location
                            : Icons.my_location_outlined,
                        color: _follow
                            ? Theme.of(context).colorScheme.primary
                            : context.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() => _follow = true);
                        final d = _carShown ?? trip.driverLive;
                        if (_mapReady) {
                          _mapController.move(
                            d ?? start,
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
          if (driver != null && const [2, 3, 4].contains(trip.status))
            _driverCard(trip),
          _bottomPanel(trip),
        ],
      ),
    );
  }

  Widget _driverCard(dynamic trip) {
    final d = trip.driver;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4),
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                foregroundImage:
                    (d?.photo != null && d!.photo!.isNotEmpty)
                        ? NetworkImage(ApiConfig.resolve(d.photo!))
                        : null,
                child: (d?.photo == null || d!.photo!.isEmpty)
                    ? Text(
                        (d?.name ?? 'س').isEmpty ? 'س' : (d?.name ?? 'س')[0],
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d?.name ?? L10n.t('driver'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _vehicleText(trip),
                      style: TextStyle(
                          fontSize: 13, color: context.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_arrivalInfo(trip) != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.skyLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              _arrivalInfo(trip)!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (d?.phone != null && d!.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone,
                              size: 13, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              d.phone!,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: context.onSurface),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (d?.ratingAvg != null)
                Row(
                  children: [
                    Icon(Icons.star, size: 18, color: Colors.amber.shade600),
                    const SizedBox(width: 2),
                    Text('${d!.ratingAvg.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TripChatScreen(
                      tripId: trip.id,
                      title: L10n.t('chat_driver'),
                    ),
                  ),
                ),
                icon: Icon(Icons.chat_bubble,
                    color: Theme.of(context).colorScheme.primary, size: 26),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _vehicleText(dynamic trip) {
    final v = trip.vehicle;
    final parts = <String>[
      if (v?.typeName != null) v!.typeName!,
      if (v?.fullName.trim().isNotEmpty == true) v!.fullName,
      if (v?.year != null) '${v!.year}',
      if (v?.color != null) v!.color!,
      if (v != null && v.seats > 0)
        L10n.f('seats_label', {'n': '${v.seats}'}),
      if (v?.plateNumber != null)
        L10n.f('plate_label', {'plate': v!.plateNumber!}),
    ];
    return parts.isNotEmpty ? parts.join(' · ') : L10n.t('private_car');
  }

  static double _kmBetween(LatLng a, LatLng b) {
    const r = 6371.0;
    final rad = math.pi / 180;
    final dLat = (b.latitude - a.latitude) * rad;
    final dLng = (b.longitude - a.longitude) * rad;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * rad) *
            math.cos(b.latitude * rad) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(h <= 1 ? math.sqrt(h) : 1.0);
  }

  String? _arrivalInfo(dynamic trip) {
    if (!const [2, 3].contains(trip.status)) return null;
    final d = trip.driverLive;
    if (d == null) return null;
    final dist = _kmBetween(d, LatLng(trip.pickupLat, trip.pickupLng));
    final mins = (dist / 0.5).ceil();
    return L10n.f('driver_arrival',
        {'dist': dist.toStringAsFixed(1), 'mins': '$mins'});
  }

  Future<void> _shareTrip(dynamic trip) async {
    final code = await context.read<TripProvider>().shareTrip(trip.id);
    if (!mounted) return;
    if (code == null || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('share_failed'))),
      );
      return;
    }
    final link = 'https://goride.app/trip/$code';
    try {
      await SharePlus.instance.share(ShareParams(
        text: link,
        subject: L10n.t('share_trip'),
      ));
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('share_copied'))),
      );
    }
  }

  Future<void> _cancelTrip(dynamic trip) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => _CancelReasonSheet(),
    );
    if (reason == null || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<TripProvider>().cancelTrip(trip.id, reason: reason);
      if (!mounted) return;
      context.read<TripProvider>().clearActiveTrip();
      if (navigator.canPop()) navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _sos() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SosScreen()),
    );
  }

  Future<void> _showStatusHistory(dynamic trip) async {
    final events = await context.read<TripProvider>().statusHistory(trip.id);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(L10n.t('status_history'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              ...events.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.radio_button_checked,
                            size: 16, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${e.label} · ${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Icon(icon, color: color, size: 36),
    );
  }

  Widget _statusChip(dynamic trip) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Text(
          trip.statusLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _bottomPanel(dynamic trip) {
    final isCompleted = trip.status == 5;

    Widget content;
    if (isCompleted) {
      content = _ratePanel(trip);
    } else if (const [6, 7, 8].contains(trip.status)) {
      content = Column(
        children: [
          Text(
            L10n.t('trip_finished'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            L10n.f('status_label', {'status': trip.statusLabel}),
            style: TextStyle(color: context.onSurfaceVariant),
          ),
        ],
      );
    } else {
      content = Column(
        children: [
          Row(
            children: [
              Icon(Icons.place, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(trip.pickupAddress)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(trip.dropoffAddress ?? L10n.t('no_dropoff')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (trip.durationMinutes != null)
            Text(
              L10n.f('eta_dist', {
                'dur': '${trip.durationMinutes}',
                'dist': (trip.distanceKm ?? 0).toStringAsFixed(2),
              }),
              style: TextStyle(color: context.onSurfaceVariant),
            ),
          const SizedBox(height: 4),
          if (trip.driverId != null && const [2, 3, 4].contains(trip.status))
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TripChatScreen(
                    tripId: trip.id,
                    title: L10n.t('chat_driver'),
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble, size: 18),
              label: Text(L10n.t('chat_driver')),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (const [0, 1, 2, 3].contains(trip.status))
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _cancelTrip(trip),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger),
                    child: Text(L10n.t('cancel_trip')),
                  ),
                ),
              if (const [0, 1, 2, 3].contains(trip.status))
                const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sos,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  icon: const Icon(Icons.sos, size: 18),
                  label: const Text('SOS'),
                ),
              ),
            ],
          ),
          if (trip.status == 3 && trip.otpCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.skyLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.password,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        L10n.f('otp_share',
                            {'code': '${trip.otpCode}'}),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: L10n.t('copy'),
                      icon: const Icon(Icons.copy,
                          size: 18, color: AppColors.primary),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: '${trip.otpCode}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(L10n.t('share_copied'))),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (trip.status == 4)
            Text(
              L10n.f('est_fare',
                  {'fare': trip.estimatedFare?.toStringAsFixed(0) ?? '-'}),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(child: content),
    );
  }

  Widget _ratePanel(dynamic trip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          L10n.t('rate_trip_title'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            return IconButton(
              onPressed: () => setState(() => _rating = i + 1),
              icon: Icon(
                i < _rating ? Icons.star : Icons.star_border,
                color: AppColors.secondary,
                size: 34,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [0, 10, 25, 50].map((v) {
            final selected = _tip == v;
            return ChoiceChip(
              label: Text(v == 0 ? L10n.t('no_tip') : '$v ج.م'),
              selected: selected && _customTipController.text.isEmpty,
              onSelected: (_) {
                setState(() {
                  _tip = v.toDouble();
                  _customTipController.clear();
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _customTipController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: L10n.t('custom_tip'),
            hintText: L10n.t('tip_example'),
            prefixText: L10n.t('EGP_SUFFIX'),
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            setState(() => _tip = parsed ?? 0);
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _comment,
          decoration: InputDecoration(
            hintText: L10n.t('rate_comment'),
          ),
        ),
        const SizedBox(height: 12),
        Text(L10n.t('rate_tags_title'),
            style: TextStyle(fontSize: 13, color: context.onSurfaceVariant)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _rateTags.map((tagKey) {
            return FilterChip(
              label: Text(L10n.t(tagKey)),
              selected: _tags.contains(tagKey),
              onSelected: (v) =>
                  setState(() => v ? _tags.add(tagKey) : _tags.remove(tagKey)),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            final provider = context.read<TripProvider>();
            final navigator = Navigator.of(context);
            final tags = _tags.map(L10n.t).join('، ');
            var comment = _comment.text.trim();
            if (tags.isNotEmpty) {
              comment = comment.isEmpty ? tags : '$comment — $tags';
            }
            await provider.rateTrip(
              trip.id,
              _rating,
              comment,
              tip: _tip,
            );
            await provider.refreshActive();
            navigator.popUntil((r) => r.isFirst);
          },
          child: Text(L10n.t('submit_rating')),
        ),
      ],
    );
  }
}

class _CancelReasonSheet extends StatelessWidget {
  const _CancelReasonSheet();

  static List<(String, String)> get _reasons => [
        ('change_of_plan', L10n.t('rc_plan_changed')),
        ('driver_too_far', L10n.t('rc_driver_far')),
        ('long_wait_time', L10n.t('rc_too_long')),
        ('wrong_address', L10n.t('rc_wrong_address')),
        ('found_other_car', L10n.t('rc_found_other')),
        ('other', L10n.t('rc_other')),
      ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L10n.t('cancel_reason_title'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._reasons.map(
              (r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chevron_left),
                title: Text(r.$2),
                onTap: () => Navigator.of(context).pop(r.$1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}