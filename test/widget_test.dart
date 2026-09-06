import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/app.dart';

void main() {
  testWidgets('CadenceApp boots and renders circadian dashboard with navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CadenceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify App Bar
    expect(find.text('Cadence'), findsOneWidget);

    // Verify Navigation destinations
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Movement'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Planner'), findsOneWidget);

    // Verify Circadian preview controls are present
    expect(find.text('Preview Circadian Shifts (Color.lerp)'), findsOneWidget);
    expect(find.text('Day (12:00)'), findsOneWidget);
    expect(find.text('Dusk (20:00)'), findsOneWidget);
    expect(find.text('Night (23:00)'), findsOneWidget);

    // Tap Dusk preview chip
    await tester.tap(find.text('Dusk (20:00)'));
    await tester.pumpAndSettle();

    // Verify transition to Dusk phase
    expect(find.text('Warm Dusk Transition'), findsOneWidget);
  });
}
