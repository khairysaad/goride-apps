import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/driver_provider.dart';
import '../../providers/trip_provider.dart';
import 'driver_requests_screen.dart';
import '../../providers/settings_provider.dart';

class DriverApplyScreen extends StatefulWidget {
  const DriverApplyScreen({super.key});

  @override
  State<DriverApplyScreen> createState() => _DriverApplyScreenState();
}

class _DriverApplyScreenState extends State<DriverApplyScreen> {
  final _license = TextEditingController();
  final _nationalId = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _plate = TextEditingController();
  int? _vehicleTypeId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceProvider>().loadHomeData();
    });
  }

  @override
  void dispose() {
    _license.dispose();
    _nationalId.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_vehicleTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('choose_type'))),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await context.read<DriverProvider>().apply(
            licenseNumber: _license.text.trim(),
            nationalId: _nationalId.text.trim(),
            vehicleMake: _make.text.trim(),
            vehicleModel: _model.text.trim(),
            vehicleYear: int.tryParse(_year.text.trim()) ?? 0,
            vehiclePlate: _plate.text.trim(),
            vehicleTypeId: _vehicleTypeId!,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.t('apply_done'))),
        );
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

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>().driver;
    final vehicleTypes = context.watch<ServiceProvider>().vehicleTypes;

    if (driver != null && driver.isVerified != true) {
      return Scaffold(
        appBar: AppBar(title: Text(L10n.t('apply_title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top,
                    size: 64, color: AppColors.warning),
                const SizedBox(height: 16),
                Text(
                  L10n.t('pending_apply'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  L10n.t('apply_pending_msg'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DriverRequestsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_outlined),
                  label: Text(L10n.t('view_requests')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('apply_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              L10n.t('apply_subtitle'),
              style: TextStyle(color: context.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (vehicleTypes.isNotEmpty) ...[
              DropdownButtonFormField<int>(
                value: _vehicleTypeId,
                decoration: InputDecoration(
                  labelText: L10n.t('vehicle_type'),
                  prefixIcon: const Icon(Icons.local_taxi_outlined),
                ),
                items: [
                  for (final vt in vehicleTypes)
                    DropdownMenuItem(value: vt.id, child: Text(vt.name)),
                ],
                onChanged: (v) => setState(() => _vehicleTypeId = v),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _license,
              decoration: InputDecoration(
                labelText: L10n.t('license_number'),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nationalId,
              decoration: InputDecoration(
                labelText: L10n.t('national_id'),
                prefixIcon: const Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _make,
              decoration: InputDecoration(
                labelText: L10n.t('car_make'),
                prefixIcon: const Icon(Icons.directions_car_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _model,
              decoration: InputDecoration(
                labelText: L10n.t('car_model'),
                prefixIcon: const Icon(Icons.directions_car_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: L10n.t('vehicle_year'),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _plate,
              decoration: InputDecoration(
                labelText: L10n.t('plate_number'),
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(L10n.t('apply_submit')),
            ),
          ],
        ),
      ),
    );
  }
}