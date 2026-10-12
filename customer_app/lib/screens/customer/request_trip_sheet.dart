import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/trip_provider.dart';
import '../../providers/payment_provider.dart';
import 'dropoff_picker.dart';
import '../../providers/settings_provider.dart';
class TripRequestData {
  final LatLng dropoff;
  final String dropoffAddress;
  final int? serviceTypeId;
  final int paymentMethod;
  final bool isScheduled;
  final DateTime? scheduledAt;
  final String? couponCode;

  const TripRequestData({
    required this.dropoff,
    required this.dropoffAddress,
    this.serviceTypeId,
    this.paymentMethod = 0,
    this.isScheduled = false,
    this.scheduledAt,
    this.couponCode,
  });
}

class RequestTripSheet extends StatefulWidget {
  const RequestTripSheet({
    super.key,
    required this.pickupLatLng,
    this.initialServiceTypeId,
    this.initialCouponCode,
    this.initialDropoff,
    this.initialDropoffAddress,
  });

  final LatLng pickupLatLng;
  final int? initialServiceTypeId;
  final String? initialCouponCode;
  final LatLng? initialDropoff;
  final String? initialDropoffAddress;

  @override
  State<RequestTripSheet> createState() => _RequestTripSheetState();
}

class _RequestTripSheetState extends State<RequestTripSheet> {
  final _dropoffController = TextEditingController();
  final _couponController = TextEditingController();
  LatLng? _dropoffLatLng;
  int? _selectedType;
  int? _serviceTypeId;
  int _paymentMethod = 0;
  List<PaymentChannel> _payChannels = PaymentProvider.fallback;
  bool _isScheduled = false;
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    context.read<ServiceProvider>().loadHomeData();
    if (widget.initialCouponCode != null &&
        widget.initialCouponCode!.trim().isNotEmpty) {
      _couponController.text = widget.initialCouponCode!.trim();
    }
    if (widget.initialDropoff != null) {
      _dropoffLatLng = widget.initialDropoff;
      _dropoffController.text =
          widget.initialDropoffAddress?.trim().isNotEmpty == true
              ? widget.initialDropoffAddress!.trim()
              : L10n.t('dropoff_on_map');
    }
    _preselectType();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final provider = context.read<PaymentProvider>();
    await provider.load();
    if (!mounted) return;
    final methods = provider.tripMethods;
    if (methods.isNotEmpty) {
      setState(() => _payChannels = methods);
    }
  }

  Future<void> _preselectType() async {
    final typeId = widget.initialServiceTypeId;
    if (typeId == null) return;
    final provider = context.read<ServiceProvider>();
    await provider.loadHomeData();
    if (!mounted) return;
    final vt = provider.vehicleTypes.where((v) => v.id == typeId).toList();
    if (vt.isEmpty) return;
    final st = provider.serviceTypes
        .where((s) => s.category == vt.first.category)
        .toList();
    setState(() {
      _selectedType = vt.first.id;
      if (st.isNotEmpty) _serviceTypeId = st.first.id;
    });
  }

  Future<void> _chooseDropoff() async {
    final result = await Navigator.of(context).push<DropoffSelection>(
      MaterialPageRoute(
        builder: (_) => DropoffPicker(initial: widget.pickupLatLng),
      ),
    );
    if (result != null) {
      setState(() {
        _dropoffLatLng = result.position;
        _dropoffController.text = result.address;
      });
    }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now().add(const Duration(minutes: 15));
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: now,
      helpText: L10n.t('pick_schedule'),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      helpText: L10n.t('pick_time'),
    );
    if (pickedTime == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_dropoffLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('err_dropoff_required'))),
      );
      return;
    }
    if (_isScheduled && _scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('err_schedule_required'))),
      );
      return;
    }
    Navigator.of(context).pop(
      TripRequestData(
        dropoff: _dropoffLatLng!,
        dropoffAddress: _dropoffController.text,
        serviceTypeId: _serviceTypeId,
        paymentMethod: _payChannels[_paymentMethod].enumValue ?? _paymentMethod,
        isScheduled: _isScheduled,
        scheduledAt: _scheduledAt,
        couponCode: _couponController.text.trim().isEmpty
            ? null
            : _couponController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: L10n.t('back'),
                  icon: const Icon(Icons.close),
                  color: context.onSurface,
                ),
                Expanded(
                  child: Text(
                    L10n.t('request_ride'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onTap: _chooseDropoff,
              readOnly: true,
              controller: _dropoffController,
              decoration: InputDecoration(
                labelText: L10n.t('dropoff'),
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _chooseDropoff,
              icon: const Icon(Icons.map_outlined),
              label: Text(L10n.t('select_on_map')),
            ),
            const SizedBox(height: 8),
            Text(
              L10n.t('vehicle_type'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Consumer<ServiceProvider>(
              builder: (context, provider, _) {
                if (provider.loading && provider.vehicleTypes.isEmpty) {
                  return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.vehicleTypes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final vt = provider.vehicleTypes[i];
                      final selected = _selectedType == vt.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedType = vt.id;
                            final st = provider.serviceTypes
                                .where((s) => s.category == vt.category)
                                .toList();
                            if (st.isNotEmpty) {
                              _serviceTypeId = st.first.id;
                            }
                          });
                        },
                        child: Container(
                          width: 110,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.divider,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _iconFor(vt.icon),
                                color: selected ? Theme.of(context).colorScheme.primary : context.onSurfaceVariant,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                vt.name,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                L10n.f('egp_amount',
                                    {'n': '${vt.minFare.round()}'}),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selected ? Theme.of(context).colorScheme.primary : context.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              if (vt.surgeMultiplier > 1) ...[
                                const SizedBox(height: 3),
                                Text(
                                  L10n.f('high_demand', {
                                    'mult': vt.surgeMultiplier.toStringAsFixed(1)
                                  }),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(settings.t('payment_method'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _paymentSelector(),
            const SizedBox(height: 16),
            TextField(
              controller: _couponController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: settings.t('coupon_optional'),
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
              ),
            ),
            if (_couponController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.skyLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        L10n.t('coupon_applied_hint'),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(L10n.t('ride_time'), style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.bolt, size: 18),
                    label: Text(settings.t('now')),
                    selected: !_isScheduled,
                    onSelected: (_) => setState(() {
                      _isScheduled = false;
                      _scheduledAt = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: Text(settings.t('later')),
                    selected: _isScheduled,
                    onSelected: (_) => setState(() => _isScheduled = true),
                  ),
                ),
              ],
            ),
            if (_isScheduled) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                  title: Text(
                    _scheduledAt == null
                        ? L10n.t('pick_schedule')
                        : '${_scheduledAt!.month}/${_scheduledAt!.day} · ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _pickSchedule,
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: Text(_isScheduled ? L10n.t('schedule_ride') : L10n.t('see_drivers')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentSelector() {
    final channels = _payChannels;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(channels.length, (i) {
        final selected = _paymentMethod == i;
        final c = channels[i];
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => _paymentMethod = i),
          showCheckmark: false,
          avatar: Icon(_payIcon(c.icon), size: 18),
          label: Text(c.nameAr),
          labelStyle: const TextStyle(fontSize: 12),
        );
      }),
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

  IconData _iconFor(String? icon) {
    switch (icon) {
      case 'car':
      case 'car_sport':
      case 'luxury_car':
        return Icons.directions_car;
      case 'van':
        return Icons.airport_shuttle;
      case 'motorcycle':
        return Icons.two_wheeler;
      default:
        return Icons.directions_car;
    }
  }
}