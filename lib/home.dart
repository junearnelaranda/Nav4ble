import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';
import 'login.dart';
import 'navable_design.dart';
import 'welcome.dart';

part 'screens/home_tab.dart';
part 'screens/explore_tab.dart';
part 'screens/reports_tab.dart';
part 'screens/alerts_tab.dart';
part 'screens/profile_tab.dart';
part 'screens/settings_screen.dart';
part 'screens/submissions_screen.dart';

enum _ProfilePhotoAction { camera, gallery, remove }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _exploreSearchController = TextEditingController(
    text: 'Cafe near Ayala Center Cebu',
  );
  int _selectedIndex = 0;
  bool _avoidStairs = true;
  bool _prioritizeElevators = false;
  final bool _showVerifiedOnly = true;
  bool _accessibleEntrance = false;
  bool _accessibleToilet = false;
  bool _tactilePaving = false;
  bool _audioAssistance = false;
  bool _voiceGuidance = true;
  String? _routeStatus;

  final List<SavedPlace> _savedPlaces = [
    const SavedPlace(
      name: 'Central Station',
      address: 'North accessible entrance',
      tag: 'Transit',
    ),
    const SavedPlace(
      name: 'City Hall Plaza',
      address: 'Step-free route via east path',
      tag: 'Civic',
    ),
  ];

  final List<AccessReport> _reports = [
    const AccessReport(
      title: 'Central Station north entrance',
      detail: 'Ramp open, elevator verified 12 min ago.',
      category: 'Verified',
      icon: Icons.check_circle_outline,
    ),
    const AccessReport(
      title: 'Market Street crossing',
      detail: 'Temporary curb repair. Use west crossing.',
      category: 'Barrier',
      icon: Icons.warning_amber_rounded,
    ),
    const AccessReport(
      title: 'City Hall plaza',
      detail: 'Smooth route confirmed by 4 riders today.',
      category: 'Route',
      icon: Icons.accessible_forward_rounded,
    ),
  ];

  final List<AccessibilitySubmission> _submissions = const [
    AccessibilitySubmission(
      title: 'Central Station Elevator',
      submittedOn: 'Oct 24, 2023',
      status: SubmissionStatus.pending,
      statusDetail: 'Reviewing Details',
      icon: Icons.accessible_forward_rounded,
    ),
    AccessibilitySubmission(
      title: 'Public Library Ramp',
      submittedOn: 'Oct 22, 2023',
      status: SubmissionStatus.pending,
      statusDetail: 'Wait time: ~2 days',
      icon: Icons.ramp_right_rounded,
    ),
    AccessibilitySubmission(
      title: 'Main Street Ramp',
      submittedOn: 'Oct 18, 2023',
      status: SubmissionStatus.approved,
      statusDetail: 'Verified by the community',
      icon: Icons.accessible_forward_rounded,
    ),
    AccessibilitySubmission(
      title: 'City Hall Entrance',
      submittedOn: 'Oct 15, 2023',
      status: SubmissionStatus.approved,
      statusDetail: 'Accessible entrance confirmed',
      icon: Icons.door_front_door_outlined,
    ),
    AccessibilitySubmission(
      title: 'Ayala Center Elevator',
      submittedOn: 'Oct 12, 2023',
      status: SubmissionStatus.approved,
      statusDetail: 'Elevator access confirmed',
      icon: Icons.elevator_outlined,
    ),
    AccessibilitySubmission(
      title: 'Cebu IT Park Curb Cut',
      submittedOn: 'Oct 10, 2023',
      status: SubmissionStatus.approved,
      statusDetail: 'Step-free route verified',
      icon: Icons.route_outlined,
    ),
    AccessibilitySubmission(
      title: 'Bus Terminal Accessible Toilet',
      submittedOn: 'Oct 8, 2023',
      status: SubmissionStatus.approved,
      statusDetail: 'Facility details confirmed',
      icon: Icons.wc_rounded,
    ),
    AccessibilitySubmission(
      title: 'Museum Step-Free Entrance',
      submittedOn: 'Oct 5, 2023',
      status: SubmissionStatus.approved,
      statusDetail: 'Entrance information verified',
      icon: Icons.meeting_room_outlined,
    ),
    AccessibilitySubmission(
      title: 'Fuente Osmeña Crossing',
      submittedOn: 'Oct 2, 2023',
      status: SubmissionStatus.approved,
      statusDetail: 'Crossing route confirmed',
      icon: Icons.signpost_outlined,
    ),
    AccessibilitySubmission(
      title: 'Pier 1 Tactile Paving',
      submittedOn: 'Sep 29, 2023',
      status: SubmissionStatus.approved,
      statusDetail: 'Tactile path verified',
      icon: Icons.blind_outlined,
    ),
    AccessibilitySubmission(
      title: 'Oak Library Entrance',
      submittedOn: 'Sep 26, 2023',
      status: SubmissionStatus.rejected,
      statusDetail: 'A clearer photo is required',
      icon: Icons.photo_camera_outlined,
    ),
    AccessibilitySubmission(
      title: 'Downtown Audio Beacon',
      submittedOn: 'Sep 24, 2023',
      status: SubmissionStatus.rejected,
      statusDetail: 'Location details were incomplete',
      icon: Icons.hearing_rounded,
    ),
  ];

  @override
  void dispose() {
    _destinationController.dispose();
    _exploreSearchController.dispose();
    super.dispose();
  }

  void _planRoute() {
    final destination = _destinationController.text.trim();

    setState(() {
      if (destination.isEmpty) {
        _routeStatus = 'Enter a destination to start routing.';
        return;
      }

      final filters = <String>[
        if (_avoidStairs) 'stairs avoided',
        if (_prioritizeElevators) 'elevators prioritized',
        if (_showVerifiedOnly) 'verified paths only',
      ].join(', ');
      _routeStatus =
          'Route to $destination ready: 1.2 mi, 18 min, step-free. $filters.';
    });
  }

  void _saveDestination() {
    final destination = _destinationController.text.trim();

    if (destination.isEmpty) {
      _showMessage('Enter a destination before saving it.');
      return;
    }

    final exists = _savedPlaces.any(
      (place) => place.name.toLowerCase() == destination.toLowerCase(),
    );
    if (exists) {
      _showMessage('$destination is already saved.');
      return;
    }

    setState(() {
      _savedPlaces.insert(
        0,
        SavedPlace(
          name: destination,
          address: 'Saved from route planner',
          tag: 'Custom',
        ),
      );
    });
    _showMessage('$destination saved.');
  }

  void _useSavedPlace(SavedPlace place) {
    setState(() {
      _destinationController.text = place.name;
      _selectedIndex = 0;
    });
    _planRoute();
  }

  void _deleteSavedPlace(SavedPlace place) {
    setState(() => _savedPlaces.remove(place));
    _showMessage('${place.name} removed from saved places.');
  }

  void _openRouteDetails() {
    if (_routeStatus == null) {
      _showMessage('Plan a route first.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RouteDetailsScreen(
          destination: _destinationController.text.trim(),
          status: _routeStatus!,
          avoidStairs: _avoidStairs,
          prioritizeElevators: _prioritizeElevators,
          showVerifiedOnly: _showVerifiedOnly,
        ),
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
                      onPressed: () {
                        final result = AuthService.updateProfile(
                          fullName: nameController.text,
                          email: emailController.text,
                          profileImageBytes: selectedPhoto,
                        );
                        if (!result.isSuccess) {
                          _showMessage(
                            result.message ?? 'Profile update failed.',
                          );
                          return;
                        }

                        setState(() {});
                        Navigator.of(sheetContext).pop();
                        _showMessage('Profile updated locally.');
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

  void _openReportSheet() {
    final locationController = TextEditingController();
    final detailController = TextEditingController();
    String category = 'Barrier';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Accessibility Update',
                    style: TextStyle(
                      color: kNavAbleNavy,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InputField(
                    controller: locationController,
                    hintText: 'Location or place name',
                    icon: Icons.place_outlined,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: _fieldDecoration(
                      hintText: 'Category',
                      icon: Icons.category_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Barrier',
                        child: Text('Barrier'),
                      ),
                      DropdownMenuItem(value: 'Ramp', child: Text('Ramp')),
                      DropdownMenuItem(
                        value: 'Elevator',
                        child: Text('Elevator'),
                      ),
                      DropdownMenuItem(value: 'Route', child: Text('Route')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => category = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _InputField(
                    controller: detailController,
                    hintText: 'What should other users know?',
                    icon: Icons.notes_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: NavAbleSize.control,
                    child: FilledButton.icon(
                      onPressed: () {
                        final location = locationController.text.trim();
                        final detail = detailController.text.trim();
                        if (location.isEmpty || detail.isEmpty) {
                          _showMessage('Add a location and report detail.');
                          return;
                        }

                        setState(() {
                          _reports.insert(
                            0,
                            AccessReport(
                              title: location,
                              detail: detail,
                              category: category,
                              icon: _iconForCategory(category),
                            ),
                          );
                        });
                        Navigator.of(context).pop();
                        _showMessage('Accessibility report added locally.');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: kNavAbleNavy,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Add Report'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      locationController.dispose();
      detailController.dispose();
    });
  }

  void _submitReport(AccessReport report) {
    setState(() {
      _reports.insert(0, report);
      _submissions.insert(
        0,
        AccessibilitySubmission(
          title: report.title,
          submittedOn: 'Today',
          status: SubmissionStatus.pending,
          statusDetail: 'Reviewing Details',
          icon: report.icon,
        ),
      );
    });
    _showMessage(
      'Report submitted locally. Thank you for helping the community.',
    );
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

  IconData _iconForCategory(String category) {
    return switch (category) {
      'Barrier' => Icons.warning_amber_rounded,
      'Ramp' => Icons.accessible_forward_rounded,
      'Elevator' => Icons.elevator,
      _ => Icons.route_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final pages = [
      _PlanPage(
        destinationController: _destinationController,
        routeStatus: _routeStatus,
        avoidStairs: _avoidStairs,
        prioritizeElevators: _prioritizeElevators,
        accessibleEntrance: _accessibleEntrance,
        accessibleToilet: _accessibleToilet,
        tactilePaving: _tactilePaving,
        audioAssistance: _audioAssistance,
        reports: _reports,
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
        onOpenRouteDetails: _openRouteDetails,
        onSaveDestination: _saveDestination,
        onReportBarrier: _openReportSheet,
        onOpenSaved: _openSavedPlaces,
        onOpenFilters: _openAccessibilityFilters,
      ),
      _ExplorePage(searchController: _exploreSearchController),
      _ReportsPage(
        reports: _reports,
        onSubmitReport: _submitReport,
        onOpenReport: _openReportDetails,
      ),
      _AlertsPage(reports: _reports, onOpenReport: _openReportDetails),
      _ProfilePage(
        user: user,
        contributionPoints: 124,
        reportCount: _submissions.length,
        savedPlaceCount: _savedPlaces.length,
        submissions: _submissions,
        voiceGuidance: _voiceGuidance,
        onVoiceGuidanceChanged: (value) =>
            setState(() => _voiceGuidance = value),
        onEditProfile: _editProfile,
        onOpenInfo: _openInfoPage,
        onSignOut: () {
          AuthService.signOut();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (context) => const WelcomeScreen(),
            ),
            (route) => false,
          );
        },
      ),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
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
    required this.title,
    required this.detail,
    required this.category,
    required this.icon,
    this.confirmations = 0,
  });

  final String title;
  final String detail;
  final String category;
  final IconData icon;
  final int confirmations;

  AccessReport copyWith({
    String? title,
    String? detail,
    String? category,
    IconData? icon,
    int? confirmations,
  }) {
    return AccessReport(
      title: title ?? this.title,
      detail: detail ?? this.detail,
      category: category ?? this.category,
      icon: icon ?? this.icon,
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

class RouteDetailsScreen extends StatelessWidget {
  const RouteDetailsScreen({
    super.key,
    required this.destination,
    required this.status,
    required this.avoidStairs,
    required this.prioritizeElevators,
    required this.showVerifiedOnly,
  });

  final String destination;
  final String status;
  final bool avoidStairs;
  final bool prioritizeElevators;
  final bool showVerifiedOnly;

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Start from the nearest accessible entrance.',
      if (avoidStairs) 'Continue using the marked step-free walkway.',
      if (prioritizeElevators) 'Use the elevator bank near the main lobby.',
      'Cross at the curb-cut crossing on the right.',
      if (showVerifiedOnly) 'Follow the peer-verified ramp access segment.',
      'Arrive at $destination through the accessible entrance.',
    ];

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
                  Text(
                    destination.isEmpty ? 'Accessible Route' : destination,
                    style: const TextStyle(
                      color: kNavAbleNavy,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status,
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
                  const Text(
                    'Step-Free Directions',
                    style: TextStyle(
                      color: kNavAbleNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var index = 0; index < steps.length; index++)
                    _InstructionStep(number: index + 1, text: steps[index]),
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
            style: const TextStyle(
              color: kNavAbleNavy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kNavAbleText,
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
      color: NavAblePalette.surface,
      child: child,
    );
  }
}
