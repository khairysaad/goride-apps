import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/trip_provider.dart';
import 'active_trip_screen.dart';
import 'driver_selection_screen.dart';
import 'request_trip_sheet.dart';
import '../../providers/settings_provider.dart';
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FavoritesProvider>().load();
    });
  }

  Future<void> _addPlace() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final lat = TextEditingController();
    final lng = TextEditingController();
    int type = 2;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(L10n.t('add_favorite_place')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: L10n.t('place_name')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: address,
                  decoration: InputDecoration(labelText: L10n.t('address')),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: lat,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: L10n.t('latitude')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lng,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: L10n.t('longitude')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 0, label: Text(L10n.t('home')), icon: Icon(Icons.home)),
                    ButtonSegment(value: 1, label: Text(L10n.t('work')), icon: Icon(Icons.work)),
                    ButtonSegment(value: 2, label: Text(L10n.t('other')), icon: Icon(Icons.place)),
                  ],
                  selected: {type},
                  onSelectionChanged: (s) => setDialog(() => type = s.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L10n.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(L10n.t('save')),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted) return;
    try {
      await context.read<FavoritesProvider>().addPlace(
            name: name.text.trim(),
            address: address.text.trim(),
            lat: double.tryParse(lat.text) ?? 0,
            lng: double.tryParse(lng.text) ?? 0,
            type: type,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('place_added'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _requestToPlace(FavoritePlace p) async {
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
        initialDropoff: LatLng(p.lat, p.lng),
        initialDropoffAddress: p.address ?? p.name,
      ),
    );
    if (data == null || !mounted) return;
    if (data.isScheduled) {
      try {
        await context.read<TripProvider>().requestTrip(
              pickup: Lat(pickup.latitude, pickup.longitude),
              pickupAddress: L10n.t('current_location'),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FavoritesProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('favorites'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlace,
        icon: const Icon(Icons.add_location_alt),
        label: Text(L10n.t('add_place')),
      ),
      body: provider.loading && provider.places.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<FavoritesProvider>().load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  Text(L10n.t('favorite_places'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (provider.places.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(L10n.t('no_favorite_places'),
                          style: TextStyle(color: context.onSurfaceVariant)),
                    )
                  else
                    ...provider.places.map((p) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.skyLight,
                              child: Icon(p.icon, color: AppColors.primary),
                            ),
                            title: Text(L10n.f('route_arrow', {'a': p.name, 'b': p.typeLabel})),
                            subtitle: Text(p.address ?? ''),
                            onTap: () => _requestToPlace(p),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  context.read<FavoritesProvider>().removePlace(p.id),
                            ),
                          ),
                        )),
                  const SizedBox(height: 20),
                  Text(L10n.t('favorite_drivers'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (provider.drivers.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(L10n.t('no_favorite_drivers'),
                          style: TextStyle(color: context.onSurfaceVariant)),
                    )
                  else
                    ...provider.drivers.map((d) => Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(d.name ?? L10n.t('driver')),
                            subtitle: Text(
                              L10n.f('driver_info', {
                                'avail': d.isAvailable
                                    ? L10n.t('available')
                                    : L10n.t('not_available'),
                                'rating': d.ratingAvg.toStringAsFixed(1),
                                'trips': '${d.tripsCount}',
                              }),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  context.read<FavoritesProvider>().removeDriver(d.driverId),
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}