import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:albaraka/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Arabic home screen renders', (tester) async {
    await tester.pumpWidget(const AsmakAlbarakaApp());
    await tester.pumpAndSettle();
    expect(find.text('أسماك البركة'), findsOneWidget);
    expect(find.text('إدارة المحل'), findsOneWidget);
  });
}
