// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_summarization/main.dart';
import 'package:ai_summarization/components/file_card.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(SummaSphereApp());

    // Verify that the banner text is displayed.
    expect(find.text("Welcome to SummaSphere!\nYour AI-powered summarization tool."), findsOneWidget);

    // Check for navigation buttons.
    expect(find.widgetWithIcon(IconButton, Icons.summarize), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.upload), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.translate), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.folder), findsOneWidget);

    // Verify that the "Recent Folders" label is displayed.
    expect(find.text("Recent Folders"), findsOneWidget);

    // Check that at least one folder card is displayed.
    expect(find.byType(FileCard), findsWidgets);
  });
}
