import 'package:flutter/foundation.dart';

/// Simple debug logger for the app.
///
/// Disabled by default to keep device/system logs quiet.
/// Enable with: `--dart-define=SPONTY_LOGS=true`.
class AppLog {
  static const bool _compileTimeEnabled = bool.fromEnvironment(
    'SPONTY_LOGS',
    defaultValue: false,
  );

  static bool get enabled => kDebugMode && _compileTimeEnabled;

  static void d(String tag, String message) {
    if (!enabled) return;
    debugPrint('[$tag] $message');
  }

  static void e(String tag, Object error, [StackTrace? stackTrace]) {
    if (!enabled) return;
    debugPrint('[$tag] ERROR: $error');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
