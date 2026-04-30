import 'package:flutter/material.dart';
import 'package:sponty_frontend/theme/colors.dart';
import 'package:sponty_frontend/components/bottom_navbar.dart';

import 'screens/swipe_screen.dart';
import 'screens/list_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dm_screen.dart';
import 'screens/settings_screen.dart';
import 'services/backend_api.dart';
import 'config/setup.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.backendApiOverride});

  /// Optional injection point (primarily for widget tests).
  ///
  /// When null, the app uses `SPONTY_BACKEND_BASE_URL` and a real HTTP backend.
  final BackendApi? backendApiOverride;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sponty',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        scaffoldBackgroundColor: AppColors.neutralLightLightest,
        appBarTheme: AppBarTheme(backgroundColor: AppColors.highlightDarkest),
      ),
      home: MainPage(backendApiOverride: backendApiOverride),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, this.backendApiOverride});

  final BackendApi? backendApiOverride;

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  // Default to List tab on launch.
  int _selectedIndex = 1;

  List<Widget>? _pages;

  @override
  void initState() {
    super.initState();

    final injected = widget.backendApiOverride;
    if (injected != null) {
      _pages = <Widget>[
        SwipeScreen(backendApi: injected),
        ListScreen(backendApi: injected),
        HomeScreen(backendApi: injected),
        const DmScreen(),
        const SettingsScreen(),
      ];
      return;
    }

    final baseUrl = SPONTY_BACKEND_BASE_URL.trim();
    if (baseUrl.isEmpty) {
      // No mocked fallback: app requires a real backend.
      return;
    }

    final api = HttpBackendApi(baseUrl: baseUrl);
    _pages = <Widget>[
      SwipeScreen(backendApi: api),
      ListScreen(backendApi: api),
      HomeScreen(backendApi: api),
      const DmScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (pages == null) {
      return Scaffold(
        appBar: AppBar(toolbarHeight: 5),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Backend not configured.\n\n'
              'Set SPONTY_BACKEND_BASE_URL in lib/config/setup.dart.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(toolbarHeight: 5),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavbar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
