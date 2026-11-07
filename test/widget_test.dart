import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:albaraka/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Arabic home screen renders', (tester) async {
    await tester.pumpWidget(const AsmakAlbarakaApp());
    // The home screen intentionally shows an indeterminate progress indicator
    // while SQLite initializes, so pump one frame instead of waiting for settle.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('أسماك البركة'), findsOneWidget);
    expect(find.text('إدارة المحل'), findsOneWidget);
  });
}
