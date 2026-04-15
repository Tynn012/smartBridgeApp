// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:smartbridgeapp/main.dart';

void main() {
  testWidgets('App loads core translator screens', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('SmartBridge'), findsOneWidget);
    expect(find.text('Sign Recognition'), findsOneWidget);
    expect(find.text('Speech to Text'), findsOneWidget);
    expect(find.text('Text to Speech'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Settings tab is reachable', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Clear History'), findsOneWidget);
    expect(find.text('App Permission Settings'), findsOneWidget);
  });
}
