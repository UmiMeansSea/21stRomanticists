// Basic smoke test — verifies the app widget tree builds without errors.
import 'package:flutter_test/flutter_test.dart';
import 'package:romanticists_app/main.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const RomanticistsApp());
    // If we reach here the widget tree built successfully.
    expect(find.byType(RomanticistsApp), findsOneWidget);
  });
}
