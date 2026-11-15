import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewsApiException implements Exception {
  const ReviewsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One user's rating of a NavAble location.
class PlaceReview {
  const PlaceReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.date,
    required this.reviewer,
    required this.isMine,
    required this.isPublished,
  });

  final String id;

  /// 1 to 5 stars.
  final int rating;
  final String comment;
  final DateTime? date;

  /// First name and last initial ("June A."), never the full name or email.
  final String reviewer;
  final bool isMine;

  /// False when an admin has hidden it; only its author still sees it.
  final bool isPublished;

  /// Null when the row is not a usable review.
  static PlaceReview? fromRow(Map<dynamic, dynamic> row) {
    final id = row['review_id']?.toString() ?? '';
    final rating = (row['rating'] as num?)?.toInt();
    if (id.isEmpty || rating == null || rating < 1 || rating > 5) return null;
    return PlaceReview(
      id: id,
      rating: rating,
      comment: row['comment']?.toString().trim() ?? '',
      date: DateTime.tryParse(row['review_date']?.toString() ?? '')?.toLocal(),
      reviewer: row['reviewer']?.toString().trim().isNotEmpty == true
          ? row['reviewer'].toString().trim()
          : 'NavAble user',
      isMine: row['is_mine'] == true,
      isPublished: row['review_status'] == 'Published',
    );
  }
}

/// A place's reviews with the numbers shown above them.
class PlaceReviews {
  PlaceReviews(List<PlaceReview> all)
    : published = List.unmodifiable(all.where((r) => r.isPublished)),
      mine = all.where((r) => r.isMine).firstOrNull;

  /// Published reviews, newest first.
  final List<PlaceReview> published;

  /// The signed-in user's own review, also when hidden by an admin.
  final PlaceReview? mine;

  int get count => published.length;

  /// Average of the published ratings; null when there are none.
  double? get average => published.isEmpty
      ? null
      : published.fold<int>(0, (sum, r) => sum + r.rating) / published.length;

  /// How many published reviews gave [stars] stars.
  int countFor(int stars) => published.where((r) => r.rating == stars).length;
}

abstract final class ReviewsApi {
  static const maxCommentLength = 500;

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<PlaceReviews> forLocation(String locationId) async {
    try {
      final rows = await _client.rpc(
        'get_location_reviews',
        params: {'place': locationId},
      );
      return PlaceReviews([
        for (final row in (rows as List).whereType<Map>())
          ?PlaceReview.fromRow(row),
      ]);
    } on PostgrestException {
      throw const ReviewsApiException("Couldn't load reviews. Try again.");
    } on Exception {
      throw const ReviewsApiException(
        "Couldn't load reviews. Check your connection.",
      );
    }
  }

  /// Adds the signed-in user's review of [locationId], or replaces the one
  /// they already wrote (one review per person per place).
  static Future<void> save({
    required String locationId,
    required int rating,
    required String comment,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const ReviewsApiException('Sign in to rate this place.');
    }
    final problem = validate(rating: rating, comment: comment);
    if (problem != null) throw ReviewsApiException(problem);
    final text = comment.trim();
    try {
      await _client.from('reviews').upsert({
        'user_id': userId,
        'location_id': locationId,
        'rating': rating,
        // The table also keeps a 0-5 accessibility score per review; the
        // star rating is the accessibility rating.
        'accessibility_score': rating,
        'comment': text.isEmpty ? null : text,
        'review_status': 'Published',
        'review_date': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,location_id');
    } on PostgrestException catch (error) {
      // 42501: the database refused it, which for an existing review means
      // an admin has hidden it.
      throw ReviewsApiException(
        error.code == '42501'
            ? 'This review was hidden by an admin and can no longer be '
                  'changed.'
            : "Couldn't save your review. Try again.",
      );
    } on Exception {
      throw const ReviewsApiException(
        "Couldn't save your review. Check your connection.",
      );
    }
  }

  static Future<void> delete(String reviewId) async {
    try {
      await _client.from('reviews').delete().eq('review_id', reviewId);
    } on Exception {
      throw const ReviewsApiException(
        "Couldn't delete your review. Try again.",
      );
    }
  }

  /// What is wrong with a review before it is sent, or null when it is fine.
  static String? validate({required int rating, required String comment}) {
    if (rating < 1 || rating > 5) return 'Choose 1 to 5 stars.';
    if (comment.trim().length > maxCommentLength) {
      return 'Keep your comment to $maxCommentLength characters or fewer.';
    }
    return null;
  }
}
