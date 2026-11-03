import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as osm;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState, Supabase;

import 'services/auth_service.dart';
import 'services/google_maps_launcher.dart';
import 'login.dart';
import 'navable_design.dart';
import 'accessibility_filters.dart';
import 'locations_api.dart';
import 'places_api.dart';
import 'profile_stats_api.dart';
import 'reports_api.dart';
import 'route_planner_api.dart';
import 'welcome.dart';

part 'screens/home_tab.dart';
part 'screens/explore_tab.dart';
part 'screens/reports_tab.dart';
part 'screens/alerts_tab.dart';
part 'screens/profile_tab.dart';
part 'screens/settings_screen.dart';
part 'screens/submissions_screen.dart';
part 'screens/report_result_screens.dart';
part 'screens/bug_report_screen.dart';
part 'widgets/open_street_map_view.dart';

enum _ProfilePhotoAction { camera, gallery, remove }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.isGuest = false});

  final bool isGuest;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _authService = AuthService();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _exploreSearchController =
      TextEditingController();
  int _selectedIndex = 0;
  AccessibleLocation? _pendingPhotoLocation;
  _ReportKind? _reportKind; // null: Reports tab opens on the two choices
  GooglePlace? _pendingGooglePlace; // Google place to contribute to
  int _photoCaptureRequestId = 0;
  AccessibleLocation? _selectedMapLocation;
  List<AccessibleLocation> _accessibleLocations = const [];
  ProfileStats? _profileStats;
  bool _profileStatsLoading = true;
  bool _locationsLoading = true;
  String? _locationsError;
  bool _avoidStairs = true;
  bool _prioritizeElevators = false;
  bool _accessibleEntrance = false;
  bool _accessibleToilet = false;
  bool _tactilePaving = false;
  bool _audioAssistance = false;
  bool _accessibleParking = false;
  bool _wheelchairSeating = false;
  bool _voiceGuidance = true;
  bool _routing = false;
  PlannedRoute? _walkingRoute;
  String? _routeStatus;
  bool _destinationSelected = false;
  List<PlaceSearchResult> _placeSearchResults = const [];
  // Last search's places, kept on the map as green/red pins.
  List<PlaceSearchResult> _resultPins = const [];
  PlaceSearchResult? _searchedPlace;
  bool _placeSearching = false;
  // Suggestions while typing: debounce timer, and a counter so a slow,
  // older answer never replaces a newer one.
  Timer? _suggestTimer;
  int _suggestRequest = 0;
  osm.LatLng? _userPosition;
  bool _triedUserPosition = false;

  final List<SavedPlace> _savedPlaces = [];

  final List<AccessReport> _reports = [];

  final List<AccessibilitySubmission> _submissions = [];

  StreamSubscription<AuthState>? _authSubscription;
  bool _signingOut = false;

  DateTime _locationsLoadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAccessibleLocations();
    _loadProfileStats();
    if (!widget.isGuest) {
      // If the sign-in ends on its own (for example it expired and couldn't
      // renew while offline), go back to login instead of leaving the user
      // on signed-in screens that can no longer scan or submit.
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((state) {
            if (state.event == AuthChangeEvent.signedOut && !_signingOut) {
              _returnToLogin();
            }
          });
    }
  }

  void _returnToLogin() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => const LoginScreen()),
      (route) => false,
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Your sign-in expired. Please sign in again.'),
      ),
    );
  }

  Future<void> _loadProfileStats() async {
    try {
      final stats = await ProfileStatsApi.getCurrentUserStats();
      if (!mounted) return;
      setState(() {
        _profileStats = stats;
        _profileStatsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _profileStatsLoading = false);
    }
  }

  /// Coming back to the app picks up what admins changed meanwhile
  /// (new places, photos, features), at most once a minute.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        DateTime.now().difference(_locationsLoadedAt) >
            const Duration(minutes: 1)) {
      _loadAccessibleLocations(refresh: true);
    }
  }

  /// [refresh] reloads quietly: keeps the current list and selection if the
  /// reload fails, and doesn't jump to the first place.
  Future<void> _loadAccessibleLocations({bool refresh = false}) async {
    _locationsLoadedAt = DateTime.now();
    try {
      final locations = await LocationsApi.getAccessibleLocations();
      if (!mounted) return;
      setState(() {
        _accessibleLocations = locations;
        if (!refresh) {
          _selectedMapLocation = locations.isEmpty ? null : locations.first;
        } else if (_selectedMapLocation case final selected?) {
          // Same place, with its updated photo and features.
          _selectedMapLocation = locations
              .where((l) => l.id == selected.id)
              .firstOrNull;
        }
        _locationsLoading = false;
        _locationsError = null;
      });
    } on LocationsApiException catch (error) {
      if (!mounted || refresh) return;
      setState(() {
        _locationsLoading = false;
        _locationsError = error.message;
      });
    } catch (_) {
      if (!mounted || refresh) return;
      setState(() {
        _locationsLoading = false;
        _locationsError = 'Could not load accessible locations from Supabase.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _suggestTimer?.cancel();
    _destinationController.dispose();
    _exploreSearchController.dispose();
    super.dispose();
  }

  void _startPhotoSubmission({
    AccessibleLocation? location,
    bool openCamera = false,
  }) {
    if (widget.isGuest) {
      _showMessage('Sign in to submit accessibility photos.');
      return;
    }
    setState(() {
      _reportKind = _ReportKind.feature;
      _pendingGooglePlace = null;
      _pendingPhotoLocation = location;
      if (location != null) _selectedMapLocation = location;
      if (openCamera) _photoCaptureRequestId++;
      _selectedIndex = 2;
    });
  }

  /// "Add accessibility info" on a Google place from Explore. A place NavAble
  /// already has is contributed to directly; a new one becomes a suggestion.
  void _contributeToGooglePlace(GooglePlace place, AccessibleLocation? linked) {
    if (linked != null) {
      _startPhotoSubmission(location: linked);
      return;
    }
    if (widget.isGuest) {
      _showMessage('Sign in to add accessibility information.');
      return;
    }
    setState(() {
      _reportKind = _ReportKind.feature;
      _pendingPhotoLocation = null;
      _pendingGooglePlace = place;
      _selectedIndex = 2;
    });
  }

  void _openReportsTab() {
    if (widget.isGuest) {
      _showMessage('Sign in to view and submit reports.');
      return;
    }
    setState(() {
      _reportKind = _ReportKind.issue;
      _selectedIndex = 2;
    });
  }

  void _selectMapLocation(AccessibleLocation location) {
    setState(() {
      _selectedMapLocation = location;
      _destinationController.text = location.name;
      _destinationSelected = true;
      _searchedPlace = null;
      _walkingRoute = null;
      _routeStatus = null;
    });
  }

  void _onDestinationChanged(String value) {
    final text = value.trim();
    if (text.isEmpty && _resultPins.isNotEmpty) {
      setState(() => _resultPins = const []);
    }
    if (_destinationSelected) {
      final selectedName = _searchedPlace?.name ?? _selectedMapLocation?.name;
      if (text == selectedName) return;
      setState(() {
        _destinationSelected = false;
        _searchedPlace = null;
        _placeSearchResults = const [];
        _walkingRoute = null;
        _routeStatus = null;
      });
    }
    // Suggest places as the user types, once they pause briefly.
    _suggestTimer?.cancel();
    _suggestRequest++;
    if (text.replaceAll(_nearMePattern, ' ').trim().length < 2) {
      if (_placeSearchResults.isNotEmpty && !_placeSearching) {
        setState(() => _placeSearchResults = const []);
      }
      return;
    }
    _suggestTimer = Timer(
      const Duration(milliseconds: 350),
      () => _suggestPlaces(text),
    );
  }

  /// Hides the suggestion list and the keyboard; result pins stay.
  void _dismissSuggestions() {
    _suggestTimer?.cancel();
    _suggestRequest++; // a suggestion still loading won't reopen the list
    FocusManager.instance.primaryFocus?.unfocus();
    if (_placeSearchResults.isNotEmpty && !_placeSearching) {
      setState(() => _placeSearchResults = const []);
    }
  }

  /// Tapping the search bar again brings back suggestions for its text.
  void _showSuggestionsAgain() {
    if (_placeSearchResults.isEmpty && !_placeSearching) {
      _onDestinationChanged(_destinationController.text);
    }
  }

  Future<void> _suggestPlaces(String text) async {
    final request = ++_suggestRequest;
    final searchText = text.replaceAll(_nearMePattern, ' ').trim();
    if (!_triedUserPosition) {
      _triedUserPosition = true;
      _userPosition = await _currentPositionOrNull();
    }
    final center = _userPosition ?? _searchedPlace?.point ?? _cebuMapCenter;
    var places = const <PlaceSearchResult>[];
    try {
      places = await RoutePlannerApi.suggestPlaces(
        query: searchText,
        near: center,
      );
    } catch (_) {
      // Suggestions are a convenience; Enter still runs the full search.
    }
    if (!mounted ||
        request != _suggestRequest ||
        _placeSearching ||
        _destinationSelected) {
      return;
    }
    setState(() {
      _placeSearchResults = _withNavAblePlaces(
        searchText,
        places,
        center,
      ).take(8).toList();
    });
  }

  /// Puts NavAble's own places that match [searchText] first, gives map
  /// results at a NavAble place its features, sorts the rest nearest to
  /// [origin] first, and drops repeated names.
  List<PlaceSearchResult> _withNavAblePlaces(
    String searchText,
    List<PlaceSearchResult> mapResults,
    osm.LatLng origin,
  ) {
    double distance(PlaceSearchResult p) =>
        (p.point.latitude - origin.latitude).abs() +
        (p.point.longitude - origin.longitude).abs();
    final nearestFirst = [...mapResults]
      ..sort((a, b) => distance(a).compareTo(distance(b)));
    final normalizedQuery = searchText.toLowerCase();
    String? navAbleFeatures(AccessibleLocation location) =>
        location.features.isEmpty ? null : location.features.take(3).join(', ');
    final accessibleResults = _accessibleLocations
        .where(
          (location) =>
              location.name.toLowerCase().contains(normalizedQuery) ||
              location.address.toLowerCase().contains(normalizedQuery),
        )
        .map(
          (location) => PlaceSearchResult(
            name: location.name,
            displayName: location.address,
            point: osm.LatLng(location.latitude, location.longitude),
            accessibility: navAbleFeatures(location),
          ),
        );
    // A map result at a verified NavAble place takes NavAble's features.
    PlaceSearchResult withNavAbleData(PlaceSearchResult place) {
      for (final location in _accessibleLocations) {
        if ((location.latitude - place.point.latitude).abs() < 0.0003 &&
            (location.longitude - place.point.longitude).abs() < 0.0003) {
          return place.withAccessibility(
            navAbleFeatures(location) ?? place.accessibility,
          );
        }
      }
      return place;
    }

    final resultNames = <String>{};
    return [
      for (final place in [
        ...accessibleResults,
        ...nearestFirst.map(withNavAbleData),
      ])
        if (resultNames.add(place.name.toLowerCase())) place,
    ];
  }

  Future<void> _planRoute() async {
    final typedDestination = _destinationController.text.trim();
    final destination = typedDestination.isNotEmpty
        ? typedDestination
        : _selectedMapLocation?.name ?? '';
    if (destination.isEmpty) {
      setState(() {
        _routeStatus = 'Enter a destination to start routing.';
        _walkingRoute = null;
      });
      return;
    }
    if (typedDestination.isEmpty) {
      _destinationController.text = destination;
    }
    if (_routing) return;

    setState(() {
      _routing = true;
      _walkingRoute = null;
      _routeStatus = 'Finding a route to $destination…';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const RoutePlannerException(
          'Turn on location services to calculate a route from your location.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const RoutePlannerException(
          'Allow location access to calculate a route from your location.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final route = await RoutePlannerApi.planRoute(
        query: destination,
        origin: osm.LatLng(position.latitude, position.longitude),
        savedLocations: _accessibleLocations,
        // Car gives the most reliable road directions in Cebu.
        mode: TravelMode.car,
        selectedPlace: _searchedPlace,
      );
      if (!mounted) return;
      setState(() {
        _walkingRoute = route;
        _routeStatus = route.distanceLabel;
        if (route.savedLocation != null) {
          _selectedMapLocation = route.savedLocation;
        }
      });
    } on RoutePlannerException catch (error) {
      if (!mounted) return;
      setState(() {
        _walkingRoute = null;
        _routeStatus = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _walkingRoute = null;
        _routeStatus = 'Could not calculate this route: $error';
      });
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<void> _searchPlaces() async {
    final query = _destinationController.text.trim();
    if (query.isEmpty || _placeSearching) return;
    _suggestTimer?.cancel();
    _suggestRequest++; // drop suggestions still on their way
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _placeSearching = true;
      _placeSearchResults = const [];
      _routeStatus = null;
    });
    try {
      // "cafe near me": search "cafe" within about 3 km of the user.
      final nearMe = _nearMePattern.hasMatch(query);
      final searchText = query.replaceAll(_nearMePattern, ' ').trim();
      if (searchText.isEmpty) {
        _showMessage('Type what to look for, like "cafe near me".');
        return;
      }
      // Search around the user: "mall" should mean malls nearby.
      var center = await _currentPositionOrNull();
      if (!mounted) return;
      _userPosition = center ?? _userPosition;
      if (center == null && nearMe) {
        _showMessage(
          'Turn on location to search near you. Showing results near '
          'Cebu City.',
        );
      }
      center ??= _searchedPlace?.point ?? _cebuMapCenter;
      // Within ~5 km first, then ~20 km, then anywhere (for exact names
      // farther away). "near me" stops at ~5 km.
      var mapResults = const <PlaceSearchResult>[];
      for (final (reach, bounded) in [
        (0.05, true),
        if (!nearMe) ...[(0.2, true), (0.2, false)],
      ]) {
        mapResults = await RoutePlannerApi.searchPlaces(
          query: searchText,
          near: center,
          reach: reach,
          bounded: bounded,
        );
        if (mapResults.isNotEmpty) break;
      }
      if (!mounted) return;
      final results = _withNavAblePlaces(searchText, mapResults, center);
      setState(() {
        _placeSearchResults = results;
        _resultPins = results;
      });
      if (results.isEmpty) {
        _showMessage('No places found. Try a more specific search.');
      }
    } on RoutePlannerException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Could not search places. Please try again.');
    } finally {
      if (mounted) setState(() => _placeSearching = false);
    }
  }

  static final _nearMePattern = RegExp(
    r'\b(near me|nearby|around me|close to me)\b',
    caseSensitive: false,
  );

  Future<osm.LatLng?> _currentPositionOrNull() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {
        // Not available on every platform (e.g. web).
      }
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return osm.LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  void _selectSearchedPlace(PlaceSearchResult place) {
    setState(() {
      _searchedPlace = place;
      // Replace the previous pick so its coordinates can never be reused.
      // Keeps the Supabase record when the result is a NavAble location.
      _selectedMapLocation = _accessibleLocationFor(place);
      _destinationController.text = place.name;
      _placeSearchResults = const [];
      _walkingRoute = null;
      _routeStatus = null;
      _destinationSelected = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  AccessibleLocation? _accessibleLocationFor(PlaceSearchResult place) {
    const tolerance = 1e-6;
    for (final location in _accessibleLocations) {
      if ((location.latitude - place.point.latitude).abs() < tolerance &&
          (location.longitude - place.point.longitude).abs() < tolerance) {
        return location;
      }
    }
    return null;
  }

  /// The place shown on the details card: the latest search pick, or else
  /// the latest marker tap. Derived on demand so it always matches the map.
  _SelectedPlace? get _selectedPlace {
    final searched = _searchedPlace;
    if (searched != null) {
      return _SelectedPlace.fromSearch(
        searched,
        accessibleLocation: _accessibleLocationFor(searched),
      );
    }
    final location = _selectedMapLocation;
    return location == null ? null : _SelectedPlace.fromAccessible(location);
  }

  /// Reads the selection at tap time, so the card always opens the place it
  /// currently shows.
  Future<void> _openSelectedPlaceInGoogleMaps() async {
    final place = _selectedPlace;
    final opened =
        place != null &&
        await GoogleMapsLauncher.openDirections(
          latitude: place.latitude,
          longitude: place.longitude,
        );
    if (!opened && mounted) {
      _showMessage('Unable to open this location in Google Maps.');
    }
  }

  void _saveAccessibleLocation(AccessibleLocation location) {
    if (_savedPlaces.any((place) => place.name == location.name)) {
      _showMessage('${location.name} is already saved.');
      return;
    }
    setState(() {
      _savedPlaces.insert(
        0,
        SavedPlace(
          name: location.name,
          address: location.address,
          tag: location.features.firstOrNull ?? 'Accessible',
        ),
      );
    });
    _showMessage('${location.name} saved.');
  }

  void _useSavedPlace(SavedPlace place) {
    setState(() {
      _destinationController.text = place.name;
      _destinationSelected = true;
      _selectedIndex = 0;
    });
    _planRoute();
  }

  void _navigateToPlace(String placeName) {
    setState(() {
      _destinationController.text = placeName;
      _destinationSelected = true;
      _selectedIndex = 0;
    });
    _planRoute();
  }

  void _deleteSavedPlace(SavedPlace place) {
    setState(() => _savedPlaces.remove(place));
    _showMessage('${place.name} removed from saved places.');
  }

  void _openRouteDetails() {
    final route = _walkingRoute;
    if (route == null) {
      _showMessage('Plan a route first.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RouteDetailsScreen(route: route),
      ),
    );
  }

  void _openReportDetails(AccessReport report) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ReportDetailsScreen(
          report: report,
          onConfirm: () {
            final index = _reports.indexOf(report);
            if (index == -1) {
              return;
            }

            setState(() {
              _reports[index] = report.copyWith(
                confirmations: report.confirmations + 1,
              );
            });
            _showMessage('Thanks for confirming this report.');
          },
        ),
      ),
    );
  }

  void _openSavedPlaceDetails(SavedPlace place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SavedPlaceDetailsScreen(
          place: place,
          onRoute: () {
            Navigator.of(context).pop();
            _useSavedPlace(place);
          },
          onSave: (updatedPlace) {
            final index = _savedPlaces.indexOf(place);
            if (index == -1) {
              return;
            }

            setState(() => _savedPlaces[index] = updatedPlace);
            Navigator.of(context).pop();
            _showMessage('${updatedPlace.name} updated.');
          },
        ),
      ),
    );
  }

  void _openSavedPlaces() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NavAbleLightTheme(
          child: Scaffold(
            backgroundColor: const Color(0xFFF7FAF8),
            appBar: AppBar(
              title: const Text('Saved Places'),
              backgroundColor: Colors.white,
              foregroundColor: kNavAbleNavy,
              elevation: 0,
            ),
            body: _SavedPage(
              savedPlaces: _savedPlaces,
              onUsePlace: (place) {
                Navigator.of(context).pop();
                _useSavedPlace(place);
              },
              onDeletePlace: _deleteSavedPlace,
              onOpenPlace: _openSavedPlaceDetails,
            ),
          ),
        ),
      ),
    );
  }

  void _editProfile() {
    final user = _authService.currentUser;
    final nameController = TextEditingController(text: user?.fullName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    var selectedPhoto = user?.profileImageBytes;

    String initialsFor(String name) {
      final words = name
          .trim()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();
      if (words.isEmpty) return 'NA';
      if (words.length == 1) {
        return words.first
            .substring(0, words.first.length.clamp(1, 2))
            .toUpperCase();
      }
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: NavAblePalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NavAbleRadius.card),
        ),
      ),
      builder: (sheetContext) {
        return NavAbleLightTheme(
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              Future<void> changePhoto() async {
                final action = await showModalBottomSheet<_ProfilePhotoAction>(
                  context: sheetContext,
                  useSafeArea: true,
                  showDragHandle: true,
                  backgroundColor: NavAblePalette.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(NavAbleRadius.card),
                    ),
                  ),
                  builder: (context) => Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NavAbleSpacing.md,
                      NavAbleSpacing.xs,
                      NavAbleSpacing.md,
                      NavAbleSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile Photo',
                          style: TextStyle(
                            color: kNavAbleNavy,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: NavAbleSpacing.sm),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFDDF9E3),
                            child: Icon(
                              Icons.photo_camera_outlined,
                              color: NavAblePalette.greenDark,
                            ),
                          ),
                          title: const Text('Take a Photo'),
                          subtitle: const Text('Use your device camera'),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(_ProfilePhotoAction.camera),
                        ),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFDDEEFF),
                            child: Icon(
                              Icons.photo_library_outlined,
                              color: kNavAbleNavy,
                            ),
                          ),
                          title: const Text('Choose from Gallery'),
                          subtitle: const Text('Select an existing image'),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(_ProfilePhotoAction.gallery),
                        ),
                        if (selectedPhoto != null)
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFEE4E2),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFB42318),
                              ),
                            ),
                            title: const Text('Remove Current Photo'),
                            onTap: () => Navigator.of(
                              context,
                            ).pop(_ProfilePhotoAction.remove),
                          ),
                      ],
                    ),
                  ),
                );

                if (action == null || !sheetContext.mounted) return;
                if (action == _ProfilePhotoAction.remove) {
                  setSheetState(() => selectedPhoto = null);
                  return;
                }

                try {
                  final image = await ImagePicker().pickImage(
                    source: action == _ProfilePhotoAction.camera
                        ? ImageSource.camera
                        : ImageSource.gallery,
                    maxWidth: 1200,
                    maxHeight: 1200,
                    imageQuality: 88,
                    requestFullMetadata: false,
                  );
                  if (image == null) return;
                  final imageBytes = await image.readAsBytes();
                  if (!sheetContext.mounted) return;
                  setSheetState(() => selectedPhoto = imageBytes);
                } catch (_) {
                  if (!sheetContext.mounted) return;
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'The photo could not be opened. Check camera or photo permissions and try again.',
                      ),
                    ),
                  );
                }
              }

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  NavAbleSpacing.lg,
                  NavAbleSpacing.xs,
                  NavAbleSpacing.lg,
                  MediaQuery.viewInsetsOf(sheetContext).bottom +
                      NavAbleSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        color: kNavAbleNavy,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: NavAbleSpacing.md),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: kNavAbleGreen,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              backgroundColor: const Color(0xFFE8F3EC),
                              foregroundImage: selectedPhoto == null
                                  ? null
                                  : MemoryImage(selectedPhoto!),
                              child: selectedPhoto == null
                                  ? Text(
                                      initialsFor(nameController.text),
                                      style: const TextStyle(
                                        color: kNavAbleNavy,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: NavAbleSpacing.xs),
                          TextButton.icon(
                            onPressed: changePhoto,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: Text(
                              selectedPhoto == null
                                  ? 'Add Profile Photo'
                                  : 'Change Profile Photo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NavAbleSpacing.sm),
                    _InputField(
                      controller: nameController,
                      hintText: 'Full name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: NavAbleSpacing.sm),
                    _InputField(
                      controller: emailController,
                      hintText: 'Email address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: NavAbleSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      height: NavAbleSize.primaryButton,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final result = await _authService.updateProfile(
                            fullName: nameController.text,
                            email: emailController.text,
                            profileImageBytes: selectedPhoto,
                          );
                          if (!mounted || !sheetContext.mounted) return;
                          if (!result.isSuccess) {
                            _showMessage(
                              result.message ?? 'Profile update failed.',
                            );
                            return;
                          }

                          setState(() {});
                          Navigator.of(sheetContext).pop();
                          _showMessage('Profile updated.');
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Profile'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      emailController.dispose();
    });
  }

  Future<PhotoAnalysis> _analyzeReportPhotos(List<Uint8List> photos) =>
      ReportsApi.analyzePhotos(photos: photos);

  Future<bool> _submitReport(
    AccessReport report,
    PhotoAnalysis analysis,
  ) async {
    try {
      final result = await ReportsApi.submit(
        title: report.title,
        detail: report.detail,
        category: report.category,
        locationId: report.locationId,
        coordinates: report.location,
        googlePlaceId: report.googlePlaceId,
        photos: report.photoBytes,
        analysis: analysis,
      );
      if (!mounted) return false;
      final savedReport = report.copyWith(
        id: result.id,
        aiAnalysisStatus: result.aiAnalysisStatus,
        detections: result.detections,
        aiAnalysisCompleted: result.aiAnalysisStatus == 'completed',
      );
      setState(() {
        _reports.insert(0, savedReport);
        _submissions.insert(
          0,
          AccessibilitySubmission(
            title: savedReport.title,
            submittedOn: 'Today',
            status: SubmissionStatus.pending,
            statusDetail: 'Waiting for administrator review',
            icon: savedReport.icon,
          ),
        );
      });
      _loadProfileStats();
      _showMessage(switch (result.aiAnalysisStatus) {
        'completed' => 'Report submitted. AI suggestions are ready for review.',
        'skipped' => 'Report submitted for administrator review.',
        'partial' =>
          'Report submitted. Some photos need administrator review without AI results.',
        _ =>
          'Report submitted. AI analysis was unavailable; an administrator can still review it.',
      });
      return true;
    } on ReportsApiException catch (error) {
      if (mounted) _showMessage(error.message);
      return false;
    } catch (_) {
      if (mounted) {
        _showMessage('Could not submit the report. Please try again.');
      }
      return false;
    }
  }

  void _openInfoPage(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => InfoScreen(title: title, body: body),
      ),
    );
  }

  void _openAccessibilityFilters() {
    FocusManager.instance.primaryFocus?.unfocus();

    var ramp = _avoidStairs;
    var elevator = _prioritizeElevators;
    var entrance = _accessibleEntrance;
    var toilet = _accessibleToilet;
    var tactile = _tactilePaving;
    var audio = _audioAssistance;
    var parking = _accessibleParking;
    var seating = _wheelchairSeating;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor: kNavAbleNavy.withValues(alpha: 0.42),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return NavAbleLightTheme(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return FractionallySizedBox(
                heightFactor: 0.82,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Accessibility Filters',
                              style: TextStyle(
                                color: kNavAbleNavy,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close filters',
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: kNavAbleNavy,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select the features you need to ensure a comfortable and safe journey.',
                              style: TextStyle(
                                color: kNavAbleText,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _FilterOptionTile(
                              icon: Icons.accessible_forward_rounded,
                              label: 'Wheelchair Ramp',
                              value: ramp,
                              onChanged: (value) =>
                                  setSheetState(() => ramp = value),
                            ),
                            _FilterOptionTile(
                              icon: Icons.elevator_outlined,
                              label: 'Elevator',
                              value: elevator,
                              onChanged: (value) =>
                                  setSheetState(() => elevator = value),
                            ),
                            _FilterOptionTile(
                              icon: Icons.meeting_room_outlined,
                              label: 'Accessible Entrance',
                              value: entrance,
                              onChanged: (value) =>
                                  setSheetState(() => entrance = value),
                            ),
                            _FilterOptionTile(
                              icon: Icons.wc_rounded,
                              label: 'Accessible Toilet',
                              value: toilet,
                              onChanged: (value) =>
                                  setSheetState(() => toilet = value),
                            ),
                            _FilterOptionTile(
                              icon: Icons.blind_rounded,
                              label: 'Tactile Paving',
                              value: tactile,
                              onChanged: (value) =>
                                  setSheetState(() => tactile = value),
                            ),
                            _FilterOptionTile(
                              icon: Icons.hearing_rounded,
                              label: 'Audio Assistance',
                              value: audio,
                              onChanged: (value) =>
                                  setSheetState(() => audio = value),
                            ),
                            _FilterOptionTile(
                              icon: Icons.local_parking_rounded,
                              label: 'Accessible Parking',
                              value: parking,
                              onChanged: (value) =>
                                  setSheetState(() => parking = value),
                            ),
                            _FilterOptionTile(
                              icon: Icons.event_seat_outlined,
                              label: 'Wheelchair Seating',
                              value: seating,
                              onChanged: (value) =>
                                  setSheetState(() => seating = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: NavAbleSize.control,
                            child: FilledButton.icon(
                              onPressed: () {
                                setState(() {
                                  _avoidStairs = ramp;
                                  _prioritizeElevators = elevator;
                                  _accessibleEntrance = entrance;
                                  _accessibleToilet = toilet;
                                  _tactilePaving = tactile;
                                  _audioAssistance = audio;
                                  _accessibleParking = parking;
                                  _wheelchairSeating = seating;
                                });
                                Navigator.of(sheetContext).pop();
                                _showMessage('Accessibility filters applied.');
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: kNavAbleNavy,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 19,
                              ),
                              label: const Text('Apply Filters'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: NavAbleSize.compactControl,
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  ramp = false;
                                  elevator = false;
                                  entrance = false;
                                  toilet = false;
                                  tactile = false;
                                  audio = false;
                                  parking = false;
                                  seating = false;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kNavAbleNavy,
                                side: const BorderSide(
                                  color: kNavAbleNavy,
                                  width: 1.5,
                                ),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('Clear All'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final pages = <Widget>[
      _PlanPage(
        isGuest: widget.isGuest,
        accessibleLocations: _accessibleLocations,
        locationsLoading: _locationsLoading,
        locationsError: _locationsError,
        selectedLocation: _selectedMapLocation,
        selectedPlace: _selectedPlace,
        onOpenInGoogleMaps: _openSelectedPlaceInGoogleMaps,
        destinationController: _destinationController,
        placeSearchResults: _placeSearchResults,
        resultPins: _resultPins,
        placeSearching: _placeSearching,
        searchedPlace: _searchedPlace,
        routeStatus: _routeStatus,
        walkingRoute: _walkingRoute,
        routing: _routing,
        avoidStairs: _avoidStairs,
        prioritizeElevators: _prioritizeElevators,
        accessibleEntrance: _accessibleEntrance,
        accessibleToilet: _accessibleToilet,
        tactilePaving: _tactilePaving,
        audioAssistance: _audioAssistance,
        accessibleParking: _accessibleParking,
        wheelchairSeating: _wheelchairSeating,
        onLocationSelected: _selectMapLocation,
        onAvoidStairsChanged: (value) => setState(() => _avoidStairs = value),
        onPrioritizeElevatorsChanged: (value) =>
            setState(() => _prioritizeElevators = value),
        onAccessibleEntranceChanged: (value) =>
            setState(() => _accessibleEntrance = value),
        onAccessibleToiletChanged: (value) =>
            setState(() => _accessibleToilet = value),
        onTactilePavingChanged: (value) =>
            setState(() => _tactilePaving = value),
        onAudioAssistanceChanged: (value) =>
            setState(() => _audioAssistance = value),
        onAccessibleParkingChanged: (value) =>
            setState(() => _accessibleParking = value),
        onWheelchairSeatingChanged: (value) =>
            setState(() => _wheelchairSeating = value),
        onDestinationChanged: _onDestinationChanged,
        onSearchPlaces: _searchPlaces,
        onSearchTapped: _showSuggestionsAgain,
        onDismissSuggestions: _dismissSuggestions,
        onPlaceSelected: _selectSearchedPlace,
        onOpenRouteDetails: _openRouteDetails,
        onSaveDestination: _saveAccessibleLocation,
        onReportBarrier: _openReportsTab,
        onSubmitAccessiblePhoto: () => _startPhotoSubmission(
          location: _selectedMapLocation,
          openCamera: true,
        ),
        onSubmitPlacePhoto: (location) =>
            _startPhotoSubmission(location: location),
        onOpenSaved: _openSavedPlaces,
        onOpenFilters: _openAccessibilityFilters,
      ),
      _ExplorePage(
        searchController: _exploreSearchController,
        locations: _accessibleLocations,
        locationsLoading: _locationsLoading,
        locationsError: _locationsError,
        onNavigate: (location) => _navigateToPlace(location.name),
        onSubmitPhoto: (location) => _startPhotoSubmission(location: location),
        onContributeGooglePlace: _contributeToGooglePlace,
        onRefresh: () => _loadAccessibleLocations(refresh: true),
      ),
      if (!widget.isGuest) ...[
        _ReportsPage(
          reports: _reports,
          locations: _accessibleLocations,
          initialLocation: _pendingPhotoLocation,
          photoCaptureRequestId: _photoCaptureRequestId,
          onPhotoCaptureRequestHandled: () => _photoCaptureRequestId = 0,
          onAnalyzePhotos: _analyzeReportPhotos,
          onSubmitReport: _submitReport,
          onOpenReport: _openReportDetails,
          initialKind: _reportKind,
          initialGooglePlace: _pendingGooglePlace,
          onBackToHome: () => setState(() => _selectedIndex = 0),
          onOpenContributions: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => _MySubmissionsScreen(
                submissions: _submissions,
                reportCount: _profileStats?.reportCount,
              ),
            ),
          ),
        ),
        _AlertsPage(reports: _reports, onOpenReport: _openReportDetails),
        _ProfilePage(
          user: user,
          contributionPoints: _profileStats?.contributionPoints,
          reportCount: _profileStats?.reportCount,
          savedPlaceCount: _profileStats?.savedPlaceCount,
          statsLoading: _profileStatsLoading,
          submissions: _submissions,
          voiceGuidance: _voiceGuidance,
          onVoiceGuidanceChanged: (value) =>
              setState(() => _voiceGuidance = value),
          onEditProfile: _editProfile,
          onOpenInfo: _openInfoPage,
          onSignOut: () async {
            _signingOut = true;
            await _authService.logout();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (context) => const WelcomeScreen(),
              ),
              (route) => false,
            );
          },
        ),
      ],
    ];

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 58,
        leading: _selectedIndex == 1
            ? IconButton(
                tooltip: 'Back to Home',
                onPressed: () => setState(() => _selectedIndex = 0),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: const SizedBox.shrink(),
        elevation: 0,
        actions: [
          if (widget.isGuest)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (context) => const LoginScreen(),
                ),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign in'),
            )
          else
            IconButton(
              tooltip: 'Profile',
              onPressed: () => setState(() => _selectedIndex = 4),
              icon: const Icon(Icons.account_circle_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() {
          _selectedIndex = index;
          _reportKind = null;
          _pendingGooglePlace = null;
        }),
        indicatorColor: theme.brightness == Brightness.dark
            ? NavAblePalette.green.withValues(alpha: 0.2)
            : kNavAbleAccent,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          if (!widget.isGuest) ...[
            const NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check_rounded),
              label: 'Reports',
            ),
            const NavigationDestination(
              icon: Icon(Icons.notifications_none_rounded),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ],
      ),
    );
  }
}

class SavedPlace {
  const SavedPlace({
    required this.name,
    required this.address,
    required this.tag,
  });

  final String name;
  final String address;
  final String tag;
}

class AccessReport {
  const AccessReport({
    this.id,
    required this.title,
    this.location = '',
    this.locationId,
    this.googlePlaceId,
    required this.detail,
    required this.category,
    required this.icon,
    this.photoBytes = const [],
    this.detections = const [],
    this.aiAnalysisCompleted = false,
    this.aiAnalysisStatus = 'not_started',
    this.confirmations = 0,
  });

  final String? id;
  final String title;
  final String location;
  final String? locationId;

  /// Google place being contributed to when it isn't a NavAble place yet.
  final String? googlePlaceId;
  final String detail;
  final String category;
  final IconData icon;
  final List<Uint8List> photoBytes;
  final List<Map<String, dynamic>> detections;
  final bool aiAnalysisCompleted;
  final String aiAnalysisStatus;
  final int confirmations;

  AccessReport copyWith({
    String? id,
    String? title,
    String? location,
    String? locationId,
    String? detail,
    String? category,
    IconData? icon,
    List<Uint8List>? photoBytes,
    List<Map<String, dynamic>>? detections,
    bool? aiAnalysisCompleted,
    String? aiAnalysisStatus,
    int? confirmations,
  }) {
    return AccessReport(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      locationId: locationId ?? this.locationId,
      googlePlaceId: googlePlaceId,
      detail: detail ?? this.detail,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      photoBytes: photoBytes ?? this.photoBytes,
      detections: detections ?? this.detections,
      aiAnalysisCompleted: aiAnalysisCompleted ?? this.aiAnalysisCompleted,
      aiAnalysisStatus: aiAnalysisStatus ?? this.aiAnalysisStatus,
      confirmations: confirmations ?? this.confirmations,
    );
  }
}

enum SubmissionStatus { pending, approved, rejected }

class AccessibilitySubmission {
  const AccessibilitySubmission({
    required this.title,
    required this.submittedOn,
    required this.status,
    required this.statusDetail,
    required this.icon,
  });

  final String title;
  final String submittedOn;
  final SubmissionStatus status;
  final String statusDetail;
  final IconData icon;
}

class _SavedPage extends StatelessWidget {
  const _SavedPage({
    required this.savedPlaces,
    required this.onUsePlace,
    required this.onDeletePlace,
    required this.onOpenPlace,
  });

  final List<SavedPlace> savedPlaces;
  final ValueChanged<SavedPlace> onUsePlace;
  final ValueChanged<SavedPlace> onDeletePlace;
  final ValueChanged<SavedPlace> onOpenPlace;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        if (savedPlaces.isEmpty)
          const _EmptyState(
            icon: Icons.bookmark_border_rounded,
            title: 'No saved places yet',
            detail: 'Save a destination from the route planner.',
          )
        else
          for (final place in savedPlaces)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Panel(
                child: InkWell(
                  onTap: () => onOpenPlace(place),
                  child: Row(
                    children: [
                      const _CircleIcon(icon: Icons.place_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: const TextStyle(
                                color: kNavAbleNavy,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${place.address} - ${place.tag}',
                              style: const TextStyle(
                                color: kNavAbleText,
                                fontSize: 13,
                                height: 1.35,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Route',
                        onPressed: () => onUsePlace(place),
                        icon: const Icon(Icons.route_rounded),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => onDeletePlace(place),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return NavAbleLightTheme(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FAF8),
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.white,
          foregroundColor: kNavAbleNavy,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Panel(
                child: Text(
                  body,
                  style: const TextStyle(
                    color: kNavAbleText,
                    fontSize: 15,
                    height: 1.55,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RouteDetailsScreen extends StatelessWidget {
  const RouteDetailsScreen({super.key, required this.route});

  final PlannedRoute route;

  @override
  Widget build(BuildContext context) {
    return NavAbleLightTheme(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FAF8),
        appBar: AppBar(
          title: const Text('Route Details'),
          backgroundColor: Colors.white,
          foregroundColor: kNavAbleNavy,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.destinationName,
                      style: const TextStyle(
                        color: kNavAbleNavy,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${route.summary}\n${route.mode.label} route estimate from OpenStreetMap.',
                      style: const TextStyle(
                        color: kNavAbleText,
                        fontSize: 14,
                        height: 1.45,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${route.mode.label} directions',
                      style: TextStyle(
                        color: kNavAbleNavy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (route.instructions.isEmpty)
                      const Text('No turn-by-turn instructions were returned.')
                    else
                      for (
                        var index = 0;
                        index < route.instructions.length;
                        index++
                      )
                        _InstructionStep(
                          number: index + 1,
                          text: route.instructions[index],
                        ),
                    const SizedBox(height: 12),
                    Text(
                      switch (route.mode) {
                        TravelMode.walking =>
                          'This route is not verified for wheelchair access or step-free travel. Check the route and location details before following it.',
                        TravelMode.car =>
                          'Follow posted signs and local traffic rules. Route estimates may not reflect current closures or restrictions.',
                        TravelMode.motorcycle =>
                          'Motorcycle routes use the standard car road profile and may not reflect motorcycle-specific restrictions. Follow posted signs and local traffic rules.',
                      },
                      style: TextStyle(
                        color: kNavAbleText,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportDetailsScreen extends StatefulWidget {
  const ReportDetailsScreen({
    super.key,
    required this.report,
    required this.onConfirm,
  });

  final AccessReport report;
  final VoidCallback onConfirm;

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final confirmations = widget.report.confirmations + (_confirmed ? 1 : 0);

    return NavAbleLightTheme(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FAF8),
        appBar: AppBar(
          title: const Text('Report Details'),
          backgroundColor: Colors.white,
          foregroundColor: kNavAbleNavy,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(widget.report.icon, color: kNavAbleGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.report.title,
                            style: const TextStyle(
                              color: kNavAbleNavy,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        _Tag(label: widget.report.category),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.report.detail,
                      style: const TextStyle(
                        color: kNavAbleText,
                        fontSize: 15,
                        height: 1.5,
                        letterSpacing: 0,
                      ),
                    ),
                    if (widget.report.photoBytes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 190,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.report.photoBytes.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              widget.report.photoBytes[index],
                              width: 240,
                              height: 190,
                              fit: BoxFit.cover,
                              semanticLabel:
                                  'Accessibility report photo ${index + 1}',
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (widget.report.aiAnalysisStatus != 'not_started') ...[
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F7F3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD5E9DB)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_outlined,
                                    color: kNavAbleGreen,
                                    size: 19,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI photo suggestions',
                                    style: TextStyle(
                                      color: kNavAbleNavy,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (!widget.report.aiAnalysisCompleted)
                                Text(
                                  widget.report.aiAnalysisStatus == 'failed'
                                      ? 'AI analysis could not finish. An administrator can still review the report.'
                                      : 'AI analysis: ${widget.report.aiAnalysisStatus}. Suggestions are informational and awaiting human review.',
                                  style: const TextStyle(color: kNavAbleText),
                                )
                              else if (widget.report.detections.isEmpty)
                                const Text(
                                  'No recognized accessibility features found.',
                                  style: TextStyle(color: kNavAbleText),
                                )
                              else
                                for (final detection
                                    in widget.report.detections)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      detection.entries
                                          .where(
                                            (entry) =>
                                                entry.value is String ||
                                                entry.value is num ||
                                                entry.value is bool,
                                          )
                                          .map(
                                            (entry) =>
                                                '${entry.key}: ${entry.value}',
                                          )
                                          .join(' · '),
                                      style: const TextStyle(
                                        color: kNavAbleNavy,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              const SizedBox(height: 6),
                              const Text(
                                'AI suggestions only. An admin must verify this report.',
                                style: TextStyle(
                                  color: kNavAbleText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      '$confirmations local confirmations',
                      style: const TextStyle(
                        color: kNavAbleNavy,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: NavAbleSize.control,
                      child: FilledButton.icon(
                        onPressed: _confirmed
                            ? null
                            : () {
                                widget.onConfirm();
                                setState(() => _confirmed = true);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: kNavAbleNavy,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.verified_outlined),
                        label: Text(
                          _confirmed ? 'Confirmed' : 'Confirm Report',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SavedPlaceDetailsScreen extends StatefulWidget {
  const SavedPlaceDetailsScreen({
    super.key,
    required this.place,
    required this.onRoute,
    required this.onSave,
  });

  final SavedPlace place;
  final VoidCallback onRoute;
  final ValueChanged<SavedPlace> onSave;

  @override
  State<SavedPlaceDetailsScreen> createState() =>
      _SavedPlaceDetailsScreenState();
}

class _SavedPlaceDetailsScreenState extends State<SavedPlaceDetailsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late String _tag;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.place.name);
    _addressController = TextEditingController(text: widget.place.address);
    _tag = widget.place.tag;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    if (name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Add a name and address.')));
      return;
    }

    widget.onSave(SavedPlace(name: name, address: address, tag: _tag));
  }

  @override
  Widget build(BuildContext context) {
    return NavAbleLightTheme(
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FAF8),
        appBar: AppBar(
          title: const Text('Saved Place'),
          backgroundColor: Colors.white,
          foregroundColor: kNavAbleNavy,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InputField(
                      controller: _nameController,
                      hintText: 'Place name',
                      icon: Icons.place_outlined,
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      controller: _addressController,
                      hintText: 'Accessible entrance or note',
                      icon: Icons.notes_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _tag,
                      decoration: _fieldDecoration(
                        hintText: 'Tag',
                        icon: Icons.label_outline,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Home', child: Text('Home')),
                        DropdownMenuItem(value: 'Work', child: Text('Work')),
                        DropdownMenuItem(
                          value: 'Transit',
                          child: Text('Transit'),
                        ),
                        DropdownMenuItem(value: 'Civic', child: Text('Civic')),
                        DropdownMenuItem(
                          value: 'Custom',
                          child: Text('Custom'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _tag = value);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onRoute,
                            icon: const Icon(Icons.route_rounded),
                            label: const Text('Route'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: kNavAbleNavy,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: kNavAbleAccent,
            child: Text(
              '$number',
              style: const TextStyle(
                color: kNavAbleNavy,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: kNavAbleText,
                fontSize: 14,
                height: 1.45,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final AccessReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: InkWell(
        onTap: onTap,
        child: _ReportTile(report: report, showCategory: true),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, this.showCategory = false});

  final AccessReport report;
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(report.icon, color: kNavAbleGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.title,
                        style: const TextStyle(
                          color: kNavAbleNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (showCategory) _Tag(label: report.category),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  report.detail,
                  style: const TextStyle(
                    color: kNavAbleText,
                    fontSize: 13,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
                if (report.confirmations > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${report.confirmations} confirmations',
                    style: const TextStyle(
                      color: kNavAbleNavy,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _fieldDecoration(hintText: hintText, icon: icon),
    );
  }
}

InputDecoration _fieldDecoration({
  required String hintText,
  required IconData icon,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF7FAF8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDDE5DF)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDDE5DF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kNavAbleGreen, width: 1.5),
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kNavAbleAccent,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: kNavAbleNavy,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: kNavAbleAccent,
      child: Icon(icon, color: kNavAbleGreen),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Icon(icon, color: kNavAbleGreen, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.navAbleSecondaryText,
              fontSize: 13,
              height: 1.4,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(NavAbleSpacing.cardInset),
      borderRadius: NavAbleRadius.card,
      color: context.navAbleSurface,
      child: child,
    );
  }
}
