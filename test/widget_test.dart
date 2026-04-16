// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:merlen_messenger_clean/main.dart';

void main() {
  testWidgets('App shows splash screen on startup', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Merlen Messenger'), findsOneWidget);
    expect(find.text('Децентрализованный чат'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let splash timeout complete to avoid pending timer at test teardown.
    await tester.pump(const Duration(seconds: 3));
  });
}
