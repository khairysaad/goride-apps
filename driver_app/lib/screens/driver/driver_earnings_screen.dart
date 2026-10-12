import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/settings_provider.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  double _total = 0;
  double _pending = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await context.read<WalletProvider>().driverEarnings();
    if (!mounted) return;
    setState(() {
      _total = double.tryParse(data?['total_earnings']?.toString() ?? '0') ?? 0;
      _pending =
          double.tryParse(data?['pending_withdrawals']?.toString() ?? '0') ?? 0;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('my_earnings'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: AppColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(L10n.t('total_earnings'),
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(
                            L10n.f('egp_amount',
                                {'n': _total.toStringAsFixed(2)}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            L10n.f('pending_earnings',
                                {'n': _pending.toStringAsFixed(2)}),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 18, color: context.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          L10n.t('earnings_view_only'),
                          style: TextStyle(
                              fontSize: 13, color: context.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}