import 'dart:math' as math;

/// Fast, zero-dependency fuzzy search engine for movie and TV show titles.
/// Supports substring matching, prefix matching, word-boundary matches,
/// acronyms (e.g., "got" -> "Game of Thrones"), subsequence matching,
/// and Levenshtein edit distance tolerance for typos (e.g. "avengrs" -> "Avengers").
class FuzzySearchService {
  FuzzySearchService._();
  static final FuzzySearchService instance = FuzzySearchService._();

  /// Normalizes a string: lowercases, removes diacritics/accents, converts
  /// separators and punctuation to spaces, and trims extra spaces.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    var s = input.toLowerCase();

    // Diacritics replacement for common European characters
    const diacritics = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'å': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'ñ': 'n',
      'ç': 'c',
    };

    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final char = s[i];
      buffer.write(diacritics[char] ?? char);
    }
    s = buffer.toString();

    // Replace punctuation and symbols with space, keep alphanumeric
    s = s.replaceAll(RegExp(r'[^a-z0-9]'), ' ');
    // Collapse consecutive whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Calculates Levenshtein distance between two normalized strings.
  static int levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        int minVal = v1[j] + 1;
        final delVal = v0[j + 1] + 1;
        final subVal = v0[j] + cost;
        if (delVal < minVal) minVal = delVal;
        if (subVal < minVal) minVal = subVal;
        v1[j + 1] = minVal;
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[t.length];
  }

  /// Computes a fuzzy match score between [query] and [title].
  /// Returns `0.0` if there is no significant match, or a score > 0.0 up to 1000.0.
  static double score(String query, String title) {
    final q = normalize(query);
    final t = normalize(title);

    if (q.isEmpty || t.isEmpty) return 0.0;

    // 1. Exact Match
    if (q == t) return 1000.0;

    // 2. Exact Title starts with query
    if (t.startsWith(q)) {
      final lengthDiff = (t.length - q.length).clamp(0, 50);
      return 900.0 - (lengthDiff * 1.5);
    }

    // 2b. Query without leading article (e.g. "The Batman" vs "Batman")
    final tWithoutArticle = t.replaceFirst(RegExp(r'^(the|a|an)\s+'), '');
    final qWithoutArticle = q.replaceFirst(RegExp(r'^(the|a|an)\s+'), '');
    if (tWithoutArticle.startsWith(qWithoutArticle)) {
      return 880.0 - (tWithoutArticle.length - qWithoutArticle.length) * 1.5;
    }

    final tWords = t.split(' ');
    final qWords = q.split(' ');

    // 3. Word-boundary prefix: any word in the title starts with the query
    for (int i = 0; i < tWords.length; i++) {
      if (tWords[i].startsWith(q)) {
        // Earlier word position in title gets higher score
        return 800.0 - (i * 15.0) - (tWords[i].length - q.length) * 2.0;
      }
    }

    // 4. Acronym match: e.g., "got" -> "Game of Thrones", "lotr" -> "The Lord of the Rings"
    if (tWords.length > 1) {
      final acronym = tWords.map((w) => w.isNotEmpty ? w[0] : '').join();
      if (acronym == q) return 780.0;
      if (acronym.startsWith(q)) return 720.0;

      // Acronym without leading article (e.g. "The Lord of the Rings" -> "lotr")
      final noLeadWords =
          tWords.isNotEmpty && ['the', 'a', 'an'].contains(tWords.first)
          ? tWords.sublist(1)
          : tWords;
      if (noLeadWords.length > 1) {
        final noLeadAcronym = noLeadWords
            .map((w) => w.isNotEmpty ? w[0] : '')
            .join();
        if (noLeadAcronym == q) return 770.0;
        if (noLeadAcronym.startsWith(q)) return 710.0;
      }

      // Acronym ignoring articles and prepositions
      final significantWords = tWords
          .where(
            (w) => !['the', 'a', 'an', 'of', 'and', 'in', 'to'].contains(w),
          )
          .toList();
      if (significantWords.length > 1) {
        final sigAcronym = significantWords
            .map((w) => w.isNotEmpty ? w[0] : '')
            .join();
        if (sigAcronym == q) return 760.0;
        if (sigAcronym.startsWith(q)) return 700.0;
      }
    }

    // 5. Substring match
    final subIdx = t.indexOf(q);
    if (subIdx >= 0) {
      return 680.0 - (subIdx * 4.0);
    }

    // 6. Multi-token match: all words in query appear in title
    if (qWords.length > 1) {
      bool allFound = true;
      int matchOrderScore = 0;
      int lastPos = -1;

      for (final qw in qWords) {
        final pos = t.indexOf(qw);
        if (pos == -1) {
          allFound = false;
          break;
        }
        if (pos > lastPos) {
          matchOrderScore += 10;
        }
        lastPos = pos;
      }

      if (allFound) {
        return 600.0 + matchOrderScore;
      }
    }

    // 7. Typo / Edit distance match against title or title words
    // For entire string:
    if (q.length >= 3) {
      final wholeDist = levenshtein(q, t);
      if (wholeDist <= 1) {
        return 550.0;
      }
      if (wholeDist <= 2 && q.length >= 6) {
        return 480.0;
      }

      // Check edit distance against each word in title
      for (int i = 0; i < tWords.length; i++) {
        final tw = tWords[i];
        if (tw.length >= 3) {
          final dist = levenshtein(q, tw);
          if (dist == 1) {
            return 520.0 - (i * 10.0);
          }
          if (dist == 2 && q.length >= 5 && tw.length >= 5) {
            return 440.0 - (i * 10.0);
          }
        }
      }
    }

    // 8. Fuzzy Subsequence matching (characters appear in order)
    if (q.length >= 3) {
      int tIdx = 0;
      int qIdx = 0;
      int consecutive = 0;
      int wordStartMatches = 0;
      double seqScore = 0.0;

      while (tIdx < t.length && qIdx < q.length) {
        if (t.codeUnitAt(tIdx) == q.codeUnitAt(qIdx)) {
          final isWordStart = tIdx == 0 || t[tIdx - 1] == ' ';
          if (isWordStart) wordStartMatches++;
          consecutive++;
          seqScore += 10.0 + (consecutive * 5.0) + (isWordStart ? 15.0 : 0.0);
          qIdx++;
        } else {
          consecutive = 0;
        }
        tIdx++;
      }

      if (qIdx == q.length) {
        final coverage = q.length / t.length;
        final finalScore =
            (150.0 + seqScore * coverage + (wordStartMatches * 20.0)).clamp(
              50.0,
              420.0,
            );
        return finalScore;
      }
    }

    return 0.0;
  }

  /// Searches and ranks items of type [T] using fuzzy matching against [getTitle].
  /// Returns items sorted in descending order of match quality.
  static List<T> search<T>({
    required String query,
    required List<T> items,
    required String Function(T item) getTitle,
    int limit = 50,
    double minScore = 40.0,
  }) {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return items;

    final scoredList = <_ScoredItem<T>>[];
    for (final item in items) {
      final title = getTitle(item);
      final s = score(cleanQ, title);
      if (s >= minScore) {
        scoredList.add(_ScoredItem(item: item, score: s));
      }
    }

    scoredList.sort((a, b) => b.score.compareTo(a.score));

    final count = math.min(limit, scoredList.length);
    return scoredList.sublist(0, count).map((e) => e.item).toList();
  }

  /// Extracts distinct top title suggestions for search-as-you-type autocomplete.
  static List<String> getTitleSuggestions({
    required String query,
    required Iterable<String> candidateTitles,
    int limit = 8,
  }) {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return const [];

    final seen = <String>{};
    final scored = <_ScoredItem<String>>[];

    for (final title in candidateTitles) {
      final cleanTitle = title.trim();
      if (cleanTitle.isEmpty) continue;
      final key = cleanTitle.toLowerCase();
      if (seen.contains(key)) continue;

      final s = score(cleanQ, cleanTitle);
      if (s >= 50.0) {
        seen.add(key);
        scored.add(_ScoredItem(item: cleanTitle, score: s));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    final count = math.min(limit, scored.length);
    return scored.sublist(0, count).map((e) => e.item).toList();
  }
}

class _ScoredItem<T> {
  final T item;
  final double score;

  const _ScoredItem({required this.item, required this.score});
}
