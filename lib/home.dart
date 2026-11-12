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
import 'legal.dart';
import 'login.dart';
import 'navable_design.dart';
import 'accessibility_filters.dart';
import 'locations_api.dart';
import 'place_categories.dart';
import 'place_search.dart';
import 'places_api.dart';
import 'points/celebration_store.dart';
import 'points/points_api.dart';
import 'profile_stats_api.dart';
import 'reports_api.dart';
import 'route_planner_api.dart';
import 'saved_places_store.dart';
import 'utils/initials.dart';
import 'welcome.dart';
import 'widgets/confetti.dart';

part 'screens/home_tab.dart';
part 'screens/explore_tab.dart';
part 'screens/reports_tab.dart';
part 'screens/alerts_tab.dart';
part 'screens/profile_tab.dart';
part 'screens/settings_screen.dart';
part 'screens/submissions_screen.dart';
part 'screens/report_result_screens.dart';
part 'screens/ai_scanning_screen.dart';
part 'screens/points_section.dart';
part 'screens/leaderboard_screen.dart';
part 'screens/level_up_screen.dart';
part 'screens/report_models.dart';
part 'screens/route_details_screen.dart';
part 'screens/saved_places_screen.dart';
part 'widgets/home_widgets.dart';
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
  // Contributor points (lifetime level and progress, history, pending).
  MyStanding? _standing;
  List<PointsAward> _awards = const [];
  List<PendingContribution> _pending = const [];
  bool _pointsLoading = true;
  bool _pointsFailed = false;
  List<AppAlert> _alerts = const [];
  bool _celebrating = false;
  bool _profileStatsLoading = true;
  bool _locationsLoading = true;
  String? _locationsError;
  bool _avoidStairs = false; // no filter is on until the user picks one
  bool _prioritizeElevators = false;
  bool _accessibleEntrance = false;
  bool _accessibleToilet = false;
  bool _tactilePaving = false;
  bool _accessibleParking = false;
  bool _wheelchairSeating = false;
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

  // The user's reports as stored, so history and status survive restarts.
  List<MyReport> _myReports = const [];

  StreamSubscription<AuthState>? _authSubscription;
  bool _signingOut = false;

  DateTime _locationsLoadedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAccessibleLocations();
    _loadProfileStats();
    _loadPoints();
    _loadAlerts();
    _loadMyReports();
    _loadSavedPlaces();
    if (!widget.isGuest) _loadProfilePicture();
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

  /// Saved places live on this device only, one list per account.
  String? get _savedPlacesOwner {
    if (widget.isGuest) return null;
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfilePicture() async {
    if (await _authService.loadProfilePicture() && mounted) setState(() {});
  }

  Future<void> _loadSavedPlaces() async {
    final places = await SavedPlacesStore.load(_savedPlacesOwner);
    if (!mounted || places.isEmpty) return;
    setState(() {
      _savedPlaces
        ..clear()
        ..addAll(places);
    });
  }

  Future<void> _storeSavedPlaces() async {
    final stored = await SavedPlacesStore.save(_savedPlacesOwner, _savedPlaces);
    if (!stored && mounted) {
      _showMessage('Could not keep saved places on this device.');
    }
  }

  Future<void> _loadPoints() async {
    if (widget.isGuest) {
      if (mounted) setState(() => _pointsLoading = false);
      return;
    }
    try {
      final standing = PointsApi.myStanding(LeaderboardPeriod.all);
      final awards = PointsApi.myAwards();
      final pending = PointsApi.myPending();
      final (loadedStanding, loadedAwards, loadedPending) = (
        await standing,
        await awards,
        await pending,
      );
      if (!mounted) return;
      setState(() {
        _standing = loadedStanding;
        _awards = loadedAwards;
        _pending = loadedPending;
        _pointsLoading = false;
        _pointsFailed = false;
      });
      _celebrateNewLevel();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pointsLoading = false;
        _pointsFailed = true; // keeps the last loaded values, if any
      });
    }
  }

  /// Plays the level-up screen once when the user's level went up since the
  /// last check on this device. The first check only records the level.
  Future<void> _celebrateNewLevel() async {
    final userId = _savedPlacesOwner;
    final progress = _standing?.progress;
    if (userId == null || progress == null || _celebrating) return;
    final last = await CelebrationStore.lastCelebrated(userId);
    final level = levelToCelebrate(
      lastCelebrated: last,
      currentLevel: progress.level,
    );
    if (level == null) {
      // First check, or same/lower level (a lower one lets a later climb
      // celebrate again).
      if (last != progress.level) {
        await CelebrationStore.setLastCelebrated(userId, progress.level);
      }
      return;
    }
    _celebrating = true;
    await CelebrationStore.setLastCelebrated(userId, level);
    if (!mounted) {
      _celebrating = false;
      return;
    }
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, _, _) =>
            _LevelUpScreen(level: level, name: progress.name),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    _celebrating = false;
  }

  Future<void> _loadMyReports() async {
    if (widget.isGuest) return;
    try {
      final reports = await ReportsApi.myReports();
      if (mounted) setState(() => _myReports = reports);
    } catch (_) {
      // Keep what's shown; try again on the next load.
    }
  }

  /// My Submissions and Profile read the stored reports.
  List<AccessibilitySubmission> get _submissions => [
    for (final report in _myReports)
      AccessibilitySubmission(
        title: report.title,
        submittedOn: _shortDate(report.createdAt),
        status: switch (report.status) {
          ReportStatus.pending => SubmissionStatus.pending,
          ReportStatus.verified ||
          ReportStatus.resolved => SubmissionStatus.approved,
          ReportStatus.rejected => SubmissionStatus.rejected,
        },
        statusDetail: '${report.status.label} · ${report.placeName}',
        icon: _reportStatusIcon(report.status),
      ),
  ];

  Future<void> _loadAlerts() async {
    if (widget.isGuest) return;
    try {
      final alerts = await PointsApi.myAlerts();
      if (mounted) setState(() => _alerts = alerts);
    } catch (_) {
      // Keep what's shown; report updates still appear.
    }
  }

  /// Opening Alerts marks them read. The green dots stay until the next
  /// load, so the user can still see which ones are new.
  Future<void> _openAlerts() async {
    await _loadAlerts();
    if (_alerts.any((alert) => !alert.isRead)) {
      try {
        await PointsApi.markAlertsRead();
      } catch (_) {
        // Try again next time.
      }
    }
  }

  void _openMySubmissions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _MySubmissionsScreen(
          submissions: _submissions,
          reportCount: _profileStats?.reportCount,
        ),
      ),
    );
  }

  void _openLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _LeaderboardScreen(isGuest: widget.isGuest),
      ),
    );
  }

  /// Same as the top bar's Sign in for guests.
  void _openSignIn() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => const LoginScreen()),
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
      _loadPoints();
      _loadAlerts();
      _loadMyReports();
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
        // Nothing is picked until the user taps a pin or a search result.
        if (_selectedMapLocation case final selected?) {
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
    String? navAbleFeatures(AccessibleLocation location) =>
        location.features.isEmpty ? null : location.features.take(3).join(', ');
    final accessibleResults = _accessibleLocations
        .where(
          (location) => placeMatchesQuery(
            searchText,
            name: location.name,
            address: location.address,
            category: location.category,
            features: location.features,
          ),
        )
        .map(
          (location) => PlaceSearchResult(
            name: location.name,
            // "Shopping mall · Cebu Business Park"
            displayName: [
              if (location.category.isNotEmpty) location.category,
              ?_readableAddress(location.address),
            ].join(' · '),
            point: osm.LatLng(location.latitude, location.longitude),
            accessibility: navAbleFeatures(location),
            category: location.category.isEmpty ? null : location.category,
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
      // A position found earlier stands in when this lookup gives none.
      var center = await _currentPositionOrNull() ?? _userPosition;
      if (!mounted) return;
      _userPosition = center;
      if (center == null && nearMe) {
        _showMessage(
          'Turn on location to search near you. Showing results near '
          'Cebu City.',
        );
      }
      center ??= _searchedPlace?.point ?? _cebuMapCenter;
      var mapResults = const <PlaceSearchResult>[];
      final category = categoryForQuery(searchText);
      if (category != null) {
        // Just a type of place ("mall"): every one nearby, as pins.
        // Within 5 km, or 15 km when none are that close.
        try {
          for (final radius in [5000, if (!nearMe) 15000]) {
            mapResults = await RoutePlannerApi.categoryPlaces(
              category,
              near: center,
              radiusMeters: radius,
            );
            if (mapResults.isNotEmpty) break;
          }
        } on RoutePlannerException {
          // The category server is down or busy; the regular search below
          // still finds the main ones.
        }
        if (!mounted) return;
        if (mapResults.isEmpty) {
          for (final reach in [0.05, if (!nearMe) 0.2]) {
            mapResults = await RoutePlannerApi.searchPlaces(
              query: category.aliases.first,
              near: center,
              reach: reach,
              bounded: true,
              limit: 40,
            );
            if (mapResults.isNotEmpty) break;
          }
        }
      } else {
        // Within ~5 km first, then ~20 km, then anywhere (for exact names
        // farther away). "near me" stops at ~5 km.
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

  /// The user's position, or null when location is off, refused, or takes
  /// longer than a few seconds. Capped so an unanswered permission prompt
  /// (easy to miss in a browser or on a computer) can't stall a search.
  Future<osm.LatLng?> _currentPositionOrNull() async {
    try {
      return await _lookUpPosition().timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }

  Future<osm.LatLng?> _lookUpPosition() async {
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
    if (_savedPlaces.any(
      (place) => place.locationId == location.id || place.name == location.name,
    )) {
      _showMessage('${location.name} is already saved.');
      return;
    }
    setState(() {
      _savedPlaces.insert(
        0,
        SavedPlace(
          name: location.name,
          address: location.address,
          tag: 'Custom',
          locationId: location.id,
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      );
    });
    _storeSavedPlaces();
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
    _storeSavedPlaces();
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
            _storeSavedPlaces();
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
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Saved Places'), elevation: 0),
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
    );
  }

  void _editProfile() {
    final user = _authService.currentUser;
    final nameController = TextEditingController(text: user?.fullName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    var selectedPhoto = user?.profileImageBytes;

    String initialsFor(String name) => initialsOf(name, fallback: 'NA');

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
        return StatefulBuilder(
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
                      Text(
                        'Profile Photo',
                        style: TextStyle(
                          color: context.navAblePrimaryText,
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
                        leading: CircleAvatar(
                          backgroundColor: Color(0xFFDDEEFF),
                          child: Icon(
                            Icons.photo_library_outlined,
                            color: context.navAblePrimaryText,
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
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: context.navAblePrimaryText,
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
                                    style: TextStyle(
                                      color: context.navAblePrimaryText,
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
      _loadMyReports();
      _loadProfileStats();
      _loadPoints();
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
    var parking = _accessibleParking;
    var seating = _wheelchairSeating;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.navAbleSurface,
      barrierColor: kNavAbleNavy.withValues(alpha: 0.42),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.82,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Accessibility Filters',
                            style: TextStyle(
                              color: context.navAblePrimaryText,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close filters',
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: context.navAblePrimaryText,
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
                          Text(
                            'Select the features you need to ensure a comfortable and safe journey.',
                            style: TextStyle(
                              color: context.navAbleSecondaryText,
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
                                parking = false;
                                seating = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kNavAbleNavy,
                              side: BorderSide(
                                color: context.navAblePrimaryText,
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
          reports: _myReports,
          locations: _accessibleLocations,
          initialLocation: _pendingPhotoLocation,
          photoCaptureRequestId: _photoCaptureRequestId,
          onPhotoCaptureRequestHandled: () => _photoCaptureRequestId = 0,
          onAnalyzePhotos: _analyzeReportPhotos,
          onSubmitReport: _submitReport,
          initialKind: _reportKind,
          initialGooglePlace: _pendingGooglePlace,
          onBackToHome: () => setState(() => _selectedIndex = 0),
          onOpenContributions: _openMySubmissions,
        ),
        _AlertsPage(
          reports: _myReports,
          alerts: _alerts,
          onOpenReports: _openMySubmissions,
        ),
        _ProfilePage(
          pointsSection: _PointsSection(
            isGuest: widget.isGuest,
            loading: _pointsLoading,
            failed: _pointsFailed,
            standing: _standing,
            awards: _awards,
            pending: _pending,
            onOpenLeaderboard: _openLeaderboard,
            onSignIn: _openSignIn,
          ),
          user: user,
          contributionPoints: _profileStats?.contributionPoints,
          reportCount: _profileStats?.reportCount,
          // Saved places live on this device.
          savedPlaceCount: _savedPlaces.length,
          statsLoading: _profileStatsLoading,
          submissions: _submissions,
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
          IconButton(
            tooltip: 'Top contributors',
            onPressed: _openLeaderboard,
            icon: const Icon(Icons.emoji_events_outlined),
          ),
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
              icon: _TopBarAvatar(user: _authService.currentUser),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            _reportKind = null;
            _pendingGooglePlace = null;
          });
          if (index == 3) _openAlerts();
        },
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
