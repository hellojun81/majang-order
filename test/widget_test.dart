import 'package:flutter_test/flutter_test.dart';
import 'package:majang_order/main.dart';

void main() {
  testWidgets('역할별 데모 로그인을 표시한다', (tester) async {
    await tester.pumpWidget(const MajangOrderApp());

    expect(find.text('마장오더'), findsOneWidget);
    expect(find.text('소매점 데모로 로그인'), findsOneWidget);
    expect(find.text('도매점 관리자 데모'), findsOneWidget);
  });
}
