/// "June Arnel Aranda" -> "JA", "Maria" -> "MA"; [fallback] when there is
/// no name. Used wherever a person shows without a profile photo.
String initialsOf(String name, {String fallback = ''}) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return fallback;
  if (words.length == 1) {
    final word = words.first;
    return word.substring(0, word.length < 2 ? word.length : 2).toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}
