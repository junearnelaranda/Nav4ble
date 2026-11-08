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
  /// Confirmed to have everything the filters ask for.
  matches,

  /// Not confirmed either way (often the data source simply doesn't report
  /// that feature); stays visible, after the matches.
  unknown,

  /// Confirmed to lack something the filters ask for; hidden.
  excluded,
}

/// Each selected filter is yes (a feature in [has] matches), no (nothing in
/// [has] matches but something in [lacks] does) or unknown. Any no hides the
/// place; all yes is a match; anything else is unknown. Silence is never a
/// no: Google, for example, never reports elevators or ramps.
FilterMatch filterMatch({
  required Iterable<String> has,
  Iterable<String> lacks = const [],
  required Iterable<List<String>> selected,
}) {
  final yes = has.map((f) => f.toLowerCase()).toList();
  final no = lacks.map((f) => f.toLowerCase()).toList();
  if (selected.isEmpty) {
    return yes.isEmpty ? FilterMatch.unknown : FilterMatch.matches;
  }
  bool mentions(List<String> features, List<String> words) =>
      words.any((word) => features.any((f) => f.contains(word)));
  var allYes = true;
  for (final words in selected) {
    if (mentions(yes, words)) continue;
    if (mentions(no, words)) return FilterMatch.excluded;
    allYes = false;
  }
  return allYes ? FilterMatch.matches : FilterMatch.unknown;
}
