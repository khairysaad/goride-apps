import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String kBaseUrl = 'https://goride-server.tailaf7d4.ts.net/goride-api';
const String kManifestUrl = '$kBaseUrl/api/installer/apps';

const MethodChannel _channel = MethodChannel('goride/installer');

class AppInfo {
  final String key;
  final String name;
  final String version;
  final String url;
  final String md5;
  final String notes;
  final String package;
  final int size;

  AppInfo({
    required this.key,
    required this.name,
    required this.version,
    required this.url,
    required this.md5,
    required this.notes,
    required this.package,
    required this.size,
  });

  factory AppInfo.fromJson(Map<String, dynamic> j) => AppInfo(
        key: (j['key'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        version: (j['version'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        md5: (j['md5'] ?? '') as String,
        notes: (j['notes'] ?? '') as String,
        package: (j['package'] ?? '') as String,
        size: (j['size'] as num?)?.toInt() ?? 0,
      );

  String get sizeMb => size > 0 ? '${(size / 1048576).toStringAsFixed(1)} MB' : '';
}

enum Phase { idle, download, verify, installing, done, error }

class InstallState {
  Phase phase = Phase.idle;
  int percent = 0;
  String message = '';

  InstallState copyWith({Phase? phase, int? percent, String? message}) {
    final s = InstallState();
    s.phase = phase ?? this.phase;
    s.percent = percent ?? this.percent;
    s.message = message ?? this.message;
    return s;
  }
}

void main() => runApp(const InstallerApp());

class InstallerApp extends StatelessWidget {
  const InstallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مثبّت GoRide',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomeScreen(),
    );
  }

  ThemeData _theme() {
    const navy = Color(0xFF0E2750);
    const navy2 = Color(0xFF163A6B);
    const sky = Color(0xFF38BDF8);
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: navy,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sky,
        brightness: Brightness.dark,
        surface: navy2,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: const Color(0xFFEAF2FF),
        displayColor: const Color(0xFFEAF2FF),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: sky),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy2,
        contentTextStyle: const TextStyle(color: Color(0xFFEAF2FF)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<List<AppInfo>> _fetchApps() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final req = await client
        .getUrl(Uri.parse(kManifestUrl))
        .timeout(const Duration(seconds: 25));
    req.headers.set('Accept', 'application/json');
    final res = await req.close().timeout(const Duration(seconds: 25));
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: req.uri);
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final raw = json['apps'] as List? ?? [];
    return raw
        .map((e) => AppInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  } finally {
    client.close();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AppInfo>? _apps;
  String? _error;
  final Map<String, InstallState> _states = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted) return;
    try {
      final r = await _channel.invokeMethod<dynamic>('getStatus');
      if (r is! Map) return;
      final data = r.cast<String, dynamic>();
      final app = data['app'] as String? ?? '';
      final st = _states[app];
      if (st == null) return;
      final phase = _phase(data['phase']);
      final percent = _i(data['percent']);
      final message = (data['message'] ?? '').toString();
      if (st.phase != phase || st.percent != percent || st.message != message) {
        _states[app] = st.copyWith(phase: phase, percent: percent, message: message);
        setState(() {});
      }
    } catch (_) {
      // يظل الاشتراك حيًا — يتصل ثانية في الدورة القادمة
    }
  }

  Phase _phase(dynamic v) {
    switch ((v as num?)?.toInt() ?? 0) {
      case 1:
        return Phase.download;
      case 2:
        return Phase.verify;
      case 3:
        return Phase.installing;
      case 4:
        return Phase.done;
      case 5:
        return Phase.error;
      default:
        return Phase.idle;
    }
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _apps = null;
    });
    try {
      final apps = await _fetchApps();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        for (final a in apps) {
          _states.putIfAbsent(a.key, () => InstallState());
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'تعذر الاتصال بالخادم — تحقق من الإنترنت ثم أعد المحاولة');
    }
  }

  int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

  Future<void> _install(AppInfo a) async {
    final can = await _channel.invokeMethod<bool>('canInstall');
    if (can != true) {
      final go = await _askPermission();
      if (go == true) {
        await _channel.invokeMethod<bool>('openUnknownSources');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'فعّل "السماح من هذا المصدر" لمثبّت GoRide ثم اضغط تثبيت مجددًا')),
        );
      }
      return;
    }
    _states[a.key] = InstallState()
      ..phase = Phase.download
      ..percent = 0;
    setState(() {});
    try {
      await _channel.invokeMethod(
        'install',
        {'app': a.key, 'url': a.url, 'md5': a.md5, 'package': a.package},
      );
    } on PlatformException catch (e) {
      _states[a.key] = InstallState()
        ..phase = Phase.error
        ..message = e.message ?? 'حدث خطأ';
      setState(() {});
    }
  }

  Future<bool?> _askPermission() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF163A6B),
        title: const Text('السماح بالتثبيت'),
        content: const Text(
          'لأمان جهازك، يطلب أندرويد السماح لمثبّت GoRide بتثبيت التطبيقات.\n'
          'اضغط "السماح" ثم فعّل المفتاح وعُد. تتم هذه الخطوة مرة واحدة فقط.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('السماح'),
          ),
        ],
      ),
    );
  }

  Future<void> _open(AppInfo a) async {
    try {
      await _channel.invokeMethod('openApp', {'package': a.package});
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'التطبيق غير مثبت')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _apps == null
          ? (_error == null ? const _Splash() : _ErrorView(onRetry: _load))
          : _MainView(
              apps: _apps!,
              states: _states,
              onInstall: _install,
              onOpen: _open,
              onRefresh: _load,
            ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('جارٍ تحميل التطبيقات المتاحة...'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: Color(0xFFF59E0B)),
            const SizedBox(height: 16),
            const Text('تعذر الوصول للخادم', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'تأكد من اتصال الإنترنت واضغط إعادة المحاولة.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainView extends StatelessWidget {
  final List<AppInfo> apps;
  final Map<String, InstallState> states;
  final ValueChanged<AppInfo> onInstall;
  final ValueChanged<AppInfo> onOpen;
  final VoidCallback onRefresh;

  const _MainView({
    required this.apps,
    required this.states,
    required this.onInstall,
    required this.onOpen,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 64, 20, 32),
        children: [
          const Center(
            child: Text(
              'مثبّت GoRide',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFF38BDF8),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ثبّت التطبيقات مباشرة من هنا — خطوة أمان واحدة فقط',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFA9C3E8)),
          ),
          const SizedBox(height: 24),
          for (final a in apps) ...[
            _AppCard(
              info: a,
              state: states[a.key] ?? InstallState(),
              onInstall: () => onInstall(a),
              onOpen: () => onOpen(a),
            ),
            const SizedBox(height: 16),
          ],
          const Divider(color: Color(0xFF24507F)),
          const SizedBox(height: 8),
          const Text(
            'شغّال مع أي متصفح — المثبّت يثبّت التطبيقات بنظام أندرويد مباشرة، '
            'فلا حاجة لمتصفح خاص أو متجر. التنزيل يستمر في الخلفية حتى لو أغلقت التطبيق، '
            'ويظهر شريط تقدّم في الإشعارات.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFA9C3E8), fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final AppInfo info;
  final InstallState state;
  final VoidCallback onInstall;
  final VoidCallback onOpen;

  const _AppCard({
    required this.info,
    required this.state,
    required this.onInstall,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final busy = state.phase == Phase.download ||
        state.phase == Phase.verify ||
        state.phase == Phase.installing;

    final action = busy
        ? FilledButton(
            onPressed: null,
            child: const Text('قيد التثبيت...'),
          )
        : state.phase == Phase.done
            ? FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
                label: const Text('فتح التطبيق'),
              )
            : FilledButton.icon(
                onPressed: onInstall,
                icon: const Icon(Icons.download),
                label: const Text('تثبيت الآن'),
              );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF163A6B).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF24507F)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  info.key == 'driver'
                      ? Icons.local_taxi
                      : Icons.airport_shuttle,
                  color: const Color(0xFF38BDF8),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.name,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'الإصدار ${info.version}'
                      '${info.sizeMb.isNotEmpty ? ' · ${info.sizeMb}' : ''}',
                      style: const TextStyle(
                          color: Color(0xFFA9C3E8), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (info.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              info.notes,
              style: const TextStyle(
                  color: Color(0xFFA9C3E8), fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 16),
          if (busy) ...[
            _ProgressBar(state: state),
            const SizedBox(height: 12),
          ],
          if (state.phase == Phase.error) ...[
            Text(
              state.message,
              style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          if (state.phase == Phase.done) ...[
            const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('تم التثبيت بنجاح ✓',
                    style: TextStyle(color: Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 12),
          ],
          action,
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final InstallState state;
  const _ProgressBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final label = switch (state.phase) {
      Phase.download => 'جارٍ التنزيل... ${state.percent}%',
      Phase.verify => 'جارٍ التحقق من سلامة الملف...',
      Phase.installing => 'جارٍ التثبيت... ${state.percent}%',
      _ => '',
    };
    final value = state.phase == Phase.verify ? null : state.percent / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: value, minHeight: 6, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}
