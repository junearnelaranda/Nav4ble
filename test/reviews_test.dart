import 'package:flutter_test/flutter_test.dart';
import 'package:navable/reviews_api.dart';

Map<String, Object?> _row({
  String id = 'r1',
  Object? rating = 4,
  String? comment = 'Wide ramp at the entrance.',
  String status = 'Published',
  String? reviewer = 'June A.',
  bool mine = false,
}) => {
  'review_id': id,
  'rating': rating,
  'comment': comment,
  'review_date': '2026-11-15T03:00:00Z',
  'review_status': status,
  'reviewer': reviewer,
  'is_mine': mine,
};

void main() {
  group('PlaceReview.fromRow', () {
    test('reads a review', () {
      final review = PlaceReview.fromRow(_row(mine: true))!;
      expect(review.rating, 4);
      expect(review.comment, 'Wide ramp at the entrance.');
      expect(review.reviewer, 'June A.');
      expect(review.isMine, isTrue);
      expect(review.isPublished, isTrue);
      expect(review.date, isNotNull);
    });

    test('falls back to a neutral name and an empty comment', () {
      final review = PlaceReview.fromRow(_row(comment: null, reviewer: ' '))!;
      expect(review.reviewer, 'NavAble user');
      expect(review.comment, '');
    });

    test('rejects rows without an id or a 1-5 rating', () {
      expect(PlaceReview.fromRow(_row(id: '')), isNull);
      expect(PlaceReview.fromRow(_row(rating: 0)), isNull);
      expect(PlaceReview.fromRow(_row(rating: 6)), isNull);
      expect(PlaceReview.fromRow(_row(rating: null)), isNull);
    });
  });

  group('PlaceReviews', () {
    PlaceReviews build(List<Map<String, Object?>> rows) =>
        PlaceReviews([for (final row in rows) ?PlaceReview.fromRow(row)]);

    test('has no average when nobody has rated', () {
      final reviews = build([]);
      expect(reviews.count, 0);
      expect(reviews.average, isNull);
      expect(reviews.mine, isNull);
    });

    test('averages the published ratings', () {
      final reviews = build([
        _row(id: 'a', rating: 5),
        _row(id: 'b', rating: 4),
        _row(id: 'c', rating: 2),
      ]);
      expect(reviews.count, 3);
      expect(reviews.average, closeTo(3.67, 0.01));
      expect(reviews.countFor(5), 1);
      expect(reviews.countFor(1), 0);
    });

    test("keeps the user's hidden review out of the list and the average", () {
      final reviews = build([
        _row(id: 'a', rating: 5),
        _row(id: 'mine', rating: 1, status: 'Hidden', mine: true),
      ]);
      expect(reviews.count, 1);
      expect(reviews.average, 5);
      expect(reviews.mine?.id, 'mine');
      expect(reviews.mine?.isPublished, isFalse);
    });
  });

  group('ReviewsApi.validate', () {
    test('needs 1 to 5 stars', () {
      expect(ReviewsApi.validate(rating: 0, comment: ''), isNotNull);
      expect(ReviewsApi.validate(rating: 6, comment: ''), isNotNull);
      expect(ReviewsApi.validate(rating: 3, comment: ''), isNull);
    });

    test('limits the comment to 500 characters after trimming', () {
      expect(ReviewsApi.validate(rating: 3, comment: 'a' * 500), isNull);
      expect(ReviewsApi.validate(rating: 3, comment: ' ${'a' * 500} '), isNull);
      expect(ReviewsApi.validate(rating: 3, comment: 'a' * 501), isNotNull);
    });
  });
}
