import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macro_lens_mobile/core/theme/app_theme.dart';

void main() {
  testWidgets('MLColors and theme smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMLTheme(),
        home: Scaffold(
          backgroundColor: MLColors.bgDeep,
          body: Text('MacroLens', style: MLTextStyles.headingSmall),
        ),
      ),
    );
    expect(find.text('MacroLens'), findsOneWidget);
  });
}
