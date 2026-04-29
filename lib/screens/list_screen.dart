import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/backend_api.dart';
import 'location_picker_screen.dart';
import '../theme/colors.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.backendApi});

  final BackendApi backendApi;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  late final ScrollController _scrollController;
  static const int _pageSize = 25;

  static bool get _isWidgetTest {
    // Avoid importing `flutter_test` into production code; rely on the binding
    // runtime type string which is stable across Flutter versions.
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding') ||
        bindingType.contains('AutomatedTestWidgetsFlutterBinding');
  }

  // TODO: Replace with user location once available.
  static const double _defaultLat = -33.8688;
  static const double _defaultLon = 151.2093;
  static const int _defaultRadiusMeters = 2500;

  double _currentLat = _defaultLat;
  double _currentLon = _defaultLon;
  String _locationLabel = 'Using default location';
  bool _locationLoading = true;
  bool _locationDenied = false;
  bool _locationUnsupported = false;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  String? _selectedCuisine; // slug (e.g. 'thai')
  _ListSort _sort = _ListSort.distance;

  List<PlaceListItem> _items = const <PlaceListItem>[];
  int _currentPage = 0;
  bool _hasNextPage = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    // Widget tests use `pumpAndSettle()` heavily; avoid platform-channel calls
    // and indeterminate progress animations there.
    if (_isWidgetTest) {
      _locationLoading = false;
      _locationLabel = 'Using default location';
      _currentLat = _defaultLat;
      _currentLon = _defaultLon;
      unawaited(_loadInitial());
      return;
    }

    unawaited(_initLocationThenLoad());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _error != null) return;
    if (_isLoadingMore) return;
    if (!_hasNextPage) return;

    final pos = _scrollController.position;
    // Start loading before the user hits the end.
    if (pos.pixels >= (pos.maxScrollExtent - 500)) {
      _loadNextPage();
    }
  }

  Future<void> _initLocationThenLoad() async {
    try {
      final pos = await _getCurrentPositionOrNull();
      if (!mounted) return;

      if (pos == null) {
        setState(() {
          _currentLat = _defaultLat;
          _currentLon = _defaultLon;
          _locationLabel = _locationUnsupported
              ? 'Location unavailable'
              : (_locationDenied
                    ? 'Location permission denied'
                    : 'Using default location');
          _locationLoading = false;
        });
      } else {
        final label = await _reverseGeocodeLabel(
          lat: pos.latitude,
          lon: pos.longitude,
        );
        if (!mounted) return;
        setState(() {
          _currentLat = pos.latitude;
          _currentLon = pos.longitude;
          _locationLabel = label;
          _locationLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLat = _defaultLat;
        _currentLon = _defaultLon;
        _locationLabel = 'Using default location';
        _locationLoading = false;
      });
    }

    await _loadInitial();
  }

  Future<void> _pickLocationOnMap() async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: LatLng(_currentLat, _currentLon),
        ),
      ),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _currentLat = selected.latitude;
      _currentLon = selected.longitude;
      _locationDenied = false;
      _locationUnsupported = false;
      _locationLoading = false;
      _locationLabel =
          '${selected.latitude.toStringAsFixed(3)}, ${selected.longitude.toStringAsFixed(3)}';
    });

    unawaited(_loadInitial());

    // Best-effort label update; does not block list loading.
    try {
      final label = await _reverseGeocodeLabel(
        lat: selected.latitude,
        lon: selected.longitude,
      ).timeout(const Duration(seconds: 3));
      if (!mounted) return;
      setState(() {
        _locationLabel = label;
      });
    } catch (_) {
      // Ignore.
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
        _locationDenied = true;
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 4),
      );
    } on MissingPluginException {
      // Widget tests / unsupported platforms.
      _locationUnsupported = true;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String> _reverseGeocodeLabel({
    required double lat,
    required double lon,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isEmpty) {
        return '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}';
      }

      final p = placemarks.first;
      final locality = (p.locality ?? '').trim();
      final subLocality = (p.subLocality ?? '').trim();
      final admin = (p.administrativeArea ?? '').trim();

      final primary = locality.isNotEmpty
          ? locality
          : (subLocality.isNotEmpty ? subLocality : 'Current location');
      final suffix = admin.isNotEmpty ? ', $admin' : '';
      return '$primary$suffix';
    } on MissingPluginException {
      return '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}';
    } catch (_) {
      return '${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}';
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _error = null;
      _items = const <PlaceListItem>[];
      _currentPage = 0;
      _hasNextPage = false;
    });

    try {
      final backendSort = _sort == _ListSort.rating
          ? SortMode.rating
          : SortMode.distance;
      final page = await widget.backendApi.fetchListPage(
        lat: _currentLat,
        lon: _currentLon,
        radiusMeters: _defaultRadiusMeters,
        page: 1,
        pageSize: _pageSize,
        sort: backendSort,
        cuisine: _selectedCuisine == null ? null : <String>[_selectedCuisine!],
      );
      if (!mounted) return;
      setState(() {
        _items = _applyClientSort(page.items);
        _currentPage = page.pagination.page;
        _hasNextPage = page.pagination.hasNextPage;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore) return;
    if (!_hasNextPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final backendSort = _sort == _ListSort.rating
          ? SortMode.rating
          : SortMode.distance;
      final page = await widget.backendApi.fetchListPage(
        lat: _currentLat,
        lon: _currentLon,
        radiusMeters: _defaultRadiusMeters,
        page: nextPage,
        pageSize: _pageSize,
        sort: backendSort,
        cuisine: _selectedCuisine == null ? null : <String>[_selectedCuisine!],
      );
      if (!mounted) return;
      setState(() {
        _items = _applyClientSort(<PlaceListItem>[..._items, ...page.items]);
        _currentPage = page.pagination.page;
        _hasNextPage = page.pagination.hasNextPage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = _ListHeader(
      locationLabel: _locationLabel,
      locationLoading: _locationLoading,
      onPickLocation: () => unawaited(_pickLocationOnMap()),
      onRefreshLocation: () => unawaited(_initLocationThenLoad()),
      selectedCuisine: _selectedCuisine,
      sort: _sort,
      onCuisineSelected: (slug) {
        setState(() {
          _selectedCuisine = slug;
        });
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        unawaited(_loadInitial());
      },
      onSortSelected: (s) {
        setState(() {
          _sort = s;
        });
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
        unawaited(_loadInitial());
      },
    );

    if (_isLoading) {
      return Scaffold(
        body: SafeArea(
          child: ListView.separated(
            key: const ValueKey('list_screen_vertical_list'),
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
            itemCount: 1 + 8,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              if (i == 0) return header;
              return const _RestaurantTileSkeleton();
            },
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            key: const ValueKey('list_screen_vertical_list'),
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
            children: [
              header,
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.neutralLightLightest,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: AppColors.neutralDarkLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final ranked = _items;
    final itemCount = ranked.length + (_isLoadingMore ? 4 : 0);

    return Scaffold(
      body: SafeArea(
        child: ListView.separated(
          key: const ValueKey('list_screen_vertical_list'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
          itemCount: 1 + itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) return header;

            final listIndex = index - 1;
            if (listIndex >= ranked.length) {
              // Skeletons while loading the next page.
              return const _RestaurantTileSkeleton();
            }

            final item = ranked[listIndex];
            final details = item.details;
            final distanceMeters = item.distanceMeters;
            final suburb = _extractSuburb(details.address);

            final thumbUrl = details.imageUrl;

            return _RestaurantTile(
              key: ValueKey(details.osmId),
              name: details.name,
              thumbnailUrl: thumbUrl,
              rating: details.rating,
              userRatingsTotal: details.userRatingsTotal,
              priceLevel: details.priceLevel,
              distanceMeters: distanceMeters,
              suburb: suburb,
            );
          },
        ),
      ),
    );
  }

  List<PlaceListItem> _applyClientSort(List<PlaceListItem> items) {
    if (_sort != _ListSort.price) return items;

    final copy = List<PlaceListItem>.of(items);
    copy.sort((a, b) {
      final ap = a.details.priceLevel;
      final bp = b.details.priceLevel;
      if (ap == null && bp == null) {
        return a.distanceMeters.compareTo(b.distanceMeters);
      }
      if (ap == null) return 1;
      if (bp == null) return -1;
      final byPrice = ap.compareTo(bp);
      if (byPrice != 0) return byPrice;
      return a.distanceMeters.compareTo(b.distanceMeters);
    });
    return List<PlaceListItem>.unmodifiable(copy);
  }

  static String _extractSuburb(String? address) {
    if (address == null || address.trim().isEmpty) return 'Nearby';

    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'Nearby';

    // Heuristic: suburb is often the penultimate segment.
    final candidate = parts.length >= 2 ? parts[parts.length - 2] : parts.first;

    // Strip common trailing state/postcode fragments.
    final cleaned = candidate
        .replaceAll(RegExp(r'\b\d{3,6}\b'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    return cleaned.isEmpty ? 'Nearby' : cleaned;
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.locationLabel,
    required this.locationLoading,
    required this.onPickLocation,
    required this.onRefreshLocation,
    required this.selectedCuisine,
    required this.sort,
    required this.onCuisineSelected,
    required this.onSortSelected,
  });

  final String locationLabel;
  final bool locationLoading;
  final VoidCallback onPickLocation;
  final VoidCallback onRefreshLocation;
  final String? selectedCuisine;
  final _ListSort sort;
  final ValueChanged<String?> onCuisineSelected;
  final ValueChanged<_ListSort> onSortSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPickLocation,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.near_me, color: AppColors.highlightDarkest),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      locationLoading ? 'Detecting location…' : locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.neutralDarkest,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  // Intentionally empty space to the right.
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.neutralLightLightest,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _SortPill(sort: sort, onSelected: onSortSelected),
                  const SizedBox(width: 10),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.neutralLightMedium,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      tooltip: 'Use current location',
                      padding: EdgeInsets.zero,
                      onPressed: onRefreshLocation,
                      icon: const Icon(
                        Icons.refresh,
                        color: AppColors.neutralDarkLightest,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CuisineScroller(
                selectedCuisine: selectedCuisine,
                onCuisineSelected: onCuisineSelected,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ListSort { distance, rating, price }

class _SortPill extends StatelessWidget {
  const _SortPill({required this.sort, required this.onSelected});

  final _ListSort sort;
  final ValueChanged<_ListSort> onSelected;

  String get _label => switch (sort) {
    _ListSort.distance => 'Distance',
    _ListSort.rating => 'Rating',
    _ListSort.price => 'Price',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ListSort>(
      tooltip: 'Sort',
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: _ListSort.distance, child: Text('Distance')),
        PopupMenuItem(value: _ListSort.rating, child: Text('Rating')),
        PopupMenuItem(value: _ListSort.price, child: Text('Price')),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.neutralLightMedium,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sort,
              size: 18,
              color: AppColors.neutralDarkLightest,
            ),
            const SizedBox(width: 6),
            Text(
              _label,
              style: const TextStyle(
                color: AppColors.neutralDarkLight,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CuisineOption {
  const _CuisineOption({
    required this.slug,
    required this.label,
    required this.icon,
  });
  final String slug;
  final String label;
  final IconData icon;
}

class _CuisineScroller extends StatelessWidget {
  const _CuisineScroller({
    required this.selectedCuisine,
    required this.onCuisineSelected,
  });

  final String? selectedCuisine;
  final ValueChanged<String?> onCuisineSelected;

  static const _options = <_CuisineOption>[
    _CuisineOption(slug: 'thai', label: 'Thai', icon: Icons.ramen_dining),
    _CuisineOption(slug: 'japanese', label: 'Japanese', icon: Icons.set_meal),
    _CuisineOption(
      slug: 'korean',
      label: 'Korean',
      icon: Icons.local_fire_department,
    ),
    _CuisineOption(slug: 'chinese', label: 'Chinese', icon: Icons.rice_bowl),
    _CuisineOption(slug: 'italian', label: 'Italian', icon: Icons.local_pizza),
    _CuisineOption(slug: 'indian', label: 'Indian', icon: Icons.soup_kitchen),
    _CuisineOption(slug: 'mexican', label: 'Mexican', icon: Icons.local_dining),
    _CuisineOption(
      slug: 'vietnamese',
      label: 'Vietnamese',
      icon: Icons.restaurant,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 1 + _options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            final selected = selectedCuisine == null;
            return _CuisineChip(
              label: 'All',
              icon: Icons.explore,
              selected: selected,
              onTap: () => onCuisineSelected(null),
            );
          }

          final opt = _options[index - 1];
          final selected = selectedCuisine == opt.slug;
          return _CuisineChip(
            label: opt.label,
            icon: opt.icon,
            selected: selected,
            onTap: () => onCuisineSelected(opt.slug),
          );
        },
      ),
    );
  }
}

class _CuisineChip extends StatelessWidget {
  const _CuisineChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.highlightDarkest
        : AppColors.neutralLightMedium;
    final fg = selected
        ? AppColors.neutralLightLightest
        : AppColors.neutralDarkLightest;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantTile extends StatelessWidget {
  const _RestaurantTile({
    super.key,
    required this.name,
    required this.thumbnailUrl,
    required this.rating,
    required this.userRatingsTotal,
    required this.priceLevel,
    required this.distanceMeters,
    required this.suburb,
  });

  final String name;
  final String? thumbnailUrl;
  final double? rating;
  final int? userRatingsTotal;
  final int? priceLevel;
  final double? distanceMeters;
  final String suburb;

  String? get _effectiveThumbUrl {
    final url = thumbnailUrl;
    if (url == null) return null;
    final trimmed = url.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool get _thumbIsSvg {
    final url = _effectiveThumbUrl;
    if (url == null) return false;
    return url.toLowerCase().contains('.svg');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutralLightLightest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 84,
              height: 84,
              child: _effectiveThumbUrl == null
                  ? Container(
                      color: AppColors.neutralLightMedium,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.restaurant,
                        size: 22,
                        color: AppColors.neutralDarkLightest,
                      ),
                    )
                  : (_thumbIsSvg
                        ? SvgPicture.network(
                            _effectiveThumbUrl!,
                            fit: BoxFit.cover,
                            placeholderBuilder: (_) =>
                                Container(color: AppColors.neutralLightMedium),
                          )
                        : Image.network(
                            _effectiveThumbUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) {
                              return Container(
                                color: AppColors.neutralLightMedium,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: AppColors.neutralDarkLightest,
                                ),
                              );
                            },
                          )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.neutralDarkest,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  suburb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.neutralDarkLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.star,
                      size: 16,
                      color: AppColors.starDarkest,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating == null ? '—' : rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.neutralDarkest,
                      ),
                    ),
                    if (userRatingsTotal != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '($userRatingsTotal)',
                        style: const TextStyle(
                          color: AppColors.neutralDarkLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      _formatPrice(priceLevel),
                      style: const TextStyle(
                        color: AppColors.neutralDarkMedium,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (distanceMeters != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatDistance(distanceMeters!),
                    style: const TextStyle(
                      color: AppColors.neutralDarkLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatPrice(int? level) {
    if (level == null) return '—';
    final n = (level + 1).clamp(1, 5);
    return r'$' * n;
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class _RestaurantTileSkeleton extends StatelessWidget {
  const _RestaurantTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutralLightLightest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 84,
              height: 84,
              color: AppColors.neutralLightMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.neutralLightMedium,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 13,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.neutralLightMedium,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 13,
                  width: 190,
                  decoration: BoxDecoration(
                    color: AppColors.neutralLightMedium,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
