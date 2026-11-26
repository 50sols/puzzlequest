import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppFooterBanner extends StatefulWidget {
  const AppFooterBanner({super.key});

  @override
  State<AppFooterBanner> createState() => AppFooterBannerState();
}

class AppFooterBannerState extends State<AppFooterBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;
  int _generation = 0;
  Timer? _retry;

  void _resize(int width) {
    if (width <= 0 || width == _width) return;
    _width = width;
    final old = _ad;
    _ad = null;
    _loaded = false;
    if (old != null) unawaited(old.dispose());
    unawaited(_load(width, ++_generation));
  }

  Future<void> _load(int width, int generation) async {
    try {
      await MobileAds.instance.initialize();
      final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (!mounted || generation != _generation) return;
      if (size == null) { _scheduleRetry(width); return; }
      final ad = BannerAd(
        adUnitId: Platform.isAndroid
            ? 'ca-app-pub-3940256099942544/9214589741'
            : 'ca-app-pub-3940256099942544/2435281174',
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted && generation == _generation) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (failed, _) {
            if (!identical(_ad, failed)) return;
            if (mounted) setState(() { _ad = null; _loaded = false; });
            unawaited(failed.dispose());
            _scheduleRetry(width);
          },
        ),
      );
      _ad = ad;
      await ad.load();
    } catch (_) {
      if (!mounted || generation != _generation) return;
      final failed = _ad;
      _ad = null;
      if (failed != null) await failed.dispose();
      _scheduleRetry(width);
    }
  }

  void _scheduleRetry(int width) {
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 15), () {
      if (mounted && _width == width) unawaited(_load(width, ++_generation));
    });
  }

  @override
  void dispose() {
    _generation++;
    _retry?.cancel();
    final ad = _ad;
    _ad = null;
    if (ad != null) unawaited(ad.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, bounds) {
    final width = bounds.maxWidth.floor();
    if (width > 0 && width != _width) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resize(width);
      });
    }
    final ad = _ad;
    if (!_loaded || ad == null || bounds.maxWidth < ad.size.width) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 4),
      child: Center(heightFactor: 1, child: SizedBox(
        width: ad.size.width.toDouble(), height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      )),
    );
  });
}
