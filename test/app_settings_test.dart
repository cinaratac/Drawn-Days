import 'package:drawn_days/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('favorite dates survive a settings JSON round trip', () {
    const settings = AppSettings(
      favoriteDateKeys: <String>['2026-08-21', '2026-10-19'],
    );

    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.favoriteDateKeys, <String>['2026-08-21', '2026-10-19']);
  });

  test('duplicate favorite dates are removed while loading', () {
    final restored = AppSettings.fromJson(<String, Object?>{
      'favoriteDateKeys': <String>['2026-08-21', '2026-08-21'],
    });

    expect(restored.favoriteDateKeys, <String>['2026-08-21']);
  });
}
