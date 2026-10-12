import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/trip_provider.dart';
import 'driver_selection_screen.dart';
import 'request_trip_sheet.dart';
import '../../providers/settings_provider.dart';
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<Trip>? _trips;
  List<Trip>? _upcoming;
  bool _loading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final trips = await context.read<TripProvider>().history();
      final upcoming = await context.read<TripProvider>().upcoming();
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _upcoming = upcoming;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _reorder(Trip t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverSelectionScreen(
          pickup: LatLng(t.pickupLat, t.pickupLng),
          requestData: TripRequestData(
            dropoff:
                LatLng(t.dropoffLat ?? t.pickupLat, t.dropoffLng ?? t.pickupLng),
            dropoffAddress: t.dropoffAddress ?? t.pickupAddress,
            serviceTypeId: t.serviceType?.id,
          ),
          onRequested: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      ),
    );
  }

  Future<void> _showDetails(Trip t) async {
    final events = await context.read<TripProvider>().statusHistory(t.id);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
                t.tripNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(L10n.f('route_arrow', {'a': t.pickupAddress, 'b': t.dropoffAddress ?? ''})),
              const SizedBox(height: 4),
              Text(
                t.statusLabel,
                style: const TextStyle(color: AppColors.secondary),
              ),
              const SizedBox(height: 16),
              Text(L10n.t('status_history'),
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
              const SizedBox(height: 16),
              if (t.status == 5) ...[
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _reorder(t);
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(L10n.t('rebook')),
                ),
                const SizedBox(height: 8),
              ],
              if (t.dropoffLat != null && t.dropoffLng != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    if (!mounted) return;
                    final tp = context.read<TripProvider>();
                    final code = await tp.shareTrip(t.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(L10n.f('share_link', {'url': 'https://goride.app/trip/$code'}))),
                    );
                  },
                  icon: const Icon(Icons.ios_share),
                  label: Text(L10n.t('share_trip')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.t('tab_trips')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [Tab(text: L10n.t('tab_history')), Tab(text: L10n.t('tab_scheduled'))],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _list(_trips ?? const [], isUpcoming: false),
                _list(_upcoming ?? const [], isUpcoming: true),
              ],
            ),
    );
  }

  Future<void> _cancelScheduled(Trip t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('cancel_trip')),
        content: Text(L10n.t('cancel_scheduled_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.t('close')),
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
    try {
      await context.read<TripProvider>().cancelTrip(t.id,
          reason: 'customer_cancelled');
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Widget _list(List<Trip> trips, {required bool isUpcoming}) {
    if (trips.isEmpty) {
      return Center(
        child: Text(
          L10n.t('no_trips'),
          style: TextStyle(color: context.onSurfaceVariant),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final t = trips[i];
          final color = t.status == 5
              ? AppColors.primary
              : t.status == 6
                  ? AppColors.danger
                  : AppColors.secondary;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(
                  t.status == 5
                      ? Icons.check
                      : t.status == 6
                          ? Icons.close
                          : Icons.schedule,
                  color: color,
                ),
              ),
              title: Text(L10n.f('route_arrow', {'a': t.pickupAddress, 'b': t.dropoffAddress ?? ''})),
              subtitle: Text(
                isUpcoming
                    ? L10n.f('dotted', {
                        'a': t.statusLabel,
                        'b': t.scheduledAt != null
                            ? '${t.scheduledAt!.hour.toString().padLeft(2, '0')}:${t.scheduledAt!.minute.toString().padLeft(2, '0')}'
                            : '-'
                      })
                    : L10n.f('dotted', {
                        'a': t.statusLabel,
                        'b': t.distanceKm?.toStringAsFixed(1) ?? '-'
                      }),
              ),
              trailing: isUpcoming
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (t.scheduledAt != null)
                          Text(
                            '${t.scheduledAt!.day}/${t.scheduledAt!.month} ${t.scheduledAt!.hour.toString().padLeft(2, '0')}:${t.scheduledAt!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                                fontSize: 12,
                                color: context.onSurfaceVariant),
                          ),
                        IconButton(
                          tooltip: L10n.t('cancel_trip'),
                          icon: const Icon(Icons.close,
                              color: AppColors.danger),
                          onPressed: () => _cancelScheduled(t),
                        ),
                      ],
                    )
                  : t.estimatedFare != null
                      ? Text(
                          L10n.f('egp_amount',
                              {'n': t.estimatedFare.toString()}),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
              onTap: () => _showDetails(t),
            ),
          );
        },
      ),
    );
  }
}