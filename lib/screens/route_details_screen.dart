part of '../home.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), elevation: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Panel(
              child: Text(
                body,
                style: TextStyle(
                  color: context.navAbleSecondaryText,
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
  const RouteDetailsScreen({super.key, required this.route});

  final PlannedRoute route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Details'), elevation: 0),
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
                    style: TextStyle(
                      color: context.navAblePrimaryText,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${route.summary}\n${route.mode.label} route estimate from OpenStreetMap.',
                    style: TextStyle(
                      color: context.navAbleSecondaryText,
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
                      color: context.navAblePrimaryText,
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
                      color: context.navAbleSecondaryText,
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
              style: TextStyle(
                color: context.navAbleSecondaryText,
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
