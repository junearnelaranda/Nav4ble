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

  test('filters keep places with no info yet and hide known misfits', () {
    const ramps = [AccessibilityFilterWords.ramps];
    expect(accessibilityFilterMatch(ayala, ramps), FilterMatch.matches);
    expect(accessibilityFilterMatch(const [], ramps), FilterMatch.unknown);
    expect(accessibilityFilterMatch(const [], const []), FilterMatch.unknown);
    expect(
      accessibilityFilterMatch(const ['Braille signage'], ramps),
      FilterMatch.excluded,
    );
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
