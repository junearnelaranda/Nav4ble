import 'package:flutter_test/flutter_test.dart';
import 'package:navable/place_search.dart';

void main() {
  bool matches(String query, {String name = '', String category = ''}) =>
      placeMatchesQuery(
        query,
        name: name,
        address: 'Cebu Business Park',
        category: category,
        features: const ['Wheelchair ramp'],
      );

  test('the category matches', () {
    expect(
      matches(
        'Shopping mall',
        name: 'Elizabeth Mall',
        category: 'Shopping mall',
      ),
      isTrue,
    );
    expect(matches('coffee', name: 'Punched', category: 'Coffee shop'), isTrue);
  });

  test('every word must be found somewhere', () {
    expect(
      matches(
        'shopping mall',
        name: 'Ayala Center Cebu',
        category: 'Shopping mall',
      ),
      isTrue,
    );
    expect(
      matches('shopping mall', name: 'Bo\'s Coffee', category: 'Coffee shop'),
      isFalse,
    );
  });

  test('plurals and case are forgiven', () {
    expect(
      matches('MALLS', name: 'SM Seaside', category: 'Shopping mall'),
      isTrue,
    );
    expect(matches('cafes', name: 'COOEE', category: 'Cafe'), isTrue);
  });

  test('name, address and features still match', () {
    expect(matches('seaside', name: 'SM Seaside City Cebu'), isTrue);
    expect(matches('business park', name: 'X'), isTrue);
    expect(matches('ramp', name: 'X'), isTrue);
    expect(matches('hospital', name: 'X', category: 'Shopping mall'), isFalse);
  });

  test('an empty query matches everything', () {
    expect(matches('  ', name: 'X'), isTrue);
  });
}
