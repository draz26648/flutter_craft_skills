import 'dart:convert';
import 'dart:io';
import 'package:flutter_craft_checks/checks.dart';

void main(List<String> args) {
  try {
    if (args.length == 2 && args.first == 'profile') {
      final file = File(args[1]);
      final p = profile(file.existsSync() ? file.readAsStringSync() : '');
      final locales = (p['locales'] as List<String>?)
          ?.map((s) => s.split(RegExp('[-_]')).first.toLowerCase())
          .join(' ');
      // Fixed four lines, not executable shell text; all enum values are validated.
      stdout.writeln(p['tokens'] ?? 'unknown');
      stdout.writeln(p['l10n'] ?? 'unknown');
      stdout.writeln(p['strictness'] ?? 'warn');
      stdout.writeln(locales == null ? 'unknown' : 'declared $locales');
    } else if (args.length == 1 && args.first == 'scan') {
      // A JSON array on stdin supports spaces, Unicode and newlines in filenames.
      final paths = jsonDecode(stdin.readLineSync()!) as List<dynamic>;
      for (final path in paths.cast<String>()) {
        for (final f in inspect(File(path).readAsStringSync(), path)) {
          stdout.writeln(
            jsonEncode({
              'rule': f.rule,
              'path': path,
              'line': f.line,
              'detail': f.detail,
            }),
          );
        }
      }
    } else {
      throw FormatException(
        'usage: check.dart profile PATH | scan (JSON paths on stdin)',
      );
    }
  } catch (error) {
    stderr.writeln(error);
    exitCode = 2;
  }
}
