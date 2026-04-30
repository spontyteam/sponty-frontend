import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';

import '../services/backend_api.dart';
import '../services/swipe_session_store.dart';
import '../theme/colors.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key, required this.backendApi});

  final BackendApi backendApi;

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  static bool get _isWidgetTest {
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding') ||
        bindingType.contains('AutomatedTestWidgetsFlutterBinding');
  }

  static const double _defaultLat = -33.8688;
  static const double _defaultLon = 151.2093;
  static const int _defaultRadiusMeters = 4000;

  static const int _minSwipes = 5;
  static const int _initialTargetSwipes = 7;
  static const int _maxInitialCandidates = 10;

  late final SwipeSession _session;

  @override
  void initState() {
    super.initState();

    _session = SwipeSessionStore.instance.getOrCreate();
    if (_session.targetSwipeCount < _initialTargetSwipes) {
      _session.targetSwipeCount = _initialTargetSwipes;
    }
  }

  Future<Position?> _getCurrentPositionOrNull() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 3),
          onTimeout: () => LocationPermission.denied,
        );
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 4),
      );
    } on MissingPluginException {
      // Widget tests / unsupported platforms.
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _startSwiping() async {
    if (_session.started && !_session.finished) return;

    setState(() {
      _session.started = true;
      _session.finished = false;
      _session.loading = true;
      _session.error = null;
      _session.recommendation = null;
      _session.targetSwipeCount = _initialTargetSwipes;
      _session.swipeIndex = 0;
      _session.swipesByOsmId.clear();
      _session.candidates.clear();
    });

    await _loadInitialCandidates();
  }

  Future<void> _loadInitialCandidates() async {
    try {
      final pos = _isWidgetTest ? null : await _getCurrentPositionOrNull();
      final lat = pos?.latitude ?? _defaultLat;
      final lon = pos?.longitude ?? _defaultLon;

      final page = await widget.backendApi.fetchListPage(
        lat: lat,
        lon: lon,
        radiusMeters: _defaultRadiusMeters,
        page: 1,
        pageSize: 25,
        sort: SortMode.distance,
      );

      final items = List<PlaceListItem>.of(page.items);
      if (!_isWidgetTest) {
        items.shuffle(math.Random());
      }

      final unique = <String>{};
      final picked = <PlaceListItem>[];
      for (final it in items) {
        final id = it.details.osmId;
        if (id.isEmpty || unique.contains(id)) continue;
        unique.add(id);
        picked.add(it);
        if (picked.length >= _maxInitialCandidates) break;
      }

      setState(() {
        _session.candidates.addAll(picked);
        // If backend returned too few, still allow swiping what we have.
        final available = _session.candidates.length;
        _session.targetSwipeCount = available < _minSwipes
            ? available
            : math.min(_initialTargetSwipes, available);
        _session.loading = false;
      });
    } catch (e) {
      setState(() {
        _session.loading = false;
        _session.error = e.toString();
      });
    }
  }

  void _recordSwipe({required bool liked}) {
    if (_session.swipeIndex >= _session.candidates.length) return;

    final item = _session.candidates[_session.swipeIndex];
    _session.swipesByOsmId[item.details.osmId] = liked;
    _session.swipeIndex += 1;

    if (_session.swipeIndex >= _session.targetSwipeCount) {
      _finishSwiping();
      return;
    }

    setState(() {});
  }

  void _finishSwiping() {
    final recommended = _computeRecommendation();
    setState(() {
      _session.finished = true;
      _session.recommendation = recommended;
    });
  }

  PlaceListItem? _computeRecommendation() {
    if (_session.swipesByOsmId.isEmpty) return null;

    PlaceListItem? bestLiked;
    PlaceListItem? bestOverall;

    for (var i = 0; i < _session.swipeIndex && i < _session.candidates.length; i++) {
      final it = _session.candidates[i];
      final id = it.details.osmId;
      final liked = _session.swipesByOsmId[id];

      if (bestOverall == null || _isBetterCandidate(it, bestOverall)) {
        bestOverall = it;
      }

      if (liked == true) {
        if (bestLiked == null || _isBetterCandidate(it, bestLiked)) {
          bestLiked = it;
        }
      }
    }

    return bestLiked ?? bestOverall;
  }

  bool _isBetterCandidate(PlaceListItem a, PlaceListItem b) {
    final ar = a.details.rating ?? 0.0;
    final br = b.details.rating ?? 0.0;
    if (ar != br) return ar > br;
    // Tie-breaker: closer wins.
    return a.distanceMeters < b.distanceMeters;
  }

  void _continueSwiping() {
    setState(() {
      _session.finished = false;
      _session.recommendation = null;

      final remaining = _session.candidates.length - _session.swipeIndex;
      final extraNeeded = math.max(0, _minSwipes - remaining);
      // Keep it simple: extend the target up to what we have.
      final nextTarget = math.min(
        _session.candidates.length,
        math.max(_session.swipeIndex + _minSwipes + extraNeeded, _session.swipeIndex + 3),
      );

      _session.targetSwipeCount = math.min(
        _session.candidates.length,
        math.max(nextTarget, _session.swipeIndex + 1),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_session.started) {
      return _StartView(onStart: _startSwiping);
    }

    if (_session.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.highlightDarkest),
      );
    }

    if (_session.error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Could not load places',
              style: TextStyle(
                color: AppColors.neutralDarkest,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _session.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.neutralDarkLight,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(
              label: 'Try again',
              onPressed: _loadInitialCandidates,
            ),
          ],
        ),
      );
    }

    if (_session.finished) {
      return _ResultView(
        recommendation: _session.recommendation,
        onContinue: _continueSwiping,
      );
    }

    if (_session.candidates.isEmpty ||
        _session.swipeIndex >= _session.candidates.length) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No places found',
              style: TextStyle(
                color: AppColors.neutralDarkest,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            _PrimaryButton(label: 'Try again', onPressed: _loadInitialCandidates),
          ],
        ),
      );
    }

    final current = _session.candidates[_session.swipeIndex];
    final next = (_session.swipeIndex + 1 < _session.candidates.length)
        ? _session.candidates[_session.swipeIndex + 1]
        : null;

    final total = _session.targetSwipeCount;
    final done = _session.swipeIndex;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-page swipe cards.
        Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            if (next != null)
              Positioned.fill(
                child: Transform.scale(
                  scale: 0.97,
                  child: _PlaceCard(item: next, isPreview: true, fullPage: true),
                ),
              ),
            Positioned.fill(
              child: Dismissible(
                key: ValueKey('swipe_card_${current.details.osmId}'),
                direction: DismissDirection.horizontal,
                onDismissed: (direction) {
                  final liked = direction == DismissDirection.startToEnd;
                  _recordSwipe(liked: liked);
                },
                child: _PlaceCard(item: current, fullPage: true),
              ),
            ),
          ],
        ),

        // Progress overlay (non-interactive so the card can be swiped anywhere).
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Swipe ${done + 1} of $total',
                      key: const ValueKey('swipe_progress_label'),
                      style: const TextStyle(
                        color: AppColors.neutralDarkest,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Swipe right to like, left to pass.',
                      style: TextStyle(
                        color: AppColors.neutralDarkLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StartView extends StatelessWidget {
  const _StartView({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Start swiping',
            style: TextStyle(
              color: AppColors.neutralDarkest,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'We’ll show nearby spots with different cuisines.\nLike what you want, pass what you don’t.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.neutralDarkLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            key: const ValueKey('start_swiping_button'),
            label: 'Start swiping',
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.recommendation, required this.onContinue});

  final PlaceListItem? recommendation;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended',
            style: TextStyle(
              color: AppColors.neutralDarkest,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          if (recommendation == null)
            const Text(
              'No recommendation yet — try swiping a bit more.',
              style: TextStyle(
                color: AppColors.neutralDarkLight,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            _PlaceCard(item: recommendation!),
          const Spacer(),
          _PrimaryButton(
            key: const ValueKey('continue_swiping_button'),
            label: 'Continue swiping',
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.highlightDarkest,
          foregroundColor: AppColors.neutralLightLightest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.item, this.isPreview = false, this.fullPage = false});

  final PlaceListItem item;
  final bool isPreview;
  final bool fullPage;

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  static String _priceLabel(int? level) {
    if (level == null || level <= 0) return '—';
    final clamped = level.clamp(1, 4);
    return r'$' * clamped;
  }

  @override
  Widget build(BuildContext context) {
    final details = item.details;
    final rating = details.rating;
    final subtitle = <String>[
      if (details.address != null && details.address!.trim().isNotEmpty)
        details.address!.split(',').first.trim(),
      _formatDistance(item.distanceMeters),
      'Price ${_priceLabel(details.priceLevel)}',
    ].join(' • ');

    if (fullPage) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isPreview ? 0.85 : 1,
        child: Container(
          color: AppColors.neutralLightLightest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PlaceImage(url: _effectivePlaceImageUrl(details)),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      details.name,
                      key: ValueKey('swipe_place_name_${details.osmId}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neutralDarkest,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 18,
                          color: AppColors.highlightDarkest,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rating == null ? '—' : rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppColors.neutralDarkLight,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neutralDarkLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isPreview ? 0.85 : 1,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.neutralLightLightest,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              details.name,
              key: ValueKey('swipe_place_name_${details.osmId}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.neutralDarkest,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, size: 18, color: AppColors.highlightDarkest),
                const SizedBox(width: 6),
                Text(
                  rating == null ? '—' : rating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppColors.neutralDarkLight,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.neutralDarkLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _effectivePlaceImageUrl(PlaceDetails details) {
  final url = details.imageUrl;
  if (url == null) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  // Backend currently provides a placeholder svg when no image exists.
  // Treat that as “no image” for the swipe UI.
  final lower = trimmed.toLowerCase();
  if (lower.contains('place-placeholder.svg')) return null;

  return trimmed;
}

class _PlaceImage extends StatelessWidget {
  const _PlaceImage({required this.url});

  final String? url;

  bool get _isSvg {
    final u = url;
    if (u == null) return false;
    return u.toLowerCase().contains('.svg');
  }

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null) {
      return Container(
        color: AppColors.neutralLightMedium,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          size: 62,
          color: AppColors.neutralDarkLightest,
        ),
      );
    }

    if (_isSvg) {
      return SvgPicture.network(
        u,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => Container(color: AppColors.neutralLightMedium),
      );
    }

    return Image.network(
      u,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: AppColors.neutralLightMedium,
          alignment: Alignment.center,
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 62,
            color: AppColors.neutralDarkLightest,
          ),
        );
      },
    );
  }
}
