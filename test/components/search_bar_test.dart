import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponty_frontend/components/search_bar.dart';

void main() {
  testWidgets('CustomSearchBar shows icon and responds to input', (WidgetTester tester) async {
    String? inputValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSearchBar(
            onChanged: (val) {
              inputValue = val;
            },
          ),
        ),
      ),
    );

    // Check that the search icon is rendered
    expect(find.byType(Image), findsOneWidget);

    // Check that the hint text is shown
    expect(find.text('Search'), findsOneWidget);

    // Enter text into the field
    await tester.enterText(find.byType(TextField), 'Pizza');
    await tester.pump(); // Let the widget rebuild

    expect(inputValue, 'Pizza');
  });
}
