import 'package:sponty_frontend/services/backend_api.dart';

class SwipeSession {
  bool started = false;
  bool finished = false;
  bool loading = false;
  String? error;

  // Candidates we’re swiping through (shuffled, nearby places).
  final List<PlaceListItem> candidates = <PlaceListItem>[];

  // How many swipes we aim for in this “round”.
  int targetSwipeCount = 7;

  // How many cards have been swiped already (index into candidates).
  int swipeIndex = 0;

  // osmId -> liked?
  final Map<String, bool> swipesByOsmId = <String, bool>{};

  PlaceListItem? recommendation;

  void resetRound() {
    finished = false;
    loading = false;
    error = null;
    candidates.clear();
    targetSwipeCount = 7;
    swipeIndex = 0;
    swipesByOsmId.clear();
    recommendation = null;
  }
}

/// In-memory store so swipe state survives tab switches.
///
/// This intentionally does not persist across app restarts.
class SwipeSessionStore {
  SwipeSessionStore._();

  static final SwipeSessionStore instance = SwipeSessionStore._();

  SwipeSession? _session;

  SwipeSession getOrCreate() {
    return _session ??= SwipeSession();
  }

  void clear() {
    _session = null;
  }
}
