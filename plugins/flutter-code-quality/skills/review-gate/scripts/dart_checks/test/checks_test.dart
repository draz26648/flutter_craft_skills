import 'package:flutter_craft_checks/checks.dart';
import 'package:test/test.dart';

void main() {
  test('profile supports quoted values and block locales', () {
    final p = profile(
      'state: "riverpod"\ntokens: none\nlocales:\n  - ar_EG\n  - en-US\n',
    );
    expect(p['state'], 'riverpod');
    expect(p['locales'], ['ar_EG', 'en-US']);
    expect(profile(''), isEmpty);
  });
  test('all enums, keys, duplicate values and locale shapes are validated', () {
    for (final s in [
      'state: riverpood',
      'di: magic',
      'routing: nope',
      'models: nope',
      'structure: nope',
      'strictness: nope',
      'tokens: nope',
      'l10n: nope',
      'locales: ar',
      'locales: [true]',
      'locales: [ar/EG]',
      'unknown: yes',
      'state: bloc\nstate: riverpod',
      '- state: bloc',
    ]) {
      expect(() => profile(s), throwsA(anything), reason: s);
    }
  });
  test('multiline code is inspected; comments and strings are not code', () {
    final found = inspect('''
// TextStyle(fontSize: 99), Color(0xff000000)
const prose = 'EdgeInsets.all(16)';
final a = EdgeInsets.only(
  left: 16,
);
final b = const Color(
  0xff000000,
);
final c = Text(
  'Hello',
);
final d = TextStyle(
  fontSize: 14,
);
final e = const EdgeInsets.fromLTRB(1, 2, 3, 4);
final f = const EdgeInsets.only(left: 8);
''', 'widget.dart');
    expect(found.where((f) => f.rule == 'colors'), hasLength(1));
    expect(found.where((f) => f.rule == 'rtl'), hasLength(3));
    expect(found.where((f) => f.rule == 'strings'), hasLength(1));
    expect(found.where((f) => f.rule == 'style'), hasLength(1));
  });
  test('syntax errors cannot silently pass', () {
    expect(() => inspect('final x = ;', 'bad.dart'), throwsFormatException);
  });
}
