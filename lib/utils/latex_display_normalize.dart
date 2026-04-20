/// 将云端返回的 TeX 规范为 [flutter_math_fork] 易解析的固定形态，减少 `\frac`、定界符等导致的渲染错误。
class LatexDisplayNormalize {
  LatexDisplayNormalize._();

  /// OCR 主结果：单行行内为主，统一为 `\\( ... \\)`（内部已去外层重复定界符）。
  static String forRecognizedOcr(String raw) {
    return _normalize(raw);
  }

  /// 解题里每条短公式 / 公式辑要：同上；若模型已用 `\\[...\\]` 则保留。
  static String forSolveSnippet(String raw) {
    return _normalize(raw);
  }

  static String _normalize(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return t;

    t = _stripMarkdownFences(t);
    t = _stripOuterDelimiters(t);
    t = _fixFracTwoDigits(t);
    t = t.trim();

    if (t.startsWith(r'\[') && t.endsWith(r'\]')) {
      return t;
    }
    if (t.startsWith(r'\(') && t.endsWith(r'\)')) {
      return t;
    }
    return '\\($t\\)';
  }

  static String _stripMarkdownFences(String t) {
    if (t.startsWith('```')) {
      return t
          .replaceFirst(RegExp(r'^```(?:tex|latex)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```\s*$'), '')
          .trim();
    }
    return t;
  }

  /// 去掉最外层一对 `$`、`$$`、`\\(...\\)`、`\\[...\\]`。
  static String _stripOuterDelimiters(String t) {
    var s = t.trim();
    for (var i = 0; i < 3; i++) {
      final before = s;
      if (s.startsWith(r'$$') && s.endsWith(r'$$') && s.length > 4) {
        s = s.substring(2, s.length - 2).trim();
        continue;
      }
      if (s.startsWith(r'$') && s.endsWith(r'$') && s.length > 1) {
        s = s.substring(1, s.length - 1).trim();
        continue;
      }
      if (s.startsWith(r'\(') && s.endsWith(r'\)')) {
        s = s.substring(2, s.length - 2).trim();
        continue;
      }
      if (s.startsWith(r'\[') && s.endsWith(r'\]')) {
        s = s.substring(2, s.length - 2).trim();
        continue;
      }
      if (before == s) break;
    }
    return s;
  }

  /// `\\frac12` → `\\frac{1}{2}`（仅两位相邻数字且无后续数字时），避免 `rac` 类解析歧义。
  static String _fixFracTwoDigits(String t) {
    return t.replaceAllMapped(
      RegExp(r'\\frac(\d)(\d)(?!\d)'),
      (m) => '\\frac{${m[1]}}{${m[2]}}',
    );
  }
}
