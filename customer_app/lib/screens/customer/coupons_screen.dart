import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/models.dart';
import '../../providers/location_provider.dart';
import '../../providers/trip_provider.dart';
import 'request_trip_sheet.dart';
import '../../providers/settings_provider.dart';

class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceProvider>().loadOffers();
    });
  }

  Future<void> _useCoupon(CouponItem offer) async {
    final location = context.read<LocationProvider>().current;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t('location_required'))),
      );
      return;
    }
    final pickup = LatLng(location.latitude, location.longitude);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RequestTripSheet(
        pickupLatLng: pickup,
        initialCouponCode: offer.code,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.t('offers_title'))),
      body: Consumer<ServiceProvider>(
        builder: (context, provider, _) {
          final offers = provider.offers;
          if (provider.loading && offers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (offers.isEmpty) {
            return Center(
              child: Text(
                L10n.t('no_offers'),
                style: TextStyle(color: context.onSurfaceVariant),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<ServiceProvider>().loadOffers(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _couponCard(offers[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _couponCard(CouponItem offer) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    offer.discountLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    offer.code,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            if (offer.title != null && offer.title!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                offer.title!,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
            if (offer.description != null && offer.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                offer.description!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            if (offer.minOrderAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                L10n.f('offer_min_order',
                    {'v': offer.minOrderAmount.toStringAsFixed(0)}),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                onPressed: () => _useCoupon(offer),
                icon: const Icon(Icons.directions_car, size: 18),
                label: Text(L10n.t('use_coupon')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}