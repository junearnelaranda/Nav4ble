import 'package:flutter_test/flutter_test.dart';
import 'package:navable/utils/initials.dart';

void main() {
  test('first and last name give two letters', () {
    expect(initialsOf('June Arnel Aranda'), 'JA');
    expect(initialsOf('  maria   reyes '), 'MR');
  });

  test('one word gives its first two letters', () {
    expect(initialsOf('Maria'), 'MA');
    expect(initialsOf('J'), 'J');
  });

  test('no name gives the fallback', () {
    expect(initialsOf('   '), '');
    expect(initialsOf('', fallback: 'NA'), 'NA');
  });
}
