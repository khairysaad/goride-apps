import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/trip_provider.dart';
import '../../providers/settings_provider.dart';

class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  List<Trip> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final trips = await context.read<TripProvider>().history();
      if (!mounted) return;
      setState(() {
        _trips = trips
            .where((t) => const [5, 6, 7, 8].contains(t.status))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _pmLabel(int method) => switch (method) {
        1 => L10n.t('pm_card'),
        2 => L10n.t('pm_wallet'),
        _ => L10n.t('pm_cash'),
      };

  String _cancelLabel(String? code) => switch (code) {
        'change_of_plan' => L10n.t('rc_plan_changed'),
        'driver_too_far' => L10n.t('rc_driver_far'),
        'long_wait_time' => L10n.t('rc_too_long'),
        'wrong_address' => L10n.t('rc_wrong_address'),
        'found_other_car' => L10n.t('rc_found_other'),
        _ => code ?? '',
      };

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d $h:$min';
  }

  Color _statusColor(int status) => switch (status) {
        5 => AppColors.success,
        6 => AppColors.danger,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('trip_history'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 100),
                    Icon(Icons.history,
                        size: 64, color: context.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(L10n.t('no_trips'), textAlign: TextAlign.center),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _tripCard(_trips[i]),
                  ),
                ),
    );
  }

  Widget _tripCard(Trip trip) {
    final fare = trip.status == 5
        ? (trip.actualFare ?? trip.estimatedFare)
        : trip.estimatedFare;
    final located = trip.completedAt ?? trip.acceptedAt ?? trip.scheduledAt;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(trip),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.skyLight,
                    child: const Icon(Icons.directions_car,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '#${trip.tripNumber}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Text(
                    trip.statusLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _statusColor(trip.status),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _row(Icons.place, trip.pickupAddress),
              if (trip.dropoffAddress != null) ...[
                const SizedBox(height: 6),
                _row(Icons.location_on, trip.dropoffAddress!),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.arrow_drop_down_circle_outlined,
                      size: 16, color: context.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _fmt(located),
                      style: TextStyle(
                          fontSize: 13, color: context.onSurfaceVariant),
                    ),
                  ),
                  if (fare != null)
                    Text(
                      L10n.f('egp_amount', {'n': fare.toStringAsFixed(0)}),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  void _showDetails(Trip trip) {
    final fare = trip.status == 5
        ? (trip.actualFare ?? trip.estimatedFare)
        : trip.estimatedFare;
    final located = trip.completedAt ?? trip.acceptedAt ?? trip.scheduledAt;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('#${trip.tripNumber}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _row(Icons.place, trip.pickupAddress),
              if (trip.dropoffAddress != null) ...[
                const SizedBox(height: 8),
                _row(Icons.location_on, trip.dropoffAddress!),
              ],
              const Divider(height: 28),
              _detail(
                  L10n.t('status_label'),
                  trip.statusLabel),
              _detail(L10n.t('payment_method'), _pmLabel(trip.paymentMethod)),
              _detail(L10n.t('actual_fare'),
                  fare != null ? fare.toStringAsFixed(2) : '-'),
              if (trip.status == 5) ...[
                _detail(
                    L10n.t('driver_earnings'),
                    trip.driverEarnings > 0
                        ? trip.driverEarnings.toStringAsFixed(2)
                        : '-'),
                _detail(
                    L10n.t('platform_fee'),
                    trip.platformFee > 0
                        ? trip.platformFee.toStringAsFixed(2)
                        : '-'),
              ],
              if (trip.distanceKm != null)
                _detail(
                    L10n.t('distance_label'),
                    L10n.f('km_value',
                        {'n': trip.distanceKm!.toStringAsFixed(2)})),
              if (trip.durationMinutes != null)
                _detail(
                    L10n.t('duration_label'), '${trip.durationMinutes}'),
              _detail(L10n.t('status_history_title'), _fmt(located)),
              const SizedBox(height: 8),
              if (trip.cancelReasonText != null &&
                  trip.cancelReasonText!.isNotEmpty)
                Text(
                  '${L10n.t('cancel_reason_title')}: ${trip.cancelReasonText}',
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                )
              else if (trip.cancelReason != null)
                Text(
                  '${L10n.t('cancel_reason_title')}: ${_cancelLabel(trip.cancelReason)}',
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: context.onSurfaceVariant, fontSize: 14)),
          ),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}