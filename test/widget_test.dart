import 'package:flutter_test/flutter_test.dart';
import 'package:moja_aplikacja/main.dart';

void main() {
  testWidgets('shows the app start screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(StartPage), findsOneWidget);
  });
}
