import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:navable/services/profile_picture.dart';

void main() {
  test('a photo is stored as a small square JPEG and reads back', () {
    final photo = img.Image(width: 1200, height: 800);
    img.fill(photo, color: img.ColorRgb8(40, 160, 90));
    final stored = ProfilePicture.encodeNow(
      Uint8List.fromList(img.encodePng(photo)),
    );

    expect(stored, startsWith('data:image/jpeg;base64,'));
    expect(stored!.length, lessThan(60000)); // fits comfortably in a row
    final back = img.decodeImage(ProfilePicture.decode(stored)!)!;
    expect(back.width, ProfilePicture.size);
    expect(back.height, ProfilePicture.size);
  });

  test('not an image, or nothing stored, gives no picture', () {
    expect(ProfilePicture.encodeNow(Uint8List.fromList([1, 2, 3])), isNull);
    expect(ProfilePicture.decode(null), isNull);
    expect(ProfilePicture.decode('https://example.com/a.jpg'), isNull);
    expect(ProfilePicture.decode('data:image/jpeg;base64,@@@'), isNull);
  });
}
