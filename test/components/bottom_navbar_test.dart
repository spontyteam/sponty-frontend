import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sponty_frontend/components/bottom_navbar.dart';

void main() {
  testWidgets('tapping nav item calls onTap with index', (
    WidgetTester tester,
  ) async {
    int? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BottomNavbar(
            currentIndex: 2,
            onTap: (i) => tapped = i,
          ),
        ),
      ),
    );

    // Labels are rendered with fontSize=0; tap the SVG icon instead.
    await tester.tap(find.byType(SvgPicture).first);
    await tester.pump();

    expect(tapped, 0);
  });
}
