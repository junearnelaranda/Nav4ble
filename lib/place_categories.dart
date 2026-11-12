import 'package:flutter/material.dart';

/// A kind of place people search for by type ("mall", "hospital"), with the
/// OpenStreetMap tag that finds every such place and the icon its map pin
/// shows.
class PlaceCategory {
  const PlaceCategory({
    required this.key,
    required this.label,
    required this.osmTag,
    required this.icon,
    required this.aliases,
  });

  final String key;

  /// Shown on results ("Shopping mall").
  final String label;

  /// OpenStreetMap tag as key=value ("shop=mall").
  final String osmTag;
  final IconData icon;

  /// Search words that mean this category (singular forms; plurals match too).
  final List<String> aliases;
}

const placeCategories = [
  PlaceCategory(
    key: 'mall',
    label: 'Shopping mall',
    osmTag: 'shop=mall',
    icon: Icons.local_mall_rounded,
    aliases: ['mall', 'shopping mall', 'shopping center', 'shopping centre'],
  ),
  PlaceCategory(
    key: 'cafe',
    label: 'Cafe',
    osmTag: 'amenity=cafe',
    icon: Icons.local_cafe_rounded,
    aliases: ['cafe', 'coffee', 'coffee shop'],
  ),
  PlaceCategory(
    key: 'restaurant',
    label: 'Restaurant',
    osmTag: 'amenity=restaurant',
    icon: Icons.restaurant_rounded,
    aliases: ['restaurant', 'food', 'eatery'],
  ),
  PlaceCategory(
    key: 'hospital',
    label: 'Hospital',
    osmTag: 'amenity=hospital',
    icon: Icons.local_hospital_rounded,
    aliases: ['hospital'],
  ),
  PlaceCategory(
    key: 'clinic',
    label: 'Clinic',
    osmTag: 'amenity=clinic',
    icon: Icons.medical_services_rounded,
    aliases: ['clinic'],
  ),
  PlaceCategory(
    key: 'pharmacy',
    label: 'Pharmacy',
    osmTag: 'amenity=pharmacy',
    icon: Icons.local_pharmacy_rounded,
    aliases: ['pharmacy', 'pharmacie', 'drugstore', 'drug store'],
  ),
  PlaceCategory(
    key: 'bank',
    label: 'Bank',
    osmTag: 'amenity=bank',
    icon: Icons.account_balance_rounded,
    aliases: ['bank'],
  ),
  PlaceCategory(
    key: 'school',
    label: 'School',
    osmTag: 'amenity=school',
    icon: Icons.school_rounded,
    aliases: ['school'],
  ),
  PlaceCategory(
    key: 'university',
    label: 'University',
    osmTag: 'amenity=university',
    icon: Icons.school_rounded,
    aliases: ['university', 'universitie', 'college'],
  ),
  PlaceCategory(
    key: 'hotel',
    label: 'Hotel',
    osmTag: 'tourism=hotel',
    icon: Icons.hotel_rounded,
    aliases: ['hotel'],
  ),
  PlaceCategory(
    key: 'church',
    label: 'Church',
    osmTag: 'amenity=place_of_worship',
    icon: Icons.church_rounded,
    aliases: ['church', 'churche'],
  ),
  PlaceCategory(
    key: 'supermarket',
    label: 'Supermarket',
    osmTag: 'shop=supermarket',
    icon: Icons.local_grocery_store_rounded,
    aliases: ['supermarket', 'grocery'],
  ),
  PlaceCategory(
    key: 'bus_station',
    label: 'Bus terminal',
    osmTag: 'amenity=bus_station',
    icon: Icons.directions_bus_rounded,
    aliases: ['terminal', 'bus terminal', 'bus station'],
  ),
  PlaceCategory(
    key: 'park',
    label: 'Park',
    osmTag: 'leisure=park',
    icon: Icons.park_rounded,
    aliases: ['park'],
  ),
];

String _normalize(String text) => text
    .toLowerCase()
    .replaceAll('é', 'e')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

/// The category a search means when it is only a type of place ("malls",
/// "coffee shop"); null for anything else, such as a place's name.
PlaceCategory? categoryForQuery(String query) {
  final text = _normalize(query);
  if (text.isEmpty) return null;
  final singular = text.endsWith('s')
      ? text.substring(0, text.length - 1)
      : text;
  for (final category in placeCategories) {
    if (category.aliases.contains(text) ||
        category.aliases.contains(singular)) {
      return category;
    }
  }
  return null;
}

/// Pin icon for a category text ("Shopping mall", "Coffee shop"); null when
/// none fits, so the pin stays plain.
IconData? iconForCategory(String? text) {
  if (text == null) return null;
  final normalized = _normalize(text);
  if (normalized.isEmpty) return null;
  for (final category in placeCategories) {
    for (final word in [
      category.key.replaceAll('_', ' '),
      ...category.aliases,
    ]) {
      if (normalized.contains(word)) return category.icon;
    }
  }
  return null;
}
