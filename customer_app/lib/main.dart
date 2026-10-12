import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'core/fcm/fcm_service.dart';
import 'providers/ads_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/location_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/complaint_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) => Directionality(
        textDirection: TextDirection.rtl,
        child: ColoredBox(
          color: const Color(0xFF0B1220),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'خطأ: ${details.exception}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      );
  final theme = ThemeProvider();
  final settings = SettingsProvider();
  await theme.load();
  await settings.load();
  unawaited(FcmService.initialize()
      .then((ready) => debugPrint('FcmService ready: $ready')));
  runApp(GoRideApp(themeProvider: theme, settingsProvider: settings));
}

class GoRideApp extends StatelessWidget {
  const GoRideApp({
    super.key,
    required this.themeProvider,
    required this.settingsProvider,
  });

  final ThemeProvider themeProvider;
  final SettingsProvider settingsProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => ComplaintProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AdsProvider()),
      ],
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, theme, settings, _) => MaterialApp(
          key: ValueKey(settings.locale),
          title: 'خط سيري',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          locale: Locale(settings.locale),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Container(
            decoration: const BoxDecoration(gradient: AppColors.bgGradient),
            child: child,
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}