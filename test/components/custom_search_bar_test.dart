import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sponty_frontend/components/search_bar.dart';

void main() {
  testWidgets('CustomSearchBar calls onChanged with typed text', (
    WidgetTester tester,
  ) async {
    String? last;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSearchBar(onChanged: (value) => last = value),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ramen');
    await tester.pump();

    expect(last, 'ramen');
  });

  testWidgets('CustomSearchBar uses provided controller', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'initial');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSearchBar(controller: controller, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.text('initial'), findsOneWidget);
  });
}
