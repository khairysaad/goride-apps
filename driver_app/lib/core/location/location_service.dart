import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/app_theme.dart';
import '../../providers/settings_provider.dart';
enum LocationAccess { granted, denied, deniedForever, serviceDisabled, unknown }

class LocationService {
  static Future<LocationAccess> checkAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    final p = await Geolocator.checkPermission();
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccess.granted;
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.denied:
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.whileInUse || req == LocationPermission.always) {
          return LocationAccess.granted;
        }
        return LocationAccess.denied;
      case LocationPermission.unableToDetermine:
        return LocationAccess.denied;
    }
  }

  static Future<LocationAccess> requestWithRationale(BuildContext context) async {
    final access = await checkAccess();
    if (access == LocationAccess.granted) return access;
    if (!context.mounted) return access;

    final explain = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('location_title')),
        content: Text(
          '${L10n.t('location_why_request')}\n\n${L10n.t('location_privacy')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.t('not_now')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.t('continue_btn')),
          ),
        ],
      ),
    );

    if (explain != true) return access;

    if (access == LocationAccess.deniedForever) {
      return _openSettingsDialog(context);
    }

    return checkAccess().then((value) {
      if (value == LocationAccess.deniedForever && context.mounted) {
        return _openSettingsDialog(context);
      }
      return value;
    });
  }

  static LocationAccess _openSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('location_denied')),
        content: Text(
          L10n.t('location_denied_msg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.t('later')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: Text(L10n.t('open_settings')),
          ),
        ],
      ),
    );
    return LocationAccess.deniedForever;
  }
}

class LocationPermissionCard extends StatelessWidget {
  final VoidCallback onRetry;

  const LocationPermissionCard({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 56, color: AppColors.secondary),
            const SizedBox(height: 12),
            Text(
              L10n.t('location_required'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              L10n.t('location_required_msg'),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.my_location, size: 20),
              label: Text(L10n.t('allow_location')),
            ),
          ],
        ),
      ),
    );
  }
}