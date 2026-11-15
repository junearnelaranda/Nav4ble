part of '../home.dart';

/// Opens a location's ratings and reviews: the average, everyone's
/// published reviews, and the signed-in user's own rating to add or change.
Future<void> _showReviewsSheet(
  BuildContext context, {
  required AccessibleLocation location,
  required bool isGuest,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.navAbleSurface,
    barrierColor: kNavAbleNavy.withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => _ReviewsSheet(location: location, isGuest: isGuest),
  );
}

class _ReviewsSheet extends StatefulWidget {
  const _ReviewsSheet({required this.location, required this.isGuest});

  final AccessibleLocation location;
  final bool isGuest;

  @override
  State<_ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<_ReviewsSheet> {
  final _comment = TextEditingController();
  PlaceReviews? _reviews;
  String? _loadError;
  int _rating = 0;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final reviews = await ReviewsApi.forLocation(widget.location.id);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        // Start the form from what the user wrote before.
        _rating = reviews.mine?.rating ?? 0;
        _comment.text = reviews.mine?.comment ?? '';
      });
    } on ReviewsApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    }
  }

  Future<void> _save() async {
    final problem = ReviewsApi.validate(
      rating: _rating,
      comment: _comment.text,
    );
    if (problem != null) {
      setState(() => _formError = problem);
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      await ReviewsApi.save(
        locationId: widget.location.id,
        rating: _rating,
        comment: _comment.text,
      );
      await _load();
      if (mounted) _announce('Your review was saved. Thank you!');
    } on ReviewsApiException catch (error) {
      if (mounted) setState(() => _formError = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(PlaceReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your review?'),
        content: const Text('Your rating and comment will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await ReviewsApi.delete(review.id);
      await _load();
      if (mounted) _announce('Your review was deleted.');
    } on ReviewsApiException catch (error) {
      if (mounted) setState(() => _formError = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _announce(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _reviews;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        maxWidth: 640,
      ),
      child: Padding(
        // Keeps the comment box above the keyboard.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Ratings & reviews',
                      style: TextStyle(
                        color: context.navAblePrimaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              widget.location.name,
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            if (reviews == null && _loadError == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (reviews == null)
              _ReviewsMessage(
                icon: Icons.cloud_off_rounded,
                text: _loadError!,
                actionLabel: 'Retry',
                onAction: _load,
              )
            else ...[
              _ReviewSummary(reviews: reviews),
              const SizedBox(height: 20),
              if (widget.isGuest)
                const _ReviewsMessage(
                  icon: Icons.lock_outline_rounded,
                  text: 'Sign in to rate this place.',
                )
              else
                _ReviewForm(
                  mine: reviews.mine,
                  rating: _rating,
                  comment: _comment,
                  saving: _saving,
                  error: _formError,
                  onRating: (value) => setState(() {
                    _rating = value;
                    _formError = null;
                  }),
                  onSave: _save,
                  onDelete: reviews.mine == null
                      ? null
                      : () => _delete(reviews.mine!),
                ),
              const SizedBox(height: 20),
              if (reviews.published.isEmpty)
                Text(
                  widget.isGuest
                      ? 'No reviews yet.'
                      : 'No reviews yet. Be the first to rate this place.',
                  style: TextStyle(color: context.navAbleSecondaryText),
                )
              else
                for (final review in reviews.published) ...[
                  _ReviewTile(review: review),
                  if (review != reviews.published.last)
                    Divider(
                      height: 24,
                      color: context.navAbleSecondaryText.withValues(
                        alpha: 0.18,
                      ),
                    ),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The average, as a number and stars, with the number of reviews.
class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.reviews});

  final PlaceReviews reviews;

  @override
  Widget build(BuildContext context) {
    final average = reviews.average;
    final count = reviews.count;
    return Semantics(
      label: average == null
          ? 'Not rated yet'
          : 'Rated ${average.toStringAsFixed(1)} out of 5 from $count '
                '${count == 1 ? 'review' : 'reviews'}',
      excludeSemantics: true,
      child: Row(
        children: [
          Text(
            average?.toStringAsFixed(1) ?? '–',
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stars(rating: average ?? 0, size: 20),
              const SizedBox(height: 4),
              Text(
                count == 0
                    ? 'Not rated yet'
                    : '$count ${count == 1 ? 'review' : 'reviews'}',
                style: TextStyle(
                  color: context.navAbleSecondaryText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Read-only stars; [rating] may be fractional (rounded to a half).
class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final halves = (rating * 2).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          Icon(
            halves >= star * 2
                ? Icons.star_rounded
                : halves == star * 2 - 1
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: const Color(0xFFE0A526),
          ),
      ],
    );
  }
}

/// The signed-in user's own rating: five stars to tap and an optional
/// comment.
class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.mine,
    required this.rating,
    required this.comment,
    required this.saving,
    required this.error,
    required this.onRating,
    required this.onSave,
    required this.onDelete,
  });

  final PlaceReview? mine;
  final int rating;
  final TextEditingController comment;
  final bool saving;
  final String? error;
  final ValueChanged<int> onRating;
  final VoidCallback onSave;
  final VoidCallback? onDelete;

  static const _words = ['Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final hidden = mine != null && !mine!.isPublished;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NavAbleRadius.card),
        border: Border.all(
          color: context.navAbleSecondaryText.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mine == null ? 'How accessible is this place?' : 'Your review',
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (hidden) ...[
            const SizedBox(height: 6),
            Text(
              'An admin has hidden this review, so others cannot see it.',
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  tooltip: '$star ${star == 1 ? 'star' : 'stars'}',
                  isSelected: star <= rating,
                  onPressed: saving || hidden ? null : () => onRating(star),
                  iconSize: 34,
                  constraints: const BoxConstraints(
                    minWidth: NavAbleSize.minimumTouchTarget,
                    minHeight: NavAbleSize.minimumTouchTarget,
                  ),
                  padding: EdgeInsets.zero,
                  color: const Color(0xFFE0A526),
                  icon: Icon(
                    star <= rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                  ),
                ),
              const SizedBox(width: 6),
              if (rating > 0)
                Flexible(
                  child: Text(
                    _words[rating - 1],
                    style: TextStyle(
                      color: context.navAbleSecondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: comment,
            enabled: !saving && !hidden,
            minLines: 2,
            maxLines: 5,
            maxLength: ReviewsApi.maxCommentLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Comment (optional)',
              hintText: 'Ramps, entrances, restrooms, staff help…',
              alignLabelWithHint: true,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (onDelete != null)
                TextButton(
                  onPressed: saving ? null : onDelete,
                  child: const Text('Delete'),
                ),
              const Spacer(),
              if (!hidden)
                FilledButton(
                  onPressed: saving ? null : onSave,
                  child: Text(
                    saving
                        ? 'Saving…'
                        : mine == null
                        ? 'Post review'
                        : 'Update review',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PlaceReview review;

  @override
  Widget build(BuildContext context) {
    final date = review.date;
    return Semantics(
      label:
          '${review.isMine ? 'Your review' : review.reviewer}, '
          '${review.rating} out of 5 stars'
          '${review.comment.isEmpty ? '' : '. ${review.comment}'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.isMine ? '${review.reviewer} (you)' : review.reviewer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.navAblePrimaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (date != null)
                Text(
                  '${_shortDate(date)}, ${date.year}',
                  style: TextStyle(
                    color: context.navAbleSecondaryText,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          _Stars(rating: review.rating.toDouble()),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment,
              style: TextStyle(
                color: context.navAbleSecondaryText,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewsMessage extends StatelessWidget {
  const _ReviewsMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.navAbleSecondaryText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: context.navAbleSecondaryText),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
