import 'package:flutter/material.dart';
import '../components/search_bar.dart';
import '../components/map_widget.dart';
import '../components/place_details_panel.dart';
import '../services/backend_api.dart';
import '../services/app_log.dart';
import '../theme/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.backendApi});

  final BackendApi backendApi;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PlacePoint? _selectedPlace;
  PlaceDetails? _selectedDetails;
  bool _isLoadingDetails = false;
  String? _detailsError;
  String _searchQuery = '';
  int _visiblePlacesCount = 0;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPlacesError(String message) {
    AppLog.d('Places', message);

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onPlaceSelected(PlacePoint place) async {
    setState(() {
      _selectedPlace = place;
      _selectedDetails = null;
      _isLoadingDetails = true;
      _detailsError = null;
    });

    try {
      final details = await widget.backendApi.fetchPlaceDetails(
        osmId: place.osmId,
      );
      if (!mounted) return;
      setState(() {
        _selectedDetails = details;
      });
    } catch (e) {
      if (!mounted) return;
      AppLog.e('Places', e);
      setState(() {
        _detailsError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedPlace = null;
      _selectedDetails = null;
      _isLoadingDetails = false;
      _detailsError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Replace with Google Map widget later
          MapWidget(
            backendApi: widget.backendApi,
            selectedPlaceId: _selectedPlace?.osmId,
            searchQuery: _searchQuery,
            onVisiblePlacesCountChanged: (count) {
              if (!mounted) return;
              setState(() {
                _visiblePlacesCount = count;
              });
            },
            onPlaceSelected: _onPlaceSelected,
            onPlaceDeselected: _clearSelection,
            onPlacesError: _showPlacesError,
          ),

          // Bottom rounded white container with search bar inside
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: _selectedPlace == null
                  ? CustomSearchBar(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    )
                  : PlaceDetailsPanel(
                      summary: _selectedPlace!,
                      details: _selectedDetails,
                      isLoading: _isLoadingDetails,
                      error: _detailsError,
                      onClose: _clearSelection,
                    ),
            ),
          ),

          if (_selectedPlace == null && _searchQuery.trim().isNotEmpty)
            Positioned(
              right: 20,
              bottom:
                  130 +
                  MediaQuery.of(context).padding.bottom +
                  MediaQuery.of(context).viewInsets.bottom,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.highlightDarkest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_visiblePlacesCount',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.neutralLightLightest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
