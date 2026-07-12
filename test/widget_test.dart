import 'package:flutter_test/flutter_test.dart';
import 'package:majang_order/main.dart';

void main() {
  testWidgets('상품과 관리자 탭을 표시한다', (tester) async {
    await tester.pumpWidget(const MajangOrderApp());

    expect(find.text('마장오더'), findsOneWidget);
    expect(find.text('상품'), findsOneWidget);
    expect(find.text('관리자'), findsOneWidget);
  });
}
