import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navable/place_categories.dart';

void main() {
  test('category words are recognised, singular or plural', () {
    expect(categoryForQuery('Mall')?.key, 'mall');
    expect(categoryForQuery('shopping malls')?.key, 'mall');
    expect(categoryForQuery('coffee shop')?.key, 'cafe');
    expect(categoryForQuery('bus terminal')?.key, 'bus_station');
    expect(categoryForQuery('hospitals')?.osmTag, 'amenity=hospital');
  });

  test('place names are not categories', () {
    expect(categoryForQuery('Ayala Center Cebu'), isNull);
    expect(categoryForQuery('SM Seaside mall'), isNull);
    expect(categoryForQuery(''), isNull);
  });

  test('icons follow the category text', () {
    expect(iconForCategory('Shopping mall'), Icons.local_mall_rounded);
    expect(iconForCategory('Coffee shop'), Icons.local_cafe_rounded);
    expect(iconForCategory('Taiwanese restaurant'), Icons.restaurant_rounded);
    expect(iconForCategory('hospital'), Icons.local_hospital_rounded);
    expect(iconForCategory('Something else'), isNull);
    expect(iconForCategory(null), isNull);
  });
}
