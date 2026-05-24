/// Text utilities for formatting strings for display.
class TextUtils {
  /// Converts a string to Title Case: every word starts with a capital letter.
  /// Preserves internal punctuation and whitespace.
  /// Examples:
  /// - "how sweet the name of jesus" -> "How Sweet The Name Of Jesus"
  /// - "all hail for the power of Jesus' name" -> "All Hail For The Power Of Jesus' Name"
  static String toTitleCase(String? input) {
    if (input == null) return '';
    final s = input.trim();
    if (s.isEmpty) return s;

    final buffer = StringBuffer();
    bool startOfWord = true;
    for (int i = 0; i < s.length; i++) {
      final ch = s[i];
      final isLetter = _isAlphabetic(ch);
      if (startOfWord && isLetter) {
        buffer.write(ch.toUpperCase());
        startOfWord = false;
      } else {
        buffer.write(ch);
        // if a letter follows and we were in a word, keep case as-is
        // we only toggle startOfWord when encountering a separator
      }

      // Word separators: space, hyphen, slash, dot, comma, colon, semicolon, parentheses, quotes
      if (!_isWordChar(ch)) {
        startOfWord = true;
      } else {
        startOfWord = false;
      }
    }

    return buffer.toString();
  }

  static bool _isAlphabetic(String ch) {
    if (ch.isEmpty) return false;
    final code = ch.codeUnitAt(0);
    // Basic Latin letters A-Z a-z
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  static bool _isWordChar(String ch) {
    if (ch.isEmpty) return false;
    final code = ch.codeUnitAt(0);
    // Letters or digits or apostrophe considered part of a word
    final isLetter = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
    final isDigit = (code >= 48 && code <= 57);
    return isLetter || isDigit || ch == "'";
  }
}