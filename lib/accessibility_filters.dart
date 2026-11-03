/// Words that count as a match for each Home map filter chip, checked
/// against a place's accessibility features (case-insensitive).
abstract final class AccessibilityFilterWords {
  // 'wheelchair accessible' (OpenStreetMap), not just 'wheelchair', so
  // "Wheelchair seating" doesn't count as a ramp.
  static const ramps = ['ramp', 'step-free', 'wheelchair accessible'];
  static const elevators = ['elevator', 'lift'];
  static const entrance = ['entrance', 'step-free'];
  static const toilet = ['toilet', 'restroom'];
  static const tactile = ['tactile', 'braille'];
  static const audio = ['audio'];
  // Google Maps also reports these two.
  static const parking = ['parking'];
  static const seating = ['seating'];
}

/// True when [features] satisfy every selected filter: each group in
/// [selected] needs at least one feature containing one of its words.
/// No selected filters matches everything.
bool matchesAccessibilityFilters(
  Iterable<String> features,
  Iterable<List<String>> selected,
) {
  final lower = features.map((f) => f.toLowerCase()).toList();
  return selected.every(
    (words) => words.any((word) => lower.any((f) => f.contains(word))),
  );
}

/// How a place fares against the selected filters.
enum FilterMatch {
  /// Has accessibility info, and it covers every selected filter.
  matches,

  /// No accessibility info yet, so nobody knows; it stays visible (red pin).
  unknown,

  /// Has accessibility info, but not what the filters ask for; hidden.
  excluded,
}

/// Filters only hide places known not to fit. A place with no accessibility
/// info yet (e.g. found on Google or OpenStreetMap only) is [FilterMatch.unknown].
FilterMatch accessibilityFilterMatch(
  Iterable<String> features,
  Iterable<List<String>> selected,
) {
  if (features.isEmpty) return FilterMatch.unknown;
  return matchesAccessibilityFilters(features, selected)
      ? FilterMatch.matches
      : FilterMatch.excluded;
}
