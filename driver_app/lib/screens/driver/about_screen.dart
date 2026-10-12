import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_theme.dart';
import '../../providers/settings_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/201557622554');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('about_app'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Image.asset(
              'assets/logo.png',
              height: 100,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'خط سيري سائق',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('1.0.0',
                style: TextStyle(color: context.onSurfaceVariant)),
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.admin_panel_settings_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('معلومات المالك',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('ENG KHAIRY SAAD'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.chat,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('التواصل عبر واتساب'),
                  subtitle: const Text('+20 155 762 2554'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _openWhatsApp(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'جميع الحقوق محفوظة © 2026',
              style: TextStyle(fontSize: 12, color: context.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}