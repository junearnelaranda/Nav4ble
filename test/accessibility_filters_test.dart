import 'package:flutter_test/flutter_test.dart';
import 'package:navable/accessibility_filters.dart';

void main() {
  const ayala = ['Ramp', 'Elevator', 'Accessible Restroom'];

  test('no filters selected matches every place', () {
    expect(matchesAccessibilityFilters(const [], const []), isTrue);
    expect(matchesAccessibilityFilters(ayala, const []), isTrue);
  });

  test('a place matches when it has one word from each selected filter', () {
    expect(
      matchesAccessibilityFilters(ayala, const [
        AccessibilityFilterWords.ramps,
        AccessibilityFilterWords.elevators,
        AccessibilityFilterWords.toilet,
      ]),
      isTrue,
    );
  });

  test('a place missing any selected filter does not match', () {
    expect(
      matchesAccessibilityFilters(ayala, const [
        AccessibilityFilterWords.ramps,
        AccessibilityFilterWords.audio,
      ]),
      isFalse,
    );
    expect(
      matchesAccessibilityFilters(const [], const [
        AccessibilityFilterWords.ramps,
      ]),
      isFalse,
    );
  });

  test('matching ignores case and partial wording', () {
    expect(
      matchesAccessibilityFilters(
        const ['STEP-FREE ENTRANCE'],
        const [
          AccessibilityFilterWords.entrance,
          AccessibilityFilterWords.ramps,
        ],
      ),
      isTrue,
    );
    expect(
      matchesAccessibilityFilters(
        const ['Braille signage'],
        const [AccessibilityFilterWords.tactile],
      ),
      isTrue,
    );
  });

  test('a place that has the feature matches', () {
    const ramps = [AccessibilityFilterWords.ramps];
    expect(filterMatch(has: ayala, selected: ramps), FilterMatch.matches);
  });

  test('missing info is unknown, never a reason to hide', () {
    const elevators = [AccessibilityFilterWords.elevators];
    // Google lists entrance and parking but never reports elevators.
    expect(
      filterMatch(
        has: const ['Accessible entrance', 'Accessible parking'],
        selected: elevators,
      ),
      FilterMatch.unknown,
    );
    expect(
      filterMatch(has: const [], selected: elevators),
      FilterMatch.unknown,
    );
  });

  test('only an explicit "no" hides a place', () {
    expect(
      filterMatch(
        has: const ['Accessible entrance'],
        lacks: const ['Accessible restroom'],
        selected: const [AccessibilityFilterWords.toilet],
      ),
      FilterMatch.excluded,
    );
  });

  test('every selected filter must be met to match', () {
    const both = [
      AccessibilityFilterWords.ramps,
      AccessibilityFilterWords.audio,
    ];
    expect(filterMatch(has: ayala, selected: both), FilterMatch.unknown);
    expect(
      filterMatch(
        has: ayala,
        lacks: const ['Audio assistance'],
        selected: both,
      ),
      FilterMatch.excluded,
    );
  });

  test('with no filters, places with info match and the rest are unknown', () {
    expect(filterMatch(has: ayala, selected: const []), FilterMatch.matches);
    expect(filterMatch(has: const [], selected: const []), FilterMatch.unknown);
  });

  test('wheelchair seating is not a ramp', () {
    expect(
      matchesAccessibilityFilters(
        const ['Wheelchair seating'],
        const [AccessibilityFilterWords.ramps],
      ),
      isFalse,
    );
    expect(
      matchesAccessibilityFilters(
        const ['Wheelchair ramp'],
        const [AccessibilityFilterWords.ramps],
      ),
      isTrue,
    );
  });
}
