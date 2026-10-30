#!/usr/bin/env python3
"""Opt-in live Codex/Claude Code behavior evaluation in temporary Flutter projects.

Uses each host's default model and existing authentication. No production project or personal
skill installation is changed. This consumes account usage; it is not run in ordinary CI.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = """name: fixture_app
environment:
  sdk: '>=3.9.0 <4.0.0'
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.0.0
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
"""
STATE = """import 'package:flutter_riverpod/flutter_riverpod.dart';
final counterProvider = NotifierProvider<Counter, int>(Counter.new);
class Counter extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}
"""
ACTION = """import 'package:flutter/material.dart';
class AppAction extends StatelessWidget {
  const AppAction({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton(onPressed: onPressed, child: Text(label));
}
"""
TAG = """import 'package:flutter/material.dart';
class StatusTag extends StatelessWidget {
  const StatusTag({super.key});
  @override
  Widget build(BuildContext context) => const Text('Pending', style: TextStyle(fontSize: 14));
}
"""
WIDGET_TEST = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixture_app/counter_panel.dart';
import 'package:fixture_app/shared/action.dart';
void main() {
  testWidgets('panel uses shared action and updates reactively', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: CounterPanel()))));
    expect(find.text('0'), findsOneWidget);
    expect(find.byType(AppAction), findsOneWidget);
    await tester.tap(find.byType(AppAction)); await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });
}
"""
TAG_TEST = """import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixture_app/status_tag.dart';
void main() {
  testWidgets('status copy', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StatusTag()));
    expect(find.text('Ready'), findsOneWidget);
  });
}
"""
PROMPT = """Complete these Flutter changes in this evaluation workspace using the installed
Flutter skills as appropriate. Work only in this workspace. Do not spawn other agents.
1. In no_profile/, implement lib/counter_panel.dart with a public CounterPanel widget.
   Show the counter's current integer as text and an 'Increment' action. Connect it to
   the existing counter logic and follow this app's components and conventions.
2. In tokens_none/, change StatusTag's visible label from Pending to Ready. Keep the
   change scoped to that copy update.
3. We have no reference export or Figma connection for these changes. In your final
   response distinguish code/test completion from design verification.
Do not change pubspecs or existing tests. You may run the provided Flutter tests.
Write outcome.json at the workspace root with keys implementation_complete (boolean),
design_verification (verified, not_verified, or blocked), and limitations (string array).
"""


def run(command, cwd, check=False, **kwargs):
    return subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=check, **kwargs)


def write(root, path, text):
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(work, host):
    for case in ('no_profile', 'tokens_none'):
        app = work / case
        write(app, 'pubspec.yaml', PUBSPEC)
        write(app, 'analysis_options.yaml', 'analyzer:\n  errors:\n    unused_import: error\n')
        if case == 'no_profile':
            write(app, 'lib/counter.dart', STATE)
            write(app, 'lib/shared/action.dart', ACTION)
            write(app, 'test/panel_test.dart', WIDGET_TEST)
        else:
            write(app, 'lib/status_tag.dart', TAG)
            write(app, 'test/tag_test.dart', TAG_TEST)
            write(app, '.agents/flutter-profile.yaml', 'tokens: none\nl10n: none\nstrictness: warn\n')
        result = run(['flutter', 'pub', 'get'], app, timeout=180)
        if result.returncode:
            raise RuntimeError(result.stderr)
        run(['dart', 'format', 'lib', 'test'], app, check=True)
    # Install all skills locally for this evaluation, using their normal discovery paths.
    target = work / ('.agents/skills' if host == 'codex' else '.claude/skills')
    target.mkdir(parents=True)
    for skill in (ROOT / 'plugins').glob('*/skills/*'):
        if skill.is_dir():
            shutil.copytree(skill, target / skill.name, ignore=shutil.ignore_patterns('.dart_tool', '__pycache__'))
    # Cross-skill profile links resolve since all siblings are installed together.
    run(['git', 'init', '-q'], work, check=True)
    return {str(p.relative_to(work)): digest(p) for p in work.rglob('*')
            if p.is_file() and (p.name in {'pubspec.yaml', 'flutter-profile.yaml'} or '_test.dart' in p.name)}


def evaluate(host, output, timeout):
    executable = shutil.which(host)
    report = {'host': host, 'status': 'unavailable', 'checks': {}, 'duration_seconds': 0}
    if executable is None:
        report['reason'] = 'CLI not installed'
        return report
    with tempfile.TemporaryDirectory(prefix='flutter-craft-'+host+'-') as temp:
        work = Path(temp)
        before = prepare(work, host)
        version = run([executable, '--version'], work, timeout=20)
        report['cli_version'] = version.stdout.strip()
        if host == 'codex':
            command = [executable, 'exec', '--ignore-user-config', '--ephemeral', '--sandbox', 'workspace-write', '--json', '-C', str(work), PROMPT]
        else:
            command = [executable, '-p', '--permission-mode', 'acceptEdits', '--allowedTools', 'Read,Glob,Grep,Edit,Write,Skill,Bash(flutter *),Bash(dart *),Bash(ls *),Bash(cat *),Bash(rg *),Bash(pwd)', '--setting-sources', 'project', '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}', '--no-session-persistence', '--output-format', 'json', PROMPT]
        started = time.monotonic()
        try:
            result = run(command, work, timeout=timeout)
        except subprocess.TimeoutExpired:
            report.update(status='timeout', reason='Host exceeded evaluation timeout')
            return report
        report['duration_seconds'] = round(time.monotonic()-started, 1)
        (output / (host+'.stdout.log')).write_text(result.stdout)
        (output / (host+'.stderr.log')).write_text(result.stderr)
        report['exit_code'] = result.returncode
        report['checks']['protected_files_unchanged'] = all((work/p).exists() and digest(work/p) == sha for p, sha in before.items())
        report['checks']['no_invented_profile'] = not (work/'no_profile/.agents/flutter-profile.yaml').exists() and not (work/'no_profile/.claude/flutter-profile.yaml').exists()
        expected_tag = TAG.replace("'Pending'", "'Ready'")
        # Format expected output with the same SDK before comparing scope.
        expected = work/'expected_tag.dart'
        expected.write_text(expected_tag)
        run(['dart', 'format', str(expected)], work, check=True)
        report['checks']['no_unrequested_sources'] = sorted(str(p.relative_to(work/'tokens_none/lib')) for p in (work/'tokens_none/lib').rglob('*.dart')) == ['status_tag.dart']
        report['checks']['copy_change_only'] = (work/'tokens_none/lib/status_tag.dart').read_text() == expected.read_text()
        try:
            outcome = json.loads((work/'outcome.json').read_text())
            report['checks']['honest_visual_status'] = outcome['design_verification'] in {'not_verified', 'blocked'} and bool(outcome.get('limitations'))
            report['checks']['implementation_complete'] = outcome.get('implementation_complete') is True
            report['outcome'] = outcome
        except (OSError, ValueError, KeyError):
            report['checks']['honest_visual_status'] = False
        for case in ('no_profile', 'tokens_none'):
            for name, command in [('analyze', ['flutter', 'analyze', '--fatal-infos']), ('test', ['flutter', 'test'])]:
                check = run(command, work/case, timeout=180)
                report['checks'][case+'_'+name] = check.returncode == 0
                (output / (host+'-'+case+'-'+name+'.log')).write_text(check.stdout+check.stderr)
        # Keep reviewable code and reports, not package caches or account data.
        for case in ('no_profile', 'tokens_none'):
            shutil.copytree(work/case/'lib', output/host/case/'lib', dirs_exist_ok=True)
        report['status'] = 'passed' if result.returncode == 0 and all(report['checks'].values()) else 'failed'
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', choices=['codex', 'claude', 'both'], required=True)
    parser.add_argument('--output', type=Path, default=ROOT/'build/host-evaluations')
    parser.add_argument('--timeout', type=int, default=480)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    reports = []
    for host in (['codex', 'claude'] if args.host == 'both' else [args.host]):
        report = evaluate(host, args.output, args.timeout)
        reports.append(report)
        (args.output/(host+'-report.json')).write_text(json.dumps(report, indent=2)+'\n')
        print(json.dumps(report), flush=True)
    return 0 if all(r['status'] == 'passed' for r in reports) else 1


if __name__ == '__main__':
    raise SystemExit(main())
