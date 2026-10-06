import 'package:flutter_test/flutter_test.dart';
import 'package:mindquest/app.dart';

void main() {
  testWidgets('App starts and shows the setup status screen', (tester) async {
    await tester.pumpWidget(const MindQuestApp());
    await tester.pumpAndSettle();

    expect(find.text('MindQuest'), findsOneWidget);
    expect(find.text('Project setup complete'), findsOneWidget);
    // No keys are passed in tests, so Supabase reports as not configured.
    expect(find.text('Supabase keys not set'), findsOneWidget);
  });
}
