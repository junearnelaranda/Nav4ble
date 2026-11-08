import 'package:flutter_test/flutter_test.dart';
import 'package:navable/points/celebration_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('first run never celebrates', () {
    expect(levelToCelebrate(lastCelebrated: null, currentLevel: 3), isNull);
  });

  test('celebrates a higher level once', () {
    expect(levelToCelebrate(lastCelebrated: 2, currentLevel: 3), 3);
  });

  test('same or lower level does not celebrate', () {
    expect(levelToCelebrate(lastCelebrated: 3, currentLevel: 3), isNull);
    expect(levelToCelebrate(lastCelebrated: 4, currentLevel: 3), isNull);
  });

  test('store is per account', () async {
    SharedPreferences.setMockInitialValues({});
    await CelebrationStore.setLastCelebrated('a', 2);
    expect(await CelebrationStore.lastCelebrated('a'), 2);
    expect(await CelebrationStore.lastCelebrated('b'), isNull);
  });
}
