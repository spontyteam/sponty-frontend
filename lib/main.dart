import 'package:flutter/material.dart';
import 'package:sponty_frontend/theme/colors.dart';
import 'package:sponty_frontend/components/bottom_navbar.dart';

import 'screens/swipe_screen.dart';
import 'screens/list_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dm_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _selectedIndex = 2;

  final List<Widget> _pages = const [
    SwipeScreen(),
    ListScreen(),
    HomeScreen(),
    DmScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 5),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavbar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
