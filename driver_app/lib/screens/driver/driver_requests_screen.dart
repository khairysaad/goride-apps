import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../core/service/request_alert.dart';
import '../../models/models.dart';
import '../../providers/driver_provider.dart';
import '../../providers/trip_provider.dart';
import 'driver_home_screen.dart';
import '../../providers/settings_provider.dart';

class DriverRequestsScreen extends StatefulWidget {
  const DriverRequestsScreen({super.key});

  @override
  State<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends State<DriverRequestsScreen> {
  List<Trip> _incoming = [];
  bool _loading = true;
  bool _pollingIncoming = false;
  Timer? _timer;
  int _busyId = 0;
  final Set<int> _seen = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().refreshActive();
      _load();
      _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_pollingIncoming) return;
    _pollingIncoming = true;
    try {
      final trips = await context.read<TripProvider>().incoming();
      if (!mounted) return;
      final fresh = trips.where((t) => !_seen.contains(t.id)).toList();
      for (final t in trips) {
        _seen.add(t.id);
      }
      setState(() {
        _incoming = trips;
        _loading = false;
      });
      if (fresh.isNotEmpty) {
        RequestAlert.ring();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _pollingIncoming = false;
    }
  }

  Future<void> _accept(Trip trip) async {
    if (_busyId != 0) return;
    setState(() => _busyId = trip.id);
    try {
      await context.read<TripProvider>().acceptTrip(trip.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.contains('conflict') || msg.contains('already')
              ? L10n.t('trip_taken')
              : msg),
        ),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _busyId = 0);
    }
  }

  Future<void> _reject(Trip trip) async {
    if (_busyId != 0) return;
    setState(() => _busyId = trip.id);
    try {
      await context.read<TripProvider>().rejectTrip(trip.id);
      _load();
    } catch (_) {
      _load();
    } finally {
      if (mounted) setState(() => _busyId = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>().driver;
    final trip = context.watch<TripProvider>().activeTrip;

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.t('incoming_requests')),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _body(driver, trip),
      ),
    );
  }

  Widget _body(Driver? driver, Trip? active) {
    if (active != null && const [2, 3, 4].contains(active.status)) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _tripCard(active, reserved: true),
          ),
        ],
      );
    }

    if (_loading && _incoming.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_incoming.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(
            driver?.isOnline ?? false
                ? Icons.notifications_active
                : Icons.pending,
            size: 64,
            color: (driver?.isOnline ?? false)
                ? Theme.of(context).colorScheme.primary
                : context.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            driver?.isOnline ?? false
                ? L10n.t('online_idle')
                : L10n.t('offline_prompt'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _incoming.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _tripCard(_incoming[i]),
    );
  }

  Widget _tripCard(Trip trip, {bool reserved = false}) {
    final busy = _busyId == trip.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (reserved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      L10n.t('reserved_for_you'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Text(
                    '#${trip.tripNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                if (trip.isScheduled) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.schedule,
                      size: 18, color: AppColors.warning),
                ],
                const Spacer(),
                Text(
                  trip.statusLabel,
                  style: TextStyle(
                    color: context.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (trip.customerName != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (trip.customerAvatar != null &&
                      trip.customerAvatar!.isNotEmpty)
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: NetworkImage(trip.customerAvatar!),
                    )
                  else
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.skyLight,
                      child: const Icon(Icons.person,
                          size: 16, color: AppColors.primary),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trip.customerName!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (trip.customerPhone != null &&
                  trip.customerPhone!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Row(
                    children: [
                      Icon(Icons.phone,
                          size: 16, color: context.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.customerPhone!,
                          style: TextStyle(
                            color: context.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            _row(Icons.place, trip.pickupAddress),
            if (trip.dropoffAddress != null) ...[
              const SizedBox(height: 8),
              _row(Icons.location_on, trip.dropoffAddress!),
            ],
            if (trip.distanceKm != null || trip.estimatedFare != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (trip.distanceKm != null)
                    Text(
                      L10n.f('km_value',
                          {'n': trip.distanceKm!.toStringAsFixed(2)}),
                      style: TextStyle(color: context.onSurfaceVariant),
                    ),
                  if (trip.estimatedFare != null) ...[
                    const Spacer(),
                    Text(
                      L10n.f('egp_amount',
                          {'n': trip.estimatedFare!.toStringAsFixed(0)}),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy || reserved ? null : () => _accept(trip),
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(L10n.t('accept_trip')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy || reserved ? null : () => _reject(trip),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: AppColors.danger,
                    ),
                    child: Text(L10n.t('reject')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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