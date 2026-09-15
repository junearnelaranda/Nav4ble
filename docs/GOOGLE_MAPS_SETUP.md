# Google Maps on Android

The Home screen uses Google Maps, initially centered on Cebu City. You can pan,
zoom, and tap **My location** to request foreground location access and center
on your device. Location permission is optional for browsing the map.

## 1. Create the Google Cloud project

1. Open https://console.cloud.google.com/ and create or select a project.
2. Link a billing account to the project.
3. Open **APIs & Services → Library**, search for **Maps SDK for Android**, and enable it.
4. Open **APIs & Services → Credentials → Create credentials → API key**.
5. Edit the key. Under **Application restrictions**, choose **Android apps**.
6. Add the package name `com.example.navable` and your debug certificate SHA-1.
7. Under **API restrictions**, restrict the key to **Maps SDK for Android**, then save.

To obtain the SHA-1, run in the Android Studio terminal:

```powershell
cd E:\capstone\Nav4ble\android
.\gradlew.bat signingReport
```

Use the **app** module's **debug** variant SHA1. If Java cannot be found, use
Android Studio's embedded JDK (on this computer: `E:\android studio\jbr`) as
JAVA_HOME in that terminal. A release signing certificate needs its own entry
in the key restrictions when you configure production signing.

This computer's current debug certificate SHA-1 (checked during integration):

```text
71:03:87:17:6E:50:BC:FD:B0:9A:20:EA:00:63:96:41:05:F2:63:DD
```

Regenerate the report if you replace the debug keystore or use another computer.

## 2. Add your key locally

Open `android/local.properties` in your editor. Preserve its existing SDK paths
and add a line at the end, replacing the placeholder with your key:

```properties
MAPS_API_KEY=YOUR_API_KEY
```

Do not add quotes or backticks. This is file content, not a terminal command.
`android/local.properties` is already ignored by Git. Do not commit the key.
The build also accepts the `MAPS_API_KEY` environment variable if the local
property is absent. Android application/API restrictions remain necessary
because mobile SDK keys are packaged in the APK.

## 3. Run on Android

Start an Android emulator with Google APIs/Google Play services and internet
access, or connect your Android phone. Then run:

```powershell
cd E:\capstone\Nav4ble
flutter pub get
flutter run
```

If Flutter reports that plugins require symlink support, enable **Developer
Mode** in Windows Settings (search Settings for “Developer Mode”), then rerun
`flutter pub get`. This project also contains desktop platform folders.

After changing a key or native configuration, stop the app and run it again;
hot reload does not update the Android manifest.

## 4. Verify

- Open Home and confirm that real Google map tiles load around Cebu City.
- Pan and pinch to zoom. Google's attribution should remain visible above the bottom cards.
- Enter a place or area (for example `Guadalupe Church, Cebu City`) and press
  the keyboard Search button or the magnifying glass. The map centers on the
  first matching coordinate and shows a pin. Add a city/full address to
  disambiguate names. This uses Android's native geocoder through the
  `geocoding` package; no additional Google Cloud API/key is required. Internet
  and a working device geocoding service are required; it is not Places autocomplete.
- Tap **My location**, allow location access, and confirm the map centers on the device.
- On an emulator, set a simulated location using its extended controls. Its
  default location may be outside Cebu.
- Deny permission and confirm you can still browse the map.
- Turn device location off and tap **My location** to check the recovery message.
- Long-press the map to select a destination, then drag the pin to adjust it.
- Tap **Start Navigation** and choose Walking, Driving, or Transit. Google Maps
  opens with the selected pin coordinates, or resolves the typed address if no
  matching pin exists. A changed address never reuses an old search's pin.
- With Google Maps installed and location available, walking/driving requests
  ask for live navigation. Google Maps may show a route preview when navigation
  is unavailable. Transit opens route options. Without the Google Maps app,
  the URL can open browser directions instead.
- Return to NavAble and tap **My location** to show the live location dot.
  NavAble does not request background location access.

If the map says it is not configured, check the local property and rebuild.
If the map appears but tiles stay blank, check internet access, billing, SDK
enablement, package name, and SHA-1 restrictions. Android Studio Logcat can
show Google Maps authorization errors. Do not share logs containing your key.

## Scope

This integration is for Android (minimum API 24). iOS, web, and desktop show
an availability message rather than initializing an unconfigured native map.
No background location tracking is enabled.

Navigation now opens Google Maps rather than displaying sample directions.
No Routes API or additional key is needed for this handoff. NavAble does not
draw route lines or provide its own turn-by-turn navigation. Accessibility
filters and nearby place cards remain demo features; Google Maps routes do not
apply these filters or verify step-free access. Report-form maps remain previews.

## Official documentation

- https://developers.google.com/maps/flutter-package/config
- https://developers.google.com/maps/documentation/android-sdk/get-api-key
- https://pub.dev/packages/google_maps_flutter
- https://pub.dev/packages/geolocator
- https://developers.google.com/maps/documentation/urls/get-started
- https://pub.dev/packages/url_launcher
