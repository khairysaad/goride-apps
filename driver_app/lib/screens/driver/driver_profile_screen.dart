import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../providers/settings_provider.dart';
import 'about_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_history_screen.dart';
import 'driver_vehicles_screen.dart';
import '../auth/login_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().loadProfile();
    });
  }

  Future<void> _toggle() async {
    try {
      await context.read<DriverProvider>().toggleAvailability();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('logout')),
        content: Text(L10n.t('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.t('logout')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>().driver;

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('profile'))),
      body: driver == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(driver),
                const SizedBox(height: 16),
                _stats(driver),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.power_settings_new,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text(
                          driver.isOnline
                              ? L10n.t('go_offline')
                              : L10n.t('go_online'),
                        ),
                        subtitle: Text(
                          driver.isOnline
                              ? L10n.t('online_idle')
                              : L10n.t('offline_prompt'),
                        ),
                        trailing: Switch(
                          value: driver.isOnline,
                          onChanged: (_) => _toggle(),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.directions_car,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text(L10n.t('my_vehicles')),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DriverVehiclesScreen(),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.history,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text(L10n.t('trip_history')),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DriverHistoryScreen(),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.account_balance_wallet,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text(L10n.t('earnings_withdrawals')),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DriverEarningsScreen(),
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary),
                        title: Text(L10n.t('about_app')),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  icon: const Icon(Icons.logout),
                  label: Text(L10n.t('logout')),
                ),
              ],
            ),
    );
  }

  Widget _header(dynamic driver) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white24,
            foregroundImage: (driver?.photo != null &&
                    driver!.photo!.isNotEmpty)
                ? NetworkImage(ApiConfig.resolve(driver.photo!))
                : null,
            child: (driver?.photo == null || driver!.photo!.isEmpty)
                ? Text(
                    (driver?.name ?? 'س').isEmpty
                        ? 'س'
                        : (driver?.name ?? 'س')[0],
                    style: const TextStyle(
                        color: Colors.white, fontSize: 26),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver?.name ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (driver?.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    L10n.f('phone_value', {'phone': driver!.phone!}),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        driver?.isVerified == true
                            ? Icons.verified
                            : Icons.pending,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        driver?.isVerified == true
                            ? L10n.t('verified')
                            : L10n.t('pending_verification'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(dynamic driver) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            _stat(
                Icons.star,
                AppColors.secondary,
                '${driver?.ratingAvg}',
                L10n.t('rating')),
            _stat(
                Icons.directions_car,
                Theme.of(context).colorScheme.primary,
                '${driver?.tripsCount}',
                L10n.t('trips_label')),
            _stat(
                Icons.account_balance_wallet,
                Theme.of(context).colorScheme.primary,
                '${driver?.totalEarnings ?? 0}',
                L10n.t('total_earnings')),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, Color color, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, color: context.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}