import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileStats {
  const ProfileStats({
    required this.contributionPoints,
    required this.reportCount,
    required this.savedPlaceCount,
  });

  final int? contributionPoints;
  final int? reportCount;
  final int? savedPlaceCount;
}

class ProfileStatsApi {
  ProfileStatsApi._();

  static Future<ProfileStats> getCurrentUserStats() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return const ProfileStats(
        contributionPoints: null,
        reportCount: null,
        savedPlaceCount: null,
      );
    }
    Future<int?> safeCount(String table) async {
      try {
        return await client
            .from(table)
            .count(CountOption.exact)
            .eq('user_id', user.id);
      } on PostgrestException {
        return null;
      }
    }

    final counts = await Future.wait([
      safeCount('reports'),
      safeCount('favorites'),
    ]);
    int? points;
    try {
      final profile = await client
          .from('profiles')
          .select('contribution_points')
          .eq('id', user.id)
          .maybeSingle();
      points = (profile?['contribution_points'] as num?)?.round();
    } on PostgrestException {
      // The profile counter is optional for existing projects.
    }
    return ProfileStats(
      contributionPoints: points,
      reportCount: counts[0],
      savedPlaceCount: counts[1],
    );
  }
}
