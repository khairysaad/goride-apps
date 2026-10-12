import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../core/network/route_service.dart';
import '../../core/widgets/app_tile_layer.dart';
import '../../models/models.dart';
import '../../providers/location_provider.dart';
import '../../providers/trip_provider.dart';
import 'request_trip_sheet.dart';
import '../../providers/settings_provider.dart';
class DriverSelectionScreen extends StatefulWidget {
  const DriverSelectionScreen({
    super.key,
    required this.pickup,
    required this.requestData,
    required this.onRequested,
  });

  final LatLng pickup;
  final TripRequestData requestData;
  final VoidCallback onRequested;

  @override
  State<DriverSelectionScreen> createState() => _DriverSelectionScreenState();
}

class _DriverSelectionScreenState extends State<DriverSelectionScreen> {
  RouteResult? _route;
  bool _loading = true;
  bool _sending = false;
  TripProvider? _tripProvider;

  @override
  void initState() {
    super.initState();
    _tripProvider = context.read<TripProvider>();
    _loadRoute();
    final location = context.read<LocationProvider>().current;
    final p = location != null
        ? Lat(location.latitude, location.longitude)
        : Lat(widget.pickup.latitude, widget.pickup.longitude);
    _tripProvider!.refreshNearbyDrivers(p,
        dropoff: Lat(widget.requestData.dropoff.latitude,
            widget.requestData.dropoff.longitude),
        serviceTypeId: widget.requestData.serviceTypeId);
    _tripProvider!.startDriversPolling(p,
        dropoff: Lat(widget.requestData.dropoff.latitude,
            widget.requestData.dropoff.longitude),
        serviceTypeId: widget.requestData.serviceTypeId);
    _tripProvider!.refreshActive();
  }

  @override
  void dispose() {
    _tripProvider?.stopDriversPolling();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    final route = await RouteService.getRoute(
      widget.pickup,
      widget.requestData.dropoff,
    );
    if (!mounted) return;
    setState(() {
      _route = route;
      _loading = false;
    });
  }

  double _estimateFare(NearbyDriver d) {
    final distanceKm = _route?.distanceKm ?? 0;
    final durationMin = _route?.durationMinutes ?? 0;
    final provider = context.read<ServiceProvider>();
    final vt = d.vehicle != null && d.vehicle!.typeCode != null
        ? provider.vehicleTypes
            .where((v) => v.code == d.vehicle!.typeCode)
            .toList()
        : <VehicleType>[];
final type = vt.isNotEmpty
          ? vt.first
          : (provider.vehicleTypes.isNotEmpty ? provider.vehicleTypes.first : null);
      if (type == null) return 5 + distanceKm * 4.5 + durationMin;
      final surge = type.surgeMultiplier < 1 ? 1.0 : type.surgeMultiplier;
      final fare = type.baseFare +
          (distanceKm * type.perKm + durationMin * type.perMinute) * surge;
      return fare < type.minFare ? type.minFare : fare;
    }

    double _surge(NearbyDriver d) {
      final provider = context.read<ServiceProvider>();
      final code = d.vehicle?.typeCode;
      if (code == null) return 1.0;
      for (final v in provider.vehicleTypes) {
        if (v.code == code && v.surgeMultiplier > 1) return v.surgeMultiplier;
      }
      return 1.0;
    }

  VehicleType? _fareType() {
    final provider = context.read<ServiceProvider>();
    if (provider.vehicleTypes.isEmpty) return null;
    final st = widget.requestData.serviceTypeId;
    if (st != null) {
      final svc = provider.serviceTypes.where((s) => s.id == st).toList();
      if (svc.isNotEmpty) {
        final vts = provider.vehicleTypes
            .where((v) => v.category == svc.first.category)
            .toList();
        if (vts.isNotEmpty) return vts.first;
      }
    }
    return provider.vehicleTypes.first;
  }

  void _showFareBreakdown() {
    final type = _fareType();
    final distanceKm = _route?.distanceKm ?? 0;
    final durationMin = _route?.durationMinutes ?? 0;
    if (type == null) return;
    final surge = type.surgeMultiplier < 1 ? 1.0 : type.surgeMultiplier;
    final base = type.baseFare;
    final distFare = distanceKm * type.perKm;
    final timeFare = durationMin * type.perMinute;
    final raw = (base + distFare + timeFare) * surge;
    final total = raw < type.minFare ? type.minFare : raw;

    Widget row(String label, String value, {bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    color: bold ? context.onSurface : context.onSurfaceVariant,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: bold
                        ? Theme.of(context).colorScheme.primary
                        : context.onSurface)),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${L10n.t('fare_details')} — ${type.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (surge > 1) ...[
                const SizedBox(height: 4),
                Text(
                  L10n.f('surge_label', {'mult': surge.toStringAsFixed(1)}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 12),
              row(L10n.t('base_fare'), L10n.f('egp_amount', {'n': base.toStringAsFixed(0)})),
              row(
                L10n.f('distance_fare',
                    {'dist': distanceKm.toStringAsFixed(1)}),
                L10n.f('egp_amount', {'n': distFare.toStringAsFixed(0)}),
              ),
              row(
                L10n.f('time_fare', {'min': '$durationMin'}),
                L10n.f('egp_amount', {'n': timeFare.toStringAsFixed(0)}),
              ),
              if (surge > 1)
                row(
                  L10n.f('high_demand', {'mult': surge.toStringAsFixed(1)}),
                  L10n.f('egp_amount',
                      {'n': ((base + distFare + timeFare) * (surge - 1)).toStringAsFixed(0)}),
                ),
              const Divider(height: 24),
              row(L10n.t('total_fare'),
                  L10n.f('egp_amount', {'n': total.toStringAsFixed(0)}),
                  bold: true),
              if (raw < type.minFare)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    L10n.f('min_fare_note', {'n': type.minFare.toStringAsFixed(0)}),
                    style:
                        TextStyle(fontSize: 12, color: context.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDriver(NearbyDriver driver) async {
    setState(() => _sending = true);
    try {
      await context.read<TripProvider>().requestTrip(
            pickup: Lat(widget.pickup.latitude, widget.pickup.longitude),
            pickupAddress: L10n.t('current_location'),
            dropoff: Lat(widget.requestData.dropoff.latitude,
                widget.requestData.dropoff.longitude),
            dropoffAddress: widget.requestData.dropoffAddress,
            serviceTypeId: widget.requestData.serviceTypeId,
            driverId: driver.id,
            paymentMethod: widget.requestData.paymentMethod,
            couponCode: widget.requestData.couponCode,
          );
      if (mounted) widget.onRequested();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final drivers = context.watch<TripProvider>().nearbyDrivers;
    final distance = _route?.distanceKm ?? 0;
    final duration = _route?.durationMinutes ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('choose_driver'))),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: widget.pickup,
                    initialZoom: 13,
                    onTap: (_, _) {},
                  ),
                  children: [
                    const AppTileLayer(),
                    if (_route != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route!.points,
                            color: AppColors.secondary,
                            strokeWidth: 5,
                            borderStrokeWidth: 2,
                            borderColor: AppColors.primaryDark,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        _marker(widget.pickup, Icons.trip_origin, AppColors.primary),
                        _marker(widget.requestData.dropoff, Icons.place,
                            AppColors.secondary),
                        ...drivers.map((d) => _driverMarker(d)),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.route, color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _loading
                                ? L10n.t('calculating_route')
                                : L10n.f('route_info', {
                                'dist': distance.toStringAsFixed(2),
                                'dur': '$duration',
                              }),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          iconSize: 20,
                          tooltip: L10n.t('fare_details'),
                          icon: Icon(Icons.info_outline,
                              color: context.onSurfaceVariant),
                          onPressed: _loading ? null : _showFareBreakdown,
                        ),
                        Text(
                          L10n.f('drivers_count', {'n': '${drivers.length}'}),
                          style: const TextStyle(color: AppColors.secondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: _sending
                ? const Center(child: CircularProgressIndicator())
                : _driverList(drivers),
          ),
        ],
      ),
    );
  }

  Marker _marker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 38,
      height: 38,
      child: Icon(icon, color: color, size: 34),
    );
  }

  Marker _driverMarker(NearbyDriver d) {
    return Marker(
      point: LatLng(d.lat, d.lng),
      width: 40,
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.secondary, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Icon(Icons.local_taxi, color: Theme.of(context).colorScheme.primary, size: 20),
      ),
    );
  }

  Widget _driverList(List<NearbyDriver> drivers) {
    if (drivers.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            L10n.t('no_drivers'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: drivers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final d = drivers[i];
        final fare = d.fare ?? _estimateFare(d);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _avatar(d),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.name ?? L10n.t('driver'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(Icons.star,
                              size: 18, color: Colors.amber.shade600),
                          const SizedBox(width: 2),
                          Text(
                            '${d.ratingAvg.toStringAsFixed(1)} (${d.tripsCount})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _vehicleLine(d),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.near_me,
                              size: 16, color: AppColors.secondary),
                          Text(
                            L10n.f('driver_eta', {
                              'dist': d.distance.toStringAsFixed(1),
                              'min': '${d.etaMinutes}',
                            }),
                            style: TextStyle(
                                color: context.onSurfaceVariant, fontSize: 13),
                          ),
                          const Spacer(),
                          if (_surge(d) > 1)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                L10n.f('high_demand',
                                    {'mult': _surge(d).toStringAsFixed(1)}),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          Text(
                            L10n.f('egp_amount', {'n': fare.toStringAsFixed(0)}),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sending ? null : () => _selectDriver(d),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(72, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: Text(L10n.t('choose')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _avatar(NearbyDriver d) {
    if (d.photo != null && d.photo!.isNotEmpty) {
      return CircleAvatar(radius: 26, backgroundColor: AppColors.skyLight);
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: AppColors.primary,
      child: Text(
        (d.name ?? 'س').isEmpty ? 'س' : (d.name ?? 'س')[0],
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  Widget _vehicleLine(NearbyDriver d) {
    final v = d.vehicle;
    final parts = <String>[
      if (v?.typeName != null) v!.typeName!,
      if (v?.fullName.isNotEmpty ?? false) v!.fullName,
      if (v?.color != null) v!.color!,
      if (v?.plateNumber != null)
        L10n.f('plate_label', {'plate': v!.plateNumber!}),
    ];
    if (parts.isEmpty) parts.add(d.vehicleType ?? '');
    return Text(
      parts.join(' · '),
      style: TextStyle(fontSize: 13, color: context.onSurface),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}