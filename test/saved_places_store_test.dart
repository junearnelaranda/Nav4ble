import 'package:flutter_test/flutter_test.dart';
import 'package:navable/saved_places_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const ayala = SavedPlace(
    name: 'Ayala Center Cebu',
    address: 'Cebu Business Park',
    tag: 'Work',
    locationId: 'aa0d22cc',
    latitude: 10.3181,
    longitude: 123.905,
  );

  test('a saved list reads back the same', () {
    final back = SavedPlacesStore.decode(SavedPlacesStore.encode([ayala]));
    expect(back, hasLength(1));
    expect(back.single.name, ayala.name);
    expect(back.single.address, ayala.address);
    expect(back.single.tag, 'Work');
    expect(back.single.locationId, 'aa0d22cc');
    expect(back.single.latitude, 10.3181);
  });

  test('broken or old entries do not lose the list', () {
    final back = SavedPlacesStore.decode(
      '[{"name":"Old","address":"x","tag":"Ramp"},{"address":"no name"},5]',
    );
    expect(back, hasLength(1));
    expect(back.single.tag, 'Custom'); // unknown tag falls back
    expect(SavedPlacesStore.decode('not json'), isEmpty);
    expect(SavedPlacesStore.decode(null), isEmpty);
  });

  test('each account on a device has its own list', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await SavedPlacesStore.save('user-a', [ayala]), isTrue);
    expect(await SavedPlacesStore.load('user-a'), hasLength(1));
    expect(await SavedPlacesStore.load('user-b'), isEmpty);
    expect(await SavedPlacesStore.load(null), isEmpty); // guest
  });
}
