import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/driver_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/settings_provider.dart';

class DriverVehiclesScreen extends StatefulWidget {
  const DriverVehiclesScreen({super.key});

  @override
  State<DriverVehiclesScreen> createState() => _DriverVehiclesScreenState();
}

class _DriverVehiclesScreenState extends State<DriverVehiclesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().fetchVehicles();
      context.read<ServiceProvider>().loadHomeData();
    });
  }

  Future<void> _addVehicle() async {
    final make = TextEditingController();
    final model = TextEditingController();
    final year = TextEditingController();
    final plate = TextEditingController();
    final color = TextEditingController();
    int? typeId;
    final types = context.read<ServiceProvider>().vehicleTypes;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(L10n.t('add_vehicle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: typeId,
                  decoration:
                      InputDecoration(labelText: L10n.t('vehicle_type_label')),
                  items: [
                    for (final vt in types)
                      DropdownMenuItem(value: vt.id, child: Text(vt.name)),
                  ],
                  onChanged: (v) => setDialog(() => typeId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                    controller: make,
                    decoration:
                        InputDecoration(labelText: L10n.t('vehicle_make'))),
                const SizedBox(height: 8),
                TextField(
                    controller: model,
                    decoration:
                        InputDecoration(labelText: L10n.t('vehicle_model'))),
                const SizedBox(height: 8),
                TextField(
                    controller: year,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: L10n.t('vehicle_year'))),
                const SizedBox(height: 8),
                TextField(
                    controller: plate,
                    decoration:
                        InputDecoration(labelText: L10n.t('plate_number'))),
                const SizedBox(height: 8),
                TextField(
                    controller: color,
                    decoration:
                        InputDecoration(labelText: L10n.t('vehicle_color'))),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(L10n.t('cancel'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(L10n.t('save'))),
          ],
        ),
      ),
    );

    if (submitted != true || !mounted || typeId == null) return;
    try {
      await context.read<DriverProvider>().addVehicle(
            vehicleTypeId: typeId!,
            make: make.text.trim(),
            model: model.text.trim(),
            year: int.tryParse(year.text) ?? DateTime.now().year,
            plateNumber: plate.text.trim(),
            color: color.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('vehicle_added'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _setActive(int vehicleId) async {
    try {
      await context.read<DriverProvider>().setActiveVehicle(vehicleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('vehicle_made_active'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _deleteVehicle(int vehicleId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('delete_vehicle')),
        content: Text(L10n.t('vehicle_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.t('delete_vehicle')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<DriverProvider>().deleteVehicle(vehicleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('vehicle_deleted'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = context.watch<DriverProvider>().vehicles;

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('my_vehicles'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVehicle,
        icon: const Icon(Icons.add),
        label: Text(L10n.t('add_vehicle')),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<DriverProvider>().fetchVehicles(),
        child: vehicles.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.directions_car,
                      size: 56, color: context.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(L10n.t('no_vehicles'),
                        style: TextStyle(color: context.onSurfaceVariant)),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: vehicles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final v = vehicles[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.skyLight,
                        child: const Icon(Icons.car_rental,
                            color: AppColors.primary),
                      ),
                      title: Text(v.fullName),
                      subtitle: Text(
                        L10n.f('plate_seats',
                            {'plate': v.plateNumber, 'seats': '${v.seats}'}),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(v.isActive
                                ? L10n.t('active')
                                : L10n.t('inactive')),
                            backgroundColor: v.isActive
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.divider,
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'active') {
                                _setActive(v.id);
                              } else if (value == 'delete') {
                                _deleteVehicle(v.id);
                              }
                            },
                            itemBuilder: (_) => [
                              if (!v.isActive)
                                PopupMenuItem(
                                    value: 'active',
                                    child: ListTile(
                                        leading: const Icon(Icons.check),
                                        title:
                                            Text(L10n.t('set_active')))),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                      leading: const Icon(Icons.delete,
                                          color: AppColors.danger),
                                      title: Text(L10n.t('delete_vehicle')))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}