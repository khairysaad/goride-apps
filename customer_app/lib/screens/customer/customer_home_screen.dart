import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../core/location/location_service.dart';
import '../../core/network/geocode_service.dart';
import '../../core/widgets/app_tile_layer.dart';
import '../../models/models.dart';
import '../../providers/ads_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/trip_provider.dart';
import 'active_trip_screen.dart';
import 'coupons_screen.dart';
import 'driver_selection_screen.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'request_trip_sheet.dart';
import 'trip_history_screen.dart';
import 'profile_screen.dart';
import '../widgets/ads_banner.dart';
import '../widgets/home_nav_host.dart';
import '../../providers/settings_provider.dart';
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  static const _cairo = LatLng(30.0444, 31.2357);
  final MapController _mapController = MapController();
  String? _currentAddress;
  bool _geocoded = false;
  List<Trip> _upcoming = [];
  void Function()? _lpListener;

  Future<void> _loadUpcoming() async {
    try {
      final list = await context.read<TripProvider>().upcoming();
      if (!mounted) return;
      setState(() => _upcoming = list);
    } catch (_) {}
  }

  LatLng? get _current {
    final p = context.watch<LocationProvider>().current;
    return p != null ? LatLng(p.latitude, p.longitude) : _cairo;
  }

  void _syncDriversPolling() {
    final p = context.read<LocationProvider>().current;
    final tp = context.read<TripProvider>();
    if (p == null) {
      tp.stopDriversPolling();
    } else {
      tp.startDriversPolling(
          Lat(p.latitude, p.longitude));
    }
  }

  Future<void> _refreshCurrentAddress() async {
    final p = context.read<LocationProvider>().current;
    if (p == null) return;
    final addr = await GeocodeService.reverse(p.latitude, p.longitude);
    if (!mounted || addr == null || addr.isEmpty) return;
    setState(() => _currentAddress = addr);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lp = context.read<LocationProvider>();
      _lpListener = _syncDriversPolling;
      lp.addListener(_lpListener!);
      _syncDriversPolling();
      if (lp.access == LocationAccess.unknown) {
        lp.requestLocation(context);
      }
      context.read<ServiceProvider>().loadHomeData();
      context.read<ServiceProvider>().loadOffers();
      context.read<FavoritesProvider>().load();
      context.read<AdsProvider>().load(target: 'customer');
      _loadUpcoming();
    });
  }

  @override
  void dispose() {
    final lp = context.read<LocationProvider>();
    if (_lpListener != null) lp.removeListener(_lpListener!);
    context.read<TripProvider>().stopDriversPolling();
    super.dispose();
  }

  Future<void> _openRequestSheet(
      {int? serviceTypeId,
      String? couponCode,
      LatLng? dropoffPoint,
      String? dropoffAddress}) async {
    final location = context.read<LocationProvider>().current;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('location_required'))),
      );
      return;
    }
    final pickup = LatLng(location.latitude, location.longitude);
    final data = await showModalBottomSheet<TripRequestData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RequestTripSheet(
        pickupLatLng: pickup,
        initialServiceTypeId: serviceTypeId,
        initialCouponCode: couponCode,
        initialDropoff: dropoffPoint,
        initialDropoffAddress: dropoffAddress,
      ),
    );
    if (data == null || !mounted) return;

    if (data.isScheduled) {
      try {
        await context.read<TripProvider>().requestTrip(
              pickup: Lat(pickup.latitude, pickup.longitude),
              pickupAddress: _currentAddress ?? L10n.t('current_location'),
              dropoff: Lat(data.dropoff.latitude, data.dropoff.longitude),
              dropoffAddress: data.dropoffAddress,
              serviceTypeId: data.serviceTypeId,
              paymentMethod: data.paymentMethod,
              isScheduled: true,
              scheduledAt: data.scheduledAt,
              couponCode: data.couponCode,
            );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.t('trip_scheduled_ok'))),
        );
        _loadUpcoming();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverSelectionScreen(
          pickup: pickup,
          requestData: data,
          onRequested: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ActiveTripScreen()),
            );
          },
        ),
      ),
    );
  }

  Widget _countChip(int count) {
    final settings = context.watch<SettingsProvider>();
    return Chip(
      avatar: Icon(Icons.local_taxi, size: 16, color: Theme.of(context).colorScheme.primary),
      label: Text('$count ${settings.t('nearby')}'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(fontSize: 12, color: context.onSurface),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }

  Widget _greeting() {
    final user = context.watch<AuthProvider>().user;
    final name = user?.name ?? '';
    final first = name.contains(' ') ? name.split(' ').first : name;
    final hour = DateTime.now().hour;
    final isMorning = hour >= 5 && hour < 12;
    final greeting = first.isEmpty
        ? (isMorning
            ? L10n.t('good_morning')
            : L10n.t('good_evening'))
        : (isMorning
            ? L10n.f('good_morning_name', {'name': first})
            : L10n.f('good_evening_name', {'name': first}));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary,
            child: first.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 16)
                : Text(
                    first.characters.first.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              greeting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  bool _tripIsLive(Trip trip) {
    if (const [5, 6, 7, 8].contains(trip.status)) return false;
    DateTime? ref;
    final updated = DateTime.tryParse(trip.raw?['updated_at'] ?? '');
    final created = DateTime.tryParse(trip.raw?['created_at'] ?? '');
    ref = (updated ?? created);
    if (ref == null) return true;
    final ageMinutes = DateTime.now().difference(ref).inMinutes;
    if (trip.status <= 1) return ageMinutes < 30;
    return ageMinutes < 180;
  }

  IconData _serviceIcon(String? icon) {
    switch (icon) {
      case 'car':
      case 'car_sport':
      case 'luxury_car':
        return Icons.directions_car;
      case 'van':
        return Icons.airport_shuttle;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'delivery':
        return Icons.inventory_2;
      case 'auto':
        return Icons.local_shipping;
      default:
        return Icons.directions_car;
    }
  }

  Widget _scheduledBanner() {
    if (_upcoming.isEmpty) return const SizedBox.shrink();
    final t = _upcoming.first;
    final time = t.scheduledAt != null
        ? '${t.scheduledAt!.day}/${t.scheduledAt!.month} · ${t.scheduledAt!.hour.toString().padLeft(2, '0')}:${t.scheduledAt!.minute.toString().padLeft(2, '0')}'
        : '';
    return Material(
      color: AppColors.secondary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) =>
                    const TripHistoryScreen(initialTab: 1),
              ),
            )
            .then((_) => _loadUpcoming()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.schedule,
                    color: Theme.of(context).colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.t('scheduled_trip'),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(
                          fontSize: 12, color: context.onSurfaceVariant),
                    ),
                    if (t.dropoffAddress != null && t.dropoffAddress!.isNotEmpty)
                      Text(
                        t.dropoffAddress!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: context.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Text(
                L10n.t('view'),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary),
              ),
              Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whereToCard() {
    final isLocated = _currentAddress != null;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _openRequestSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.place_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      L10n.t('current_location'),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentAddress ?? L10n.t('where_to'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: isLocated
                            ? context.onSurface
                            : context.onSurfaceVariant,
                        fontWeight:
                            isLocated ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: context.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _servicesSection() {
    return Consumer<ServiceProvider>(
      builder: (context, provider, _) {
        final types = provider.vehicleTypes;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.t('services_title'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (types.isEmpty)
              const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
                children: types
                    .map(
                      (vt) => InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openRequestSheet(serviceTypeId: vt.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.skyLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _serviceIcon(vt.icon),
                                color: AppColors.primary,
                                size: 26,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                vt.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                L10n.f('egp_amount', {'n': '${vt.minFare.round()}'}),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary),
                              ),
                              if (vt.surgeMultiplier > 1)
                                Text(
                                  '×${vt.surgeMultiplier.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.deepOrange,
                                      fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _offersSection() {
    return Consumer<ServiceProvider>(
      builder: (context, provider, _) {
        final offers = provider.offers;
        if (offers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    L10n.t('offers_title'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CouponsScreen()),
                  ),
                  child: Text(L10n.t('view_all')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 128,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: offers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final offer = offers[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        _openRequestSheet(couponCode: offer.code),
                    child: Container(
                      width: 196,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.discountLabel,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          if (offer.description != null &&
                              offer.description!.isNotEmpty)
                            Text(
                              offer.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          const Spacer(),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  offer.code,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary),
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_forward,
                                  color: Colors.white, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _favoritesSection() {
    return Consumer<FavoritesProvider>(
      builder: (context, fv, _) {
        if (fv.places.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.t('favorites'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fv.places.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = fv.places[i];
                  return ActionChip(
                    avatar: Icon(p.icon, size: 16, color: Theme.of(context).colorScheme.primary),
                    label: Text(p.name),
                    onPressed: () {
                      _openRequestSheet(
                        dropoffPoint: LatLng(p.lat, p.lng),
                        dropoffAddress: p.address ?? p.name,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bottomPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
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
              Consumer<AdsProvider>(
                builder: (context, ads, _) => ads.ads.isEmpty
                    ? const SizedBox.shrink()
                    : const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: AdsBanner(target: 'customer'),
                      ),
              ),
              _scheduledBanner(),
              if (_upcoming.isNotEmpty) const SizedBox(height: 12),
              _whereToCard(),
              const SizedBox(height: 20),
              _servicesSection(),
              const SizedBox(height: 22),
              _offersSection(),
              const SizedBox(height: 22),
              _favoritesSection(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openRequestSheet,
                child: Text(L10n.t('request_ride')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>().activeTrip;
    final current = _current ?? _cairo;
    final access = context.watch<LocationProvider>().access;

    if (!_geocoded &&
        context.read<LocationProvider>().current != null) {
      _geocoded = true;
      _refreshCurrentAddress();
    }

    if (trip != null && _tripIsLive(trip)) {
      return const ActiveTripScreen();
    }

    return HomeNavHost(
      mapPage: Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: current,
                initialZoom: 13,
                onTap: (_, _) {},
              ),
              children: [
                const AppTileLayer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: current,
                      width: 44,
                      height: 44,
                      child: Icon(Icons.navigation,
                          color: Theme.of(context).colorScheme.primary, size: 44),
                    ),
                    ...context
                        .watch<TripProvider>()
                        .nearbyDrivers
                        .map(
                          (d) => Marker(
                            point: LatLng(d.lat, d.lng),
                            width: 38,
                            height: 38,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.secondary, width: 2),
                              ),
                              child: Icon(Icons.local_taxi,
                                  color: Theme.of(context).colorScheme.primary, size: 18),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Flexible(child: _greeting()),
                        const Spacer(),
                        _countChip(context
                            .watch<TripProvider>()
                            .nearbyDrivers
                            .length),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            icon: const Icon(Icons.favorite_border,
                                color: AppColors.danger),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const FavoritesScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Consumer<NotificationProvider>(
                          builder: (context, np, _) => CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              icon: Badge(
                                isLabelVisible: np.unreadCount > 0,
                                label: Text('${np.unreadCount}'),
                                child: Icon(Icons.notifications_none,
                                    color: context.onSurface),
                              ),
                              onPressed: () {
                                np.load();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const NotificationsScreen()),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _bottomPanel(),
                ],
              ),
            ),
            if (access != LocationAccess.granted)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: LocationPermissionCard(
                  onRetry: () {
                    context.read<LocationProvider>().requestLocation(context);
                  },
                ),
              ),
          ],
        ),
      ),
      pages: [
        const TripHistoryScreen(),
        const ProfileScreen(),
      ],
    );
  }
}