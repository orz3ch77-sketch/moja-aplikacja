import 'package:flutter_test/flutter_test.dart';
import 'package:moja_aplikacja/main.dart';

void main() {
  testWidgets('shows the app start screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(StartPage), findsOneWidget);
  });

  test('detects all img levels with numbered _o suffix as external links', () {
    expect(isExternalInternetLinkBase('img1_4_5_4_o1'), isTrue);
    expect(isExternalInternetLinkBase('img1_4_8_12_o3'), isTrue);
    expect(isExternalInternetLinkBase('img1_4_5_4'), isFalse);
    expect(isExternalInternetLinkBase('img1_4_8_1o'), isFalse);
  });

  test('removes any file extension from asset names', () {
    expect(assetBaseName('assets/img1_4_4_1_o1.webp'), 'img1_4_4_1_o1');
    expect(
      assetBaseName('assets/external_links/img1_4_4_1_o1.json'),
      'img1_4_4_1_o1',
    );
  });

  test('ignores numbered _o suffix when counting level depth', () {
    expect(levelHierarchyBaseFor('img1_4_5_1_o1'), 'img1_4_5_1');
    expect(levelHierarchyBaseFor('img1_4_5_2_o12'), 'img1_4_5_2');
    expect(levelHierarchyBaseFor('img1_4_5_2'), 'img1_4_5_2');
  });
}
