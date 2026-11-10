import 'package:flutter_test/flutter_test.dart';
import 'package:party_game_app/main.dart';

void main() {
  testWidgets('PartyGameApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PartyGameApp());
    expect(find.byType(PartyGameApp), findsOneWidget);
  });
}
