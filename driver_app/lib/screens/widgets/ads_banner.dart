import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../config/api_config.dart';
import '../../models/models.dart';
import '../../providers/ads_provider.dart';

class AdsBanner extends StatefulWidget {
  const AdsBanner({
    super.key,
    required this.target,
    this.height = 150,
    this.minHeight = 90,
    this.maxHeight = 400,
    this.interval = const Duration(seconds: 5),
  });

  final String target;

  /// الارتفاع الافتراضي المستخدم فقط عندما نجهل نسبة أبعاد الوسيط.
  final double height;

  /// حدود الارتفاع عند حساب الحجم تلقائياً من نسبة الصورة (عرض الشاشة كامل).
  final double minHeight;
  final double maxHeight;

  /// المدة التي يبقى فيها الإعلان (صورة/يوتيوب) قبل الانتقال للتالي.
  /// أما الفيديو فينتقل تلقائياً بعد انتهاء التشغيل.
  final Duration interval;

  @override
  State<AdsBanner> createState() => _AdsBannerState();
}

class _AdsBannerState extends State<AdsBanner> {
  final PageController _controller = PageController();
  final Map<int, double> _ratios = {};
  final Map<int, Duration?> _videoDur = {};
  Timer? _timer;
  int _index = 0;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdsProvider>().load(target: widget.target);
    });
  }

  List<Ad> _ads() => context.read<AdsProvider>().ads;

  void _onRatio(int id, double ratio) {
    if (!mounted || ratio <= 0) return;
    if ((_ratios[id] ?? 0) == ratio) return;
    setState(() => _ratios[id] = ratio);
  }

  void _onVideoReady(int id, Duration? duration) {
    _videoDur[id] = duration;
    if (!mounted) return;
    final ads = _ads();
    final idx = _index.clamp(0, ads.length - 1);
    if (ads.isNotEmpty && ads[idx].id == id) _scheduleNext(ads);
  }

  double _ratioFor(Ad ad) {
    if (ad.ratio != null && ad.ratio! > 0) return ad.ratio!;
    final detected = _ratios[ad.id];
    if (detected != null && detected > 0) return detected;
    if (ad.isYoutube) return 16 / 9;
    return 0;
  }

  double _heightFor(Ad ad, double width) {
    final r = _ratioFor(ad);
    if (r <= 0) return widget.height;
    return (width / r).clamp(widget.minHeight, widget.maxHeight);
  }

  void _advance() {
    if (!mounted || !_controller.hasClients) return;
    final ads = _ads();
    if (ads.length <= 1) return;
    _controller.animateToPage(
      (_index + 1) % ads.length,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _scheduleNext(List<Ad> ads) {
    _timer?.cancel();
    if (ads.length <= 1) return;
    final ad = ads[_index.clamp(0, ads.length - 1)];
    final custom = ad.duration;
    Duration d;
    if (custom != null && custom > 0) {
      d = Duration(seconds: custom);
    } else if (ad.isVideo) {
      final vd = _videoDur[ad.id];
      d = (vd != null && vd > Duration.zero)
          ? vd + const Duration(milliseconds: 500)
          : const Duration(seconds: 12);
    } else {
      d = widget.interval;
    }
    _timer = Timer(d, _advance);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdsProvider>(
      builder: (context, provider, _) {
        final ads = provider.ads;
        if (ads.isEmpty) return const SizedBox.shrink();
        if (!_armed) {
          _armed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scheduleNext(_ads());
          });
        }
        if (_index >= ads.length) _index = 0;
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;
            final idx = _index.clamp(0, ads.length - 1);
            final height = _heightFor(ads[idx], width);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: height,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: ads.length,
                    onPageChanged: (i) {
                      setState(() => _index = i);
                      _scheduleNext(ads);
                    },
                    itemBuilder: (context, i) => _adCard(
                      context,
                      ads[i],
                      i == _index,
                      ads.length <= 1,
                    ),
                  ),
                ),
                if (ads.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      ads.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _adCard(BuildContext context, Ad ad, bool active, bool soleAd) {
    final radius = BorderRadius.circular(16);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          onTap: _onAdTap(ad),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _media(context, ad, active, soleAd),
              if ((ad.title ?? '').isNotEmpty || (ad.subtitle ?? '').isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((ad.title ?? '').isNotEmpty)
                          Text(
                            ad.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        if ((ad.subtitle ?? '').isNotEmpty)
                          Text(
                            ad.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _media(BuildContext context, Ad ad, bool active, bool soleAd) {
    final surface = Theme.of(context).colorScheme.surface;
    if (ad.isYoutube) {
      final id = ad.youtubeId;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (id != null)
            CachedNetworkImage(
              imageUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: surface),
              errorWidget: (_, _, _) => Container(color: Colors.black),
            )
          else
            Container(color: Colors.black),
          Container(color: Colors.black26),
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
          ),
        ],
      );
    }
    if (ad.isVideo) {
      final hasCustom = ad.duration != null && ad.duration! > 0;
      return _AdVideo(
        url: ad.imageUrl,
        active: active,
        loop: soleAd || hasCustom,
        onTap: _onAdTap(ad),
        onRatio: (r) => _onRatio(ad.id, r),
        onReady: (d) => _onVideoReady(ad.id, d),
        onCompleted: hasCustom ? null : _advance,
      );
    }
    final resolved = ApiConfig.resolve(ad.imageUrl);
    return _RatioReporter(
      url: resolved,
      onRatio: (r) => _onRatio(ad.id, r),
      child: CachedNetworkImage(
        imageUrl: resolved,
        fit: BoxFit.contain,
        placeholder: (_, _) => Container(color: surface),
        errorWidget: (_, _, _) => Container(
          color: surface,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  VoidCallback? _onAdTap(Ad ad) {
    if (ad.hasLink) return () => _openLink(ad.linkUrl!);
    if (ad.isYoutube) return () => _openLink(ad.imageUrl);
    if (ad.isVideo) return () => _openLink(ApiConfig.resolve(ad.imageUrl));
    return null;
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

/// يستنتج نسبة أبعاد الصورة (العرض/الارتفاع) ثم يبلّغ الأعلى بها،
/// حتى يُضبط ارتفاع الإعلان بحيث تظهر الصورة كاملة بعرض الشاشة دون اقتصاص.
class _RatioReporter extends StatefulWidget {
  const _RatioReporter({
    required this.url,
    required this.child,
    this.onRatio,
  });

  final String url;
  final Widget child;
  final ValueChanged<double>? onRatio;

  @override
  State<_RatioReporter> createState() => _RatioReporterState();
}

class _RatioReporterState extends State<_RatioReporter> {
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  void _resolve() {
    try {
      final provider = CachedNetworkImageProvider(widget.url);
      final stream = provider.resolve(const ImageConfiguration());
      _stream = stream;
      _listener = ImageStreamListener((info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (w > 0 && h > 0) widget.onRatio?.call(w / h);
      });
      stream.addListener(_listener!);
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AdVideo extends StatefulWidget {
  const _AdVideo({
    required this.url,
    required this.active,
    required this.loop,
    this.onTap,
    this.onRatio,
    this.onReady,
    this.onCompleted,
  });

  final String url;
  final bool active;
  final bool loop;
  final VoidCallback? onTap;
  final ValueChanged<double>? onRatio;
  final ValueChanged<Duration?>? onReady;
  final VoidCallback? onCompleted;

  @override
  State<_AdVideo> createState() => _AdVideoState();
}

class _AdVideoState extends State<_AdVideo> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _inited = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _init();
  }

  @override
  void didUpdateWidget(covariant _AdVideo old) {
    super.didUpdateWidget(old);
    if (widget.active && !_inited) {
      _init();
    } else if (_ready) {
      if (widget.active) {
        _completed = false;
        _c?.seekTo(Duration.zero);
        _c?.play();
      } else {
        _c?.pause();
      }
    }
  }

  Future<void> _init() async {
    _inited = true;
    final uri = Uri.tryParse(ApiConfig.resolve(widget.url));
    if (uri == null) return;
    final c = VideoPlayerController.networkUrl(uri);
    _c = c;
    c.addListener(_onPos);
    try {
      await c.initialize();
      await c.setLooping(widget.loop);
      await c.setVolume(0);
      final size = c.value.size;
      if (size.width > 0 && size.height > 0) {
        widget.onRatio?.call(size.width / size.height);
      }
      widget.onReady?.call(c.value.duration);
      if (widget.active) await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  void _onPos() {
    if (widget.loop || _completed) return;
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    final d = c.value.duration;
    final p = c.value.position;
    if (d > Duration.zero && p >= d - const Duration(milliseconds: 120)) {
      _completed = true;
      widget.onCompleted?.call();
    }
  }

  @override
  void dispose() {
    _c?.removeListener(_onPos);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null || !_ready) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(Icons.videocam_outlined,
            color: Colors.white54, size: 40),
      );
    }
    final size = c.value.size;
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: () {},
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: size.width == 0 ? 16 : size.width,
          height: size.height == 0 ? 9 : size.height,
          child: VideoPlayer(c),
        ),
      ),
    );
  }
}
