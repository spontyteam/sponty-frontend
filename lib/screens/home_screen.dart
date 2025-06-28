import 'package:flutter/material.dart';
import '../components/search_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Replace with Google Map widget later
          Container(
            color: Colors.grey[300],
            child: const Center(
              child: Text('Map Goes Here', style: TextStyle(fontSize: 24)),
            ),
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
              child: CustomSearchBar(
                onChanged: (value) {
                  print('Search value: $value');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
