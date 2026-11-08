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

    final reportCount = await safeCount('reports');
    return ProfileStats(
      // Points now come from PointsApi.myStanding (contribution_points).
      contributionPoints: null,
      reportCount: reportCount,
      // Saved places live on the device (see SavedPlacesStore).
      savedPlaceCount: null,
    );
  }
}
