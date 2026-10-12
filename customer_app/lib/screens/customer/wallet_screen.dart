import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/settings_provider.dart';
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const _presets = [50, 100, 200, 500];
  double _selected = 100;
  final _custom = TextEditingController();
  PaymentChannel? _method;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().load();
    });
    context.read<PaymentProvider>().load().then((_) {
      if (!mounted) return;
      final methods = context.read<PaymentProvider>().topupMethods;
      if (methods.isNotEmpty) {
        setState(() => _method = methods.first);
      }
    });
  }

  Future<void> _topup(double amount) async {
    setState(() => _busy = true);
    try {
      final res = await context.read<WalletProvider>().topup(amount, method: _method?.key);
      if (!mounted) return;
      final pending = (res['status'] ?? '').toString() == 'pending';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pending
            ? L10n.f('topup_pending', {'amount': '$amount'})
            : L10n.f('topup_ok', {'amount': '$amount'}))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('wallet'))),
      body: RefreshIndicator(
        onRefresh: () => context.read<WalletProvider>().load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
          Card(
            color: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.t('available_balance'),
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(L10n.t('wallet_topup_title'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presets.map((v) {
              final selected = _selected == v;
              return ChoiceChip(
                label: Text(L10n.f('egp_amount', {'n': '$v'})),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selected = v.toDouble();
                    _custom.clear();
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _custom,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: L10n.t('custom_amount'),
              hintText: L10n.t('custom_amount_hint'),
              prefixText: L10n.t('EGP_SUFFIX'),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) {
                setState(() => _selected = parsed);
              } else {
                setState(() => _selected = 0);
              }
            },
          ),
          const SizedBox(height: 16),
          Text(L10n.t('payment_method'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _methodSelector(context),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy
                ? null
                : () {
                    final amount = _selected;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(L10n.t('err_amount'))),
                      );
                      return;
                    }
                    _topup(amount);
                  },
            child: Text(L10n.t('add_balance')),
          ),
          const SizedBox(height: 24),
          Text(L10n.t('transactions'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (wallet.transactions.isEmpty)
            Text(L10n.t('no_transactions'),
                style: TextStyle(color: context.onSurfaceVariant))
          else
            ...wallet.transactions.map((t) => _txTile(t)),
        ],
        ),
      ),
    );
  }

  Widget _methodSelector(BuildContext context) {
    final methods = context.watch<PaymentProvider>().topupMethods;
    if (methods.isEmpty) {
      return Text(L10n.t('no_payment_methods'),
          style: TextStyle(color: context.onSurfaceVariant));
    }
    if (methods.any((m) => m.key == _method?.key) == false) {
      _method = methods.first;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: methods.map((m) {
            final selected = m.key == _method?.key;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => setState(() => _method = m),
              showCheckmark: false,
              avatar: Icon(_payIcon(m.icon), size: 18),
              label: Text(m.nameAr),
              labelStyle: const TextStyle(fontSize: 12),
            );
          }).toList(),
        ),
        if (_method != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.f('send_amount_to', {
                    'method': _method!.nameAr,
                  }),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  _method!.account?.isNotEmpty == true
                      ? _method!.account!
                      : _method!.key.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (_method!.holderName?.isNotEmpty == true)
                  Text(_method!.holderName!,
                      style: TextStyle(color: context.onSurfaceVariant)),
                if (_method!.instructions?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(_method!.instructions!,
                      style: TextStyle(
                          color: context.onSurfaceVariant, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  IconData _payIcon(String key) {
    switch (key) {
      case 'cash':
        return Icons.payments;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'card':
        return Icons.credit_card;
      case 'vodafone_cash':
        return Icons.phone_iphone;
      case 'instapay':
        return Icons.bolt;
      case 'fawry':
        return Icons.local_atm;
      case 'orange_cash':
        return Icons.phone_android;
      case 'etisalat_cash':
        return Icons.smartphone;
      default:
        return Icons.payments;
    }
  }

  Widget _txTile(WalletTransaction t) {
    final credit = t.amount >= 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: credit
            ? Colors.green.withValues(alpha: 0.15)
            : AppColors.danger.withValues(alpha: 0.15),
        child: Icon(
          credit ? Icons.add : Icons.remove,
          color: credit ? Colors.green : AppColors.danger,
        ),
      ),
      title: Text(t.description ?? L10n.t('operation')),
      subtitle: Text(_formatDate(t.createdAt)),
      trailing: Text(
        L10n.f('egp_amount',
            {'n': '${credit ? '+' : ''}${t.amount.toStringAsFixed(2)}'}),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: credit ? Colors.green : AppColors.danger,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m';
  }
}