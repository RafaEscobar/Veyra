abstract final class AnswerNormalizer {
  static final RegExp _whitespace = RegExp(r'\s+');

  static String normalize(String answer) {
    return answer.trim().toLowerCase().replaceAll(_whitespace, ' ');
  }
}
