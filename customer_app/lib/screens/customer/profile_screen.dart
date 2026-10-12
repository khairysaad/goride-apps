import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import 'complaints_screen.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'sos_screen.dart';
import 'wallet_screen.dart';
import 'about_screen.dart';
import '../auth/login_screen.dart';
import '../../providers/settings_provider.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _editProfile(BuildContext context, dynamic user) async {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email ?? '');
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('edit_profile')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: L10n.t('name')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: L10n.t('email_optional')),
            ),
          ],
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
    );
    if (submitted != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.updateProfile(
      name: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
      email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.t('profile_updated'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('my_account'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Icon(Icons.person, size: 44, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user.phone,
              style: TextStyle(color: context.onSurfaceVariant),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: () => _editProfile(context, user),
              icon: const Icon(Icons.edit, size: 18),
              label: Text(L10n.t('edit_profile')),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: Icon(Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.primary, size: 32),
              title: Text(L10n.t('wallet_balance')),
              subtitle: Text(
                L10n.f('wallet_hint', {'bal': '${user.walletBalance}'}),
                style: const TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.account_balance_wallet,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(L10n.t('wallet_topup')),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.headset_mic_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(L10n.t('complaints_support')),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ComplaintsScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.sos, color: AppColors.danger),
                  title: Text(L10n.t('sos_label')),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SosScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.notifications_none,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(L10n.t('notifications')),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.favorite_border, color: AppColors.danger),
                  title: Text(L10n.t('favorites')),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(L10n.t('appearance')),
                  trailing: DropdownButton<ThemeMode>(
                    value: context.watch<ThemeProvider>().mode,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(
                          value: ThemeMode.light, child: Text(L10n.t('theme_light'))),
                      DropdownMenuItem(
                          value: ThemeMode.dark, child: Text(L10n.t('theme_dark'))),
                      DropdownMenuItem(
                          value: ThemeMode.system, child: Text(L10n.t('theme_system'))),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        context.read<ThemeProvider>().setMode(mode);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(L10n.t('language_label')),
                  trailing: DropdownButton<String>(
                    value: context.watch<SettingsProvider>().locale,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: 'ar', child: Text(L10n.t('arabic'))),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (loc) {
                      if (loc != null) {
                        context.read<SettingsProvider>().setLocale(loc);
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.card_giftcard),
                  title: Text(L10n.t('referral_code')),
                  trailing: Text(
                    user.referralCode ?? 'GR-REF',
                    style: TextStyle(color: context.onSurfaceVariant),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
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
          ElevatedButton.icon(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            icon: const Icon(Icons.logout),
            label: Text(L10n.t('logout')),
          ),
        ],
      ),
    );
  }
}