part of '../home.dart';

/// Top Contributors: This month and All-time rankings, the top 20, and the
/// signed-in user's own rank pinned at the bottom.
class _LeaderboardScreen extends StatefulWidget {
  const _LeaderboardScreen({required this.isGuest});

  final bool isGuest;

  @override
  State<_LeaderboardScreen> createState() => _LeaderboardScreenState();
}

typedef _LeaderboardData = ({List<LeaderboardEntry> entries, MyStanding? me});

class _LeaderboardScreenState extends State<_LeaderboardScreen> {
  LeaderboardPeriod _period = LeaderboardPeriod.month;
  final Map<LeaderboardPeriod, _LeaderboardData> _data = {};
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final period = _period;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final entries = PointsApi.leaderboard(period);
      final me = widget.isGuest
          ? Future<MyStanding?>.value()
          : PointsApi.myStanding(period);
      final data = (entries: await entries, me: await me);
      if (!mounted) return;
      setState(() => _data[period] = data);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _choose(LeaderboardPeriod period) {
    if (period == _period) return;
    setState(() => _period = period);
    if (!_data.containsKey(period)) _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data[_period];
    return Scaffold(
      appBar: AppBar(title: const Text('Top Contributors')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<LeaderboardPeriod>(
                  segments: const [
                    ButtonSegment(
                      value: LeaderboardPeriod.month,
                      label: Text('This month'),
                    ),
                    ButtonSegment(
                      value: LeaderboardPeriod.all,
                      label: Text('All-time'),
                    ),
                  ],
                  selected: {_period},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => _choose(selection.first),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _list(context, data),
              ),
            ),
            if (data?.me case final me? when me.rank != null)
              _MyRankBar(standing: me, name: 'You'),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, _LeaderboardData? data) {
    Widget message(String text, {bool retry = false}) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        Icon(
          retry ? Icons.cloud_off_rounded : Icons.emoji_events_outlined,
          size: 44,
          color: context.navAbleSecondaryText,
        ),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.navAbleSecondaryText, fontSize: 15),
        ),
        if (retry) ...[
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      ],
    );

    if (data == null) {
      if (_failed) return message("Couldn't load the leaderboard", retry: true);
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (data.entries.isEmpty) {
      return message(
        _period == LeaderboardPeriod.month
            ? 'No contributions yet this month. Be the first!'
            : 'No contributions yet. Be the first!',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: data.entries.length + (_loading ? 1 : 0),
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: context.navAbleSecondaryText.withValues(alpha: 0.15),
      ),
      itemBuilder: (context, index) {
        if (index == data.entries.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: LinearProgressIndicator()),
          );
        }
        return _LeaderboardRow(entry: data.entries[index]);
      },
    );
  }
}

/// Gold, silver and bronze for the top three.
const _medalColors = [Color(0xFFE0A526), Color(0xFF9AA6B2), Color(0xFFC27C4E)];

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(entry.fullName, fallback: '?');
    return Semantics(
      label:
          'Rank ${entry.rank}, ${entry.fullName}, ${entry.levelName}, '
          '${entry.points} points',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: entry.rank <= 3
                  ? Icon(
                      Icons.emoji_events_rounded,
                      color: _medalColors[entry.rank - 1],
                      size: 24,
                    )
                  : Text(
                      '${entry.rank}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.navAbleSecondaryText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 19,
              backgroundColor: NavAblePalette.green.withValues(alpha: 0.18),
              foregroundImage: entry.picture == null
                  ? null
                  : MemoryImage(entry.picture!),
              child: Text(
                initials,
                style: TextStyle(
                  color: context.navAblePrimaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.navAblePrimaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _LevelBadge(
                    level: entry.level,
                    name: entry.levelName,
                    size: 11,
                  ),
                ],
              ),
            ),
            Text(
              '${entry.points}',
              style: TextStyle(
                color: context.navAblePrimaryText,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              ' pts',
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The signed-in user's rank, pinned under the list.
class _MyRankBar extends StatelessWidget {
  const _MyRankBar({required this.standing, required this.name});

  final MyStanding standing;
  final String name;

  @override
  Widget build(BuildContext context) {
    final progress = standing.progress;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NavAblePalette.green.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NavAblePalette.green.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            '#${standing.rank}',
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: context.navAblePrimaryText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _LevelBadge(level: progress.level, name: progress.name, size: 11),
          const SizedBox(width: 10),
          Text(
            '${standing.points} pts',
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
