import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sponty',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    Center(child: Text('Swipe', style: TextStyle(fontSize: 24))),
    Center(child: Text('List', style: TextStyle(fontSize: 24))),
    Center(child: Text('Home', style: TextStyle(fontSize: 24))),
    Center(child: Text('DM', style: TextStyle(fontSize: 24))),
    Center(child: Text('Notifications', style: TextStyle(fontSize: 24)))
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sponty'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
              icon: Image.asset('../assets/swipe.png', width: 24, height: 24), 
              label: 'Swipe',
            ),
            BottomNavigationBarItem(
              icon: Image.asset('../assets/list.png', width: 24, height: 24),
              label: 'List',
            ),
            BottomNavigationBarItem(
              icon: Image.asset('../assets/home.png', width: 24, height: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Image.asset('../assets/dm.png', width: 24, height: 24),
              label: 'DM',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications, color: Colors.grey),
              label: 'Notifications'
            ),
        ],
      ),
    );
  }
}
