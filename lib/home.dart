import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as osm;

import 'auth_service.dart';
import 'login.dart';
import 'navable_design.dart';
import 'locations_api.dart';
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
part 'widgets/open_street_map_view.dart';

enum _ProfilePhotoAction { camera, gallery, remove }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.isGuest = false});

  final bool isGuest;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _exploreSearchController =
      TextEditingController();
  int _selectedIndex = 0;
  AccessibleLocation? _pendingPhotoLocation;
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
  bool _voiceGuidance = true;
  bool _routing = false;
  PlannedRoute? _walkingRoute;
  String? _routeStatus;
  TravelMode _travelMode = TravelMode.walking;
  final Map<TravelMode, double> _routeDurations = {};
  int _routeEstimateGeneration = 0;
  bool _destinationSelected = false;
  List<PlaceSearchResult> _placeSearchResults = const [];
  PlaceSearchResult? _searchedPlace;
  bool _placeSearching = false;

  final List<SavedPlace> _savedPlaces = [];

  final List<AccessReport> _reports = [];

  final List<AccessibilitySubmission> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadAccessibleLocations();
    _loadProfileStats();
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

  Future<void> _loadAccessibleLocations() async {
    try {
      final locations = await LocationsApi.getAccessibleLocations();
      if (!mounted) return;
      setState(() {
        _accessibleLocations = locations;
        _selectedMapLocation = locations.isEmpty ? null : locations.first;
        _locationsLoading = false;
        _locationsError = null;
      });
    } on LocationsApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _locationsLoading = false;
        _locationsError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationsLoading = false;
        _locationsError = 'Could not load accessible locations from Firestore.';
      });
    }
  }

  @override
  void dispose() {
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
      _pendingPhotoLocation = location;
      if (location != null) _selectedMapLocation = location;
      if (openCamera) _photoCaptureRequestId++;
      _selectedIndex = 2;
    });
  }

  void _openReportsTab() {
    if (widget.isGuest) {
      _showMessage('Sign in to view and submit reports.');
      return;
    }
    setState(() => _selectedIndex = 2);
  }

  void _selectMapLocation(AccessibleLocation location) {
    setState(() {
      _selectedMapLocation = location;
      _destinationController.text = location.name;
      _destinationSelected = true;
      _searchedPlace = null;
      _walkingRoute = null;
      _routeStatus = null;
      _routeDurations.clear();
      _routeEstimateGeneration++;
    });
  }

  void _onDestinationChanged(String value) {
    if (!_destinationSelected) return;
    final selectedName = _searchedPlace?.name ?? _selectedMapLocation?.name;
    if (value.trim() == selectedName) return;
    setState(() {
      _destinationSelected = false;
      _searchedPlace = null;
      _placeSearchResults = const [];
      _walkingRoute = null;
      _routeStatus = null;
      _routeDurations.clear();
      _routeEstimateGeneration++;
    });
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
    final estimateGeneration = ++_routeEstimateGeneration;

    setState(() {
      _routing = true;
      _walkingRoute = null;
      _routeDurations.clear();
      _routeStatus =
          'Finding a ${_travelMode.label.toLowerCase()} route to $destination…';
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
        mode: _travelMode,
        selectedPlace: _searchedPlace,
      );
      if (!mounted) return;
      setState(() {
        _walkingRoute = route;
        _routeStatus = route.summary;
        _storeRouteDuration(route);
        if (route.savedLocation != null) {
          _selectedMapLocation = route.savedLocation;
        }
      });
      unawaited(_loadAlternativeRouteEstimates(route, estimateGeneration));
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
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _placeSearching = true;
      _placeSearchResults = const [];
      _routeStatus = null;
    });
    try {
      final mapResults = await RoutePlannerApi.searchPlaces(
        query: query,
        near: _searchedPlace?.point ?? _cebuMapCenter,
      );
      if (!mounted) return;
      final normalizedQuery = query.toLowerCase();
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
            ),
          );
      final resultNames = <String>{};
      final results = <PlaceSearchResult>[
        for (final place in [...accessibleResults, ...mapResults])
          if (resultNames.add(place.name.toLowerCase())) place,
      ];
      setState(() => _placeSearchResults = results);
      if (results.isEmpty) _showMessage('No places found. Try a more specific search.');
    } on RoutePlannerException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Could not search places. Please try again.');
    } finally {
      if (mounted) setState(() => _placeSearching = false);
    }
  }

  void _selectSearchedPlace(PlaceSearchResult place) {
    _routeEstimateGeneration++;
    setState(() {
      _searchedPlace = place;
      _destinationController.text = place.name;
      _placeSearchResults = const [];
      _walkingRoute = null;
      _routeStatus = place.displayName;
      _destinationSelected = true;
      _routeDurations.clear();
    });
    FocusManager.instance.primaryFocus?.unfocus();
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
        builder: (context) => RouteDetailsScreen(
          route: route,
          onModeChanged: _changeRouteMode,
        ),
      ),
    );
  }

  Future<PlannedRoute> _changeRouteMode(
    PlannedRoute currentRoute,
    TravelMode mode,
  ) async {
    _routeEstimateGeneration++;
    setState(() {
      _travelMode = mode;
      _routing = true;
      _routeStatus = 'Finding a ${mode.label.toLowerCase()} route…';
    });
    try {
      final savedLocations = currentRoute.savedLocation == null
          ? const <AccessibleLocation>[]
          : [currentRoute.savedLocation!];
      final route = await RoutePlannerApi.planRoute(
        query: currentRoute.destinationName,
        origin: currentRoute.origin,
        savedLocations: savedLocations,
        mode: mode,
        selectedPlace: PlaceSearchResult(
          name: currentRoute.destinationName,
          displayName: currentRoute.destinationName,
          point: currentRoute.destination,
        ),
      );
      if (!mounted) return route;
      setState(() {
        _walkingRoute = route;
        _routeStatus = route.summary;
        _storeRouteDuration(route);
      });
      return route;
    } on RoutePlannerException catch (error) {
      if (mounted) {
        setState(() {
          _travelMode = currentRoute.mode;
          _routeStatus = error.message;
        });
      }
      rethrow;
    } catch (error) {
      if (mounted) {
        setState(() {
          _travelMode = currentRoute.mode;
          _routeStatus = 'Could not calculate this route: $error';
        });
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  void _storeRouteDuration(PlannedRoute route) {
    _routeDurations[route.mode] = route.durationSeconds;
    if (route.mode == TravelMode.car ||
        route.mode == TravelMode.motorcycle) {
      _routeDurations[TravelMode.car] = route.durationSeconds;
      _routeDurations[TravelMode.motorcycle] = route.durationSeconds;
    }
  }

  Future<void> _loadAlternativeRouteEstimates(
    PlannedRoute route,
    int generation,
  ) async {
    const estimateModes = [TravelMode.walking, TravelMode.car];
    for (final mode in estimateModes) {
      if (mode == route.mode ||
          (mode == TravelMode.car && route.mode == TravelMode.motorcycle)) {
        continue;
      }
      try {
        final estimate = await RoutePlannerApi.planRoute(
          query: route.destinationName,
          origin: route.origin,
          savedLocations: route.savedLocation == null
              ? const <AccessibleLocation>[]
              : [route.savedLocation!],
          mode: mode,
          selectedPlace: PlaceSearchResult(
            name: route.destinationName,
            displayName: route.destinationName,
            point: route.destination,
          ),
        );
        if (!mounted || generation != _routeEstimateGeneration) return;
        setState(() => _storeRouteDuration(estimate));
      } catch (_) {
        // Keep showing estimates for modes that have already loaded.
      }
    }
  }

  Future<void> _selectMapRouteMode(TravelMode mode) async {
    final route = _walkingRoute;
    if (route == null || route.mode == mode || _routing) return;
    try {
      await _changeRouteMode(route, mode);
    } on Exception catch (error) {
      if (mounted) _showMessage(error.toString());
    }
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
        builder: (context) => Scaffold(
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
    );
  }

  void _editProfile() {
    final user = AuthService.currentUser;
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
                        final result = await AuthService.updateProfile(
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
        location: report.location,
        locationId: report.locationId,
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
    final user = AuthService.currentUser;
    final pages = <Widget>[
      _PlanPage(
        isGuest: widget.isGuest,
        accessibleLocations: _accessibleLocations,
        locationsLoading: _locationsLoading,
        locationsError: _locationsError,
        selectedLocation: _selectedMapLocation,
        destinationController: _destinationController,
        placeSearchResults: _placeSearchResults,
        placeSearching: _placeSearching,
        searchedPlace: _searchedPlace,
        routeStatus: _routeStatus,
        walkingRoute: _walkingRoute,
        routing: _routing,
        travelMode: _travelMode,
        routeDurations: _routeDurations,
        destinationSelected: _destinationSelected,
        avoidStairs: _avoidStairs,
        prioritizeElevators: _prioritizeElevators,
        accessibleEntrance: _accessibleEntrance,
        accessibleToilet: _accessibleToilet,
        tactilePaving: _tactilePaving,
        audioAssistance: _audioAssistance,
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
        onPlanRoute: _planRoute,
        onRouteModeSelected: _selectMapRouteMode,
        onDestinationChanged: _onDestinationChanged,
        onSearchPlaces: _searchPlaces,
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
            await AuthService.signOut();
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
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
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
    return Scaffold(
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
    );
  }
}

class RouteDetailsScreen extends StatefulWidget {
  const RouteDetailsScreen({
    super.key,
    required this.route,
    required this.onModeChanged,
  });

  final PlannedRoute route;
  final Future<PlannedRoute> Function(PlannedRoute, TravelMode) onModeChanged;

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  late PlannedRoute _route;
  bool _changingMode = false;

  @override
  void initState() {
    super.initState();
    _route = widget.route;
  }

  Future<void> _selectMode(TravelMode mode) async {
    if (_changingMode || mode == _route.mode) return;
    setState(() => _changingMode = true);
    try {
      final updatedRoute = await widget.onModeChanged(_route, mode);
      if (mounted) setState(() => _route = updatedRoute);
    } catch (error) {
      if (!mounted) return;
      final message = error is RoutePlannerException
          ? error.message
          : 'Could not calculate this route. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _changingMode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    return Scaffold(
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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Travel mode',
                          style: TextStyle(
                            color: kNavAbleNavy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_changingMode)
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<TravelMode>(
                      segments: const [
                        ButtonSegment(
                          value: TravelMode.walking,
                          icon: Icon(Icons.directions_walk_rounded),
                          label: Text('Walk'),
                        ),
                        ButtonSegment(
                          value: TravelMode.car,
                          icon: Icon(Icons.directions_car_rounded),
                          label: Text('Car'),
                        ),
                        ButtonSegment(
                          value: TravelMode.motorcycle,
                          icon: Icon(Icons.motorcycle_rounded),
                          label: Text('Motorcycle'),
                        ),
                      ],
                      selected: {route.mode},
                      onSelectionChanged: _changingMode
                          ? null
                          : (selection) => _selectMode(selection.first),
                      showSelectedIcon: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
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

    return Scaffold(
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
                              for (final detection in widget.report.detections)
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
                      label: Text(_confirmed ? 'Confirmed' : 'Confirm Report'),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    return Scaffold(
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
                      DropdownMenuItem(value: 'Custom', child: Text('Custom')),
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
