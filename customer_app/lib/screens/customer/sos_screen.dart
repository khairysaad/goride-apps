import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../providers/location_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/settings_provider.dart';
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  int _type = 0;
  bool _sending = false;

  Future<void> _sendSos() async {
    setState(() => _sending = true);
    try {
      final trip = context.read<TripProvider>().activeTrip;
      final pos = context.read<LocationProvider>().current;
      await ApiClient.instance.post('/emergency', data: {
        'type': _type,
        'trip_id': trip?.id,
        if (pos != null) 'lat': pos.latitude,
        if (pos != null) 'lng': pos.longitude,
        if (pos != null)
          'notes':
              'SOS (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})',
      });
      if (!mounted) return;
      setState(() => _sending = false);
      _showSentSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _showSentSheet() {
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
        child: SafeArea(
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
              const SizedBox(height: 20),
              const Icon(Icons.verified_user,
                  color: Colors.green, size: 56),
              const SizedBox(height: 12),
              Text(
                L10n.t('sos_sent'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                L10n.t('sos_sent_msg'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              _emergencyButton(ctx, Icons.local_police,
                  L10n.t('call_police'), '122'),
              const SizedBox(height: 10),
              _emergencyButton(ctx, Icons.medical_services,
                  L10n.t('call_ambulance'), '123'),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(L10n.t('close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emergencyButton(
      BuildContext ctx, IconData icon, String label, String number) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
      ),
      onPressed: () async {
        final ok = await launchUrl(Uri(scheme: 'tel', path: number),
            mode: LaunchMode.externalApplication);
        if (!mounted) return;
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.t('dial_failed'))),
          );
        }
      },
      icon: Icon(icon),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.watch<TripProvider>().activeTrip;

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('emergency'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.health_and_safety,
                color: AppColors.danger, size: 64),
            const SizedBox(height: 12),
            Text(
              L10n.t('sos_question'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              L10n.t('sos_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (trip != null)
              Card(
                child: ListTile(
                  leading: Icon(Icons.local_taxi, color: Theme.of(context).colorScheme.primary),
                  title: Text(L10n.f('trip_no', {'id': '${trip.id}'})),
                  subtitle: Text(trip.pickupAddress),
                  trailing: const Icon(Icons.chevron_left),
                ),
              ),
            const SizedBox(height: 14),
            Text(L10n.t('help_type'),
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                _typeChip(0, L10n.t('help_distress'), Icons.warning_amber),
                const SizedBox(width: 10),
                _typeChip(1, L10n.t('help_accident'), Icons.car_crash),
                const SizedBox(width: 10),
                _typeChip(2, L10n.t('help_danger'), Icons.gpp_maybe),
                const SizedBox(width: 10),
                _typeChip(3, L10n.t('other'), Icons.more_horiz),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _sendSos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                icon: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.sos, size: 26),
                label: Text(_sending
                    ? L10n.t('sending')
                    : L10n.t('send_sos')),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              L10n.t('emergency_contacts'),
              style:
                  TextStyle(fontSize: 13, color: context.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _quickDialCard(
                      Icons.local_police, L10n.t('call_police'), '122'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _quickDialCard(
                      Icons.medical_services, L10n.t('call_ambulance'), '123'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickDialCard(IconData icon, String label, String number) {
    return OutlinedButton.icon(
      onPressed: () async {
        await launchUrl(Uri(scheme: 'tel', path: number),
            mode: LaunchMode.externalApplication);
      },
      icon: Icon(icon, color: AppColors.danger, size: 20),
      label: Text(label,
          style: const TextStyle(fontSize: 12), overflow: TextOverflow.fade),
    );
  }

  Widget _typeChip(int value, String label, IconData icon) {
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.danger.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.danger : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 24,
                  color: selected ? AppColors.danger : context.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}