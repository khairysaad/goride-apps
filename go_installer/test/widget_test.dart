import 'package:flutter_test/flutter_test.dart';

import 'package:go_installer/main.dart';

void main() {
  testWidgets('InstallerApp renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const InstallerApp());
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(InstallerApp), findsOneWidget);
  });
}