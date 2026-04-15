import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartbridgeapp/main.dart';

void main() {
  testWidgets('First launch shows onboarding and terms checkbox', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('SmartBridge Setup'), findsOneWidget);
    expect(find.text('Your communication bridge starts here'), findsOneWidget);

    await tester.tap(find.text('Skip to Terms'));
    await tester.pumpAndSettle();

    expect(find.text('Terms and Conditions'), findsOneWidget);
    expect(find.text('I agree to the Terms and Conditions'), findsOneWidget);
  });

  testWidgets('Returning users can access main pages', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_seen': true,
      'accepted_terms': true,
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.text('Swipe left or right to switch pages quickly.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.info_outline), findsWidgets);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('SmartBridge'), findsWidgets);
    expect(find.textContaining('Version:'), findsOneWidget);
  });
}
