/// True when every word of [query] appears in the place's name, address,
/// category or accessibility features, ignoring case and a plural "s"
/// ("malls" finds "Shopping mall"). An empty query matches every place.
bool placeMatchesQuery(
  String query, {
  required String name,
  required String address,
  required String category,
  Iterable<String> features = const [],
}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;
  final text = [name, address, category, ...features].join(' ').toLowerCase();
  return words.every(
    (word) =>
        text.contains(word) ||
        (word.length > 3 &&
            word.endsWith('s') &&
            text.contains(word.substring(0, word.length - 1))),
  );
}
