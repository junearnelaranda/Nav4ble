import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/navable_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('changing theme or text size saves it on the device', () async {
    SharedPreferences.setMockInitialValues({});
    await NavAblePreferences.load();
    expect(NavAblePreferences.themeMode.value, ThemeMode.dark); // default

    NavAblePreferences.themeMode.value = ThemeMode.light;
    NavAblePreferences.textScale.value = 1.15;
    await Future<void>.delayed(Duration.zero); // let the saves finish

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
    expect(prefs.getDouble('text_scale'), 1.15);
  });

  test('the next launch restores the saved choices', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'light',
      'text_scale': 0.9,
    });
    await NavAblePreferences.load();
    expect(NavAblePreferences.themeMode.value, ThemeMode.light);
    expect(NavAblePreferences.textScale.value, 0.9);
  });

  test('a bad stored text size falls back to normal', () async {
    SharedPreferences.setMockInitialValues({'text_scale': 9.0});
    await NavAblePreferences.load();
    expect(NavAblePreferences.textScale.value, 1);
  });
}
