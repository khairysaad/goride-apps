import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/config/app_theme.dart';

void main() {
  test('theme builds', () {
    expect(AppTheme.light.brightness.toString().isEmpty, false);
  });
}