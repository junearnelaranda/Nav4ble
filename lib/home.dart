import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'login.dart';
import 'welcome.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _destinationController = TextEditingController();
  int _selectedIndex = 0;
  bool _avoidStairs = true;
  bool _prioritizeElevators = true;
  bool _showVerifiedOnly = true;
  bool _voiceGuidance = true;
  bool _highContrastRoutes = false;
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

  @override
  void dispose() {
    _destinationController.dispose();
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

  void _editProfile() {
    final user = AuthService.currentUser;
    final nameController = TextEditingController(text: user?.fullName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
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
                'Edit Profile',
                style: TextStyle(
                  color: kNavAbleNavy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 16),
              _InputField(
                controller: nameController,
                hintText: 'Full name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              _InputField(
                controller: emailController,
                hintText: 'Email address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    final result = AuthService.updateProfile(
                      fullName: nameController.text,
                      email: emailController.text,
                    );
                    if (!result.isSuccess) {
                      _showMessage(result.message ?? 'Profile update failed.');
                      return;
                    }

                    setState(() {});
                    Navigator.of(context).pop();
                    _showMessage('Profile updated locally.');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kNavAbleNavy,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Profile'),
                ),
              ),
            ],
          ),
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
                    value: category,
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
                    height: 52,
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

  void _openInfoPage(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => InfoScreen(title: title, body: body),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        userName: user?.fullName ?? 'Traveler',
        destinationController: _destinationController,
        routeStatus: _routeStatus,
        avoidStairs: _avoidStairs,
        prioritizeElevators: _prioritizeElevators,
        showVerifiedOnly: _showVerifiedOnly,
        reports: _reports,
        onAvoidStairsChanged: (value) => setState(() => _avoidStairs = value),
        onPrioritizeElevatorsChanged: (value) =>
            setState(() => _prioritizeElevators = value),
        onShowVerifiedOnlyChanged: (value) =>
            setState(() => _showVerifiedOnly = value),
        onPlanRoute: _planRoute,
        onOpenRouteDetails: _openRouteDetails,
        onSaveDestination: _saveDestination,
        onReportBarrier: _openReportSheet,
      ),
      _ReportsPage(
        reports: _reports,
        onAddReport: _openReportSheet,
        onOpenReport: _openReportDetails,
      ),
      _SavedPage(
        savedPlaces: _savedPlaces,
        onUsePlace: _useSavedPlace,
        onDeletePlace: _deleteSavedPlace,
        onOpenPlace: _openSavedPlaceDetails,
      ),
      _ProfilePage(
        user: user,
        voiceGuidance: _voiceGuidance,
        highContrastRoutes: _highContrastRoutes,
        onVoiceGuidanceChanged: (value) =>
            setState(() => _voiceGuidance = value),
        onHighContrastRoutesChanged: (value) =>
            setState(() => _highContrastRoutes = value),
        onEditProfile: _editProfile,
        onOpenInfo: _openInfoPage,
        onSignOut: () {
          AuthService.signOut();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        },
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        title: const Text('NavAble'),
        backgroundColor: Colors.white,
        foregroundColor: kNavAbleNavy,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Help',
            onPressed: () => _openInfoPage(
              'Help Center',
              'This Flutter-only prototype includes local route planning, saved places, reports, and profile preferences. Live maps, AI routing, and cloud sync will be connected later.',
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        indicatorColor: kNavAbleAccent,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Saved',
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

class _PlanPage extends StatelessWidget {
  const _PlanPage({
    required this.userName,
    required this.destinationController,
    required this.routeStatus,
    required this.avoidStairs,
    required this.prioritizeElevators,
    required this.showVerifiedOnly,
    required this.reports,
    required this.onAvoidStairsChanged,
    required this.onPrioritizeElevatorsChanged,
    required this.onShowVerifiedOnlyChanged,
    required this.onPlanRoute,
    required this.onOpenRouteDetails,
    required this.onSaveDestination,
    required this.onReportBarrier,
  });

  final String userName;
  final TextEditingController destinationController;
  final String? routeStatus;
  final bool avoidStairs;
  final bool prioritizeElevators;
  final bool showVerifiedOnly;
  final List<AccessReport> reports;
  final ValueChanged<bool> onAvoidStairsChanged;
  final ValueChanged<bool> onPrioritizeElevatorsChanged;
  final ValueChanged<bool> onShowVerifiedOnlyChanged;
  final VoidCallback onPlanRoute;
  final VoidCallback onOpenRouteDetails;
  final VoidCallback onSaveDestination;
  final VoidCallback onReportBarrier;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Text(
          'Hello, $userName',
          style: const TextStyle(
            color: kNavAbleNavy,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Plan a step-free route with accessibility checks before you go.',
          style: TextStyle(
            color: kNavAbleText,
            fontSize: 14,
            height: 1.45,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 20),
        _RoutePlannerCard(
          destinationController: destinationController,
          routeStatus: routeStatus ?? 'Ready to plan an accessible route.',
          avoidStairs: avoidStairs,
          prioritizeElevators: prioritizeElevators,
          showVerifiedOnly: showVerifiedOnly,
          onAvoidStairsChanged: onAvoidStairsChanged,
          onPrioritizeElevatorsChanged: onPrioritizeElevatorsChanged,
          onShowVerifiedOnlyChanged: onShowVerifiedOnlyChanged,
          onPlanRoute: onPlanRoute,
          onOpenRouteDetails: onOpenRouteDetails,
        ),
        const SizedBox(height: 18),
        const _MapPreview(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.report_problem_outlined,
                label: 'Report Barrier',
                onPressed: onReportBarrier,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.place_outlined,
                label: 'Save Place',
                onPressed: onSaveDestination,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ReportsPreview(reports: reports.take(3).toList()),
      ],
    );
  }
}

class _ReportsPage extends StatelessWidget {
  const _ReportsPage({
    required this.reports,
    required this.onAddReport,
    required this.onOpenReport,
  });

  final List<AccessReport> reports;
  final VoidCallback onAddReport;
  final ValueChanged<AccessReport> onOpenReport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        _SectionHeader(
          title: 'Accessibility Reports',
          actionLabel: 'Add',
          onAction: onAddReport,
        ),
        const SizedBox(height: 14),
        for (final report in reports)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReportCard(
              report: report,
              onTap: () => onOpenReport(report),
            ),
          ),
      ],
    );
  }
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
        const Text(
          'Saved Places',
          style: TextStyle(
            color: kNavAbleNavy,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 14),
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

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.user,
    required this.voiceGuidance,
    required this.highContrastRoutes,
    required this.onVoiceGuidanceChanged,
    required this.onHighContrastRoutesChanged,
    required this.onEditProfile,
    required this.onOpenInfo,
    required this.onSignOut,
  });

  final NavAbleUser? user;
  final bool voiceGuidance;
  final bool highContrastRoutes;
  final ValueChanged<bool> onVoiceGuidanceChanged;
  final ValueChanged<bool> onHighContrastRoutesChanged;
  final VoidCallback onEditProfile;
  final void Function(String title, String body) onOpenInfo;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        _Panel(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: kNavAbleAccent,
                child: Icon(Icons.person_rounded, color: kNavAbleGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Traveler',
                      style: const TextStyle(
                        color: kNavAbleNavy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'Local demo account',
                      style: const TextStyle(
                        color: kNavAbleText,
                        fontSize: 13,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit profile',
                onPressed: onEditProfile,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Accessibility Preferences',
                style: TextStyle(
                  color: kNavAbleNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              _SwitchRow(
                label: 'Voice guidance',
                value: voiceGuidance,
                onChanged: onVoiceGuidanceChanged,
              ),
              _SwitchRow(
                label: 'High contrast routes',
                value: highContrastRoutes,
                onChanged: onHighContrastRoutesChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ProfileLink(
          icon: Icons.support_agent_rounded,
          label: 'Accessibility Support',
          onTap: () => onOpenInfo(
            'Accessibility Support',
            'Support contact tools are ready as Flutter screens. A real support email, chat, or ticketing service can be connected later.',
          ),
        ),
        _ProfileLink(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          onTap: () => onOpenInfo(
            'Privacy Policy',
            'This front-end prototype stores account, report, and saved-place data only in memory while the app is running.',
          ),
        ),
        _ProfileLink(
          icon: Icons.description_outlined,
          label: 'Terms of Service',
          onTap: () => onOpenInfo(
            'Terms of Service',
            'These placeholder terms are included so the app navigation is complete before production legal text is added.',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: onSignOut,
            style: OutlinedButton.styleFrom(
              foregroundColor: kNavAbleNavy,
              side: const BorderSide(color: Color(0xFFDDE5DF), width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: Colors.white,
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'Sign Out',
              style: TextStyle(fontWeight: FontWeight.w800),
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
    final confirmations =
        widget.report.confirmations + (_confirmed ? 1 : 0);

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
                    height: 52,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a name and address.')),
      );
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
                    value: _tag,
                    decoration: _fieldDecoration(
                      hintText: 'Tag',
                      icon: Icons.label_outline,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Home', child: Text('Home')),
                      DropdownMenuItem(value: 'Work', child: Text('Work')),
                      DropdownMenuItem(value: 'Transit', child: Text('Transit')),
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

class _RoutePlannerCard extends StatelessWidget {
  const _RoutePlannerCard({
    required this.destinationController,
    required this.routeStatus,
    required this.avoidStairs,
    required this.prioritizeElevators,
    required this.showVerifiedOnly,
    required this.onAvoidStairsChanged,
    required this.onPrioritizeElevatorsChanged,
    required this.onShowVerifiedOnlyChanged,
    required this.onPlanRoute,
    required this.onOpenRouteDetails,
  });

  final TextEditingController destinationController;
  final String routeStatus;
  final bool avoidStairs;
  final bool prioritizeElevators;
  final bool showVerifiedOnly;
  final ValueChanged<bool> onAvoidStairsChanged;
  final ValueChanged<bool> onPrioritizeElevatorsChanged;
  final ValueChanged<bool> onShowVerifiedOnlyChanged;
  final VoidCallback onPlanRoute;
  final VoidCallback onOpenRouteDetails;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route Planner',
            style: TextStyle(
              color: kNavAbleNavy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          _InputField(
            controller: destinationController,
            hintText: 'Where are you going?',
            icon: Icons.search_rounded,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onPlanRoute(),
          ),
          const SizedBox(height: 12),
          _SwitchRow(
            label: 'Avoid stairs',
            value: avoidStairs,
            onChanged: onAvoidStairsChanged,
          ),
          _SwitchRow(
            label: 'Prioritize elevators',
            value: prioritizeElevators,
            onChanged: onPrioritizeElevatorsChanged,
          ),
          _SwitchRow(
            label: 'Peer-verified only',
            value: showVerifiedOnly,
            onChanged: onShowVerifiedOnlyChanged,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onPlanRoute,
              style: FilledButton.styleFrom(
                backgroundColor: kNavAbleNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.route_rounded),
              label: const Text(
                'Plan Accessible Route',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            routeStatus,
            style: const TextStyle(
              color: kNavAbleText,
              fontSize: 13,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          if (!routeStatus.startsWith('Ready') &&
              !routeStatus.startsWith('Enter')) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onOpenRouteDetails,
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('View Route Details'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        dense: true,
        activeColor: kNavAbleGreen,
        title: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF344054),
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
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

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapPainter())),
            const Positioned(
              top: 12,
              left: 12,
              child: _MapBadge(icon: Icons.accessible, label: 'Ramp'),
            ),
            const Positioned(
              right: 12,
              bottom: 12,
              child: _MapBadge(icon: Icons.elevator, label: 'Elevator'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final streetPaint = Paint()
      ..color = const Color(0xFFDDE5DF)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final routePaint = Paint()
      ..color = kNavAbleGreen
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = kNavAbleNavy;

    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.72),
      Offset(size.width * 0.92, size.height * 0.24),
      streetPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.26),
      Offset(size.width * 0.86, size.height * 0.76),
      streetPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.68),
      Offset(size.width * 0.78, size.height * 0.33),
      routePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.14, size.height * 0.68),
      8,
      pointPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.33),
      8,
      pointPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE5DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kNavAbleGreen, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: kNavAbleNavy,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsPreview extends StatelessWidget {
  const _ReportsPreview({required this.reports});

  final List<AccessReport> reports;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nearby Accessibility Reports',
            style: TextStyle(
              color: kNavAbleNavy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          for (final report in reports) _ReportTile(report: report),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: kNavAbleNavy,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onAction,
          style: FilledButton.styleFrom(
            backgroundColor: kNavAbleNavy,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Panel(
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Icon(icon, color: kNavAbleGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: kNavAbleNavy,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kNavAbleText),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: kNavAbleNavy,
          side: const BorderSide(color: Color(0xFFDDE5DF), width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
        ),
        icon: Icon(icon, color: kNavAbleGreen),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
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
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E8E2)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kNavAbleNavy.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
