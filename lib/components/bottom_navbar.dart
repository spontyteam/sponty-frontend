// components/bottom_navbar.dart

import 'package:flutter/material.dart';
import 'package:sponty_frontend/theme/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavbar({required this.currentIndex, required this.onTap});

  /// Helper to return an SVG icon with correct color based on index
  Widget _buildNavIcon(String assetPath, int index) {
    return SvgPicture.asset(
      assetPath,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(
        currentIndex == index
            ? AppColors.highlightDarkest
            : AppColors.neutralLightDark,
        BlendMode.srcIn,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: onTap,
      selectedItemColor: AppColors.highlightDarkest,
      unselectedItemColor: AppColors.neutralLightDark,
      backgroundColor: AppColors.neutralLightLightest,
      selectedFontSize: 0,
      unselectedFontSize: 0,
      items: [
        BottomNavigationBarItem(
          icon: _buildNavIcon('assets/icons/swipe.svg', 0),
          label: 'Swipe',
        ),
        BottomNavigationBarItem(
          icon: _buildNavIcon('assets/icons/list.svg', 1),
          label: 'List',
        ),
        BottomNavigationBarItem(
          icon: _buildNavIcon('assets/icons/home.svg', 2),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: _buildNavIcon('assets/icons/dm.svg', 3),
          label: 'DM',
        ),
        BottomNavigationBarItem(
          icon: _buildNavIcon('assets/icons/settings.svg', 4),
          label: 'Settings',
        ),
      ],
    );
  }
}
