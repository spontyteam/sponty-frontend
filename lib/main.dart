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
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.swipe, color: Colors.grey), 
              label: 'Swipe',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list, color: Colors.grey),
              label: 'List',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home, color: Colors.grey),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.message, color: Colors.grey),
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
