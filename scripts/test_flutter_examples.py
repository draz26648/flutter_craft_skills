#!/usr/bin/env python3
"""Compile shipped Dart assets and test lifecycle/capture behavior in temp packages."""
import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(command, cwd):
    subprocess.run(command, cwd=cwd, check=True)


LIFECYCLE_TEST = r'''
import 'dart:async';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:example/lifecycle.dart';
void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());
  test('success and failure preserve transition sequence', () async {
    final states = <AsyncValue<int>>[];
    container.listen(walletProvider, (_, next) => states.add(next));
    final controller = container.read(walletProvider.notifier);
    await controller.refresh(() async => 42);
    expect(states, [const AsyncLoading<int>(), const AsyncData<int>(42)]);
    states.clear();
    await controller.refresh(() => Future<int>.error(StateError('offline')));
    expect(states.first, isA<AsyncLoading<int>>());
    expect(states.last, isA<AsyncError<int>>());
  });
  test('older completion cannot overwrite newer data', () async {
    final controller = container.read(walletProvider.notifier);
    final first = Completer<int>();
    final second = Completer<int>();
    final a = controller.refresh(() => first.future);
    final b = controller.refresh(() => second.future);
    second.complete(2); await b;
    first.complete(1); await a;
    expect(container.read(walletProvider), const AsyncData<int>(2));
  });
  test('invalidated lifetime does not publish a stale response', () async {
    final controller = container.read(walletProvider.notifier);
    final pending = Completer<int>();
    final work = controller.refresh(() => pending.future);
    container.invalidate(walletProvider);
    expect(container.read(walletProvider), const AsyncData<int>(0));
    pending.complete(99); await work;
    expect(container.read(walletProvider), const AsyncData<int>(0));
  });
  test('disposed container has no late writes', () async {
    final local = ProviderContainer();
    final controller = local.read(walletProvider.notifier);
    final pending = Completer<int>();
    final work = controller.refresh(() => pending.future);
    local.dispose(); pending.complete(99);
    await expectLater(work, completes);
  });
}
'''
CAPTURE_TEST = r'''
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/capture_harness.dart';
void main() {
  testWidgets('capture has requested size and pixels', (tester) async {
    await captureWidget(tester, child: const ColoredBox(color: Colors.red),
      output: 'build/screenshots/sample.png', theme: ThemeData(),
      locale: const Locale('en'), direction: TextDirection.ltr,
      logicalSize: const Size(100, 200), pixelRatio: 2, textScale: 1);
    await tester.runAsync(() async {
      final bytes = await File('build/screenshots/sample.png').readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 200); expect(frame.image.height, 400);
      final pixels = await frame.image.toByteData();
      expect(pixels!.buffer.asUint8List().take(4), [244, 67, 54, 255]);
      frame.image.dispose(); codec.dispose();
    });
  });
}
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--riverpod', choices=['2', '3', 'both'], default='both')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='flutter-craft-examples-') as temp:
        root = Path(temp)
        for major in (['2', '3'] if args.riverpod == 'both' else [args.riverpod]):
            project = root / ('riverpod' + major)
            (project / 'lib').mkdir(parents=True)
            (project / 'test').mkdir()
            constraint = '^2.6.1' if major == '2' else '^3.0.0'
            (project / 'pubspec.yaml').write_text(f"name: example\nenvironment:\n  sdk: '>=3.9.0 <4.0.0'\ndependencies:\n  riverpod: {constraint}\ndev_dependencies:\n  test: ^1.25.0\n")
            shutil.copy(ROOT / 'plugins/flutter-code-quality/skills/state-management/references/riverpod_lifecycle.dart', project / 'lib/lifecycle.dart')
            (project / 'test/lifecycle_test.dart').write_text(LIFECYCLE_TEST)
            run(['dart', 'pub', 'get'], project)
            run(['dart', 'analyze', '--fatal-infos'], project)
            run(['dart', 'test'], project)
        app = root / 'capture'
        run(['flutter', 'create', '--empty', '--platforms=linux', '--project-name', 'capture_example', str(app)], root)
        (app / 'test/support').mkdir(parents=True, exist_ok=True)
        shutil.copy(ROOT / 'plugins/flutter-design-fidelity/skills/visual-verification/references/capture_harness.dart', app / 'test/support/capture_harness.dart')
        shutil.copy(ROOT / 'plugins/flutter-design-fidelity/skills/design-tokens/references/theme-extension-template.dart', app / 'lib/app_tokens.dart')
        (app / 'test/capture_test.dart').write_text(CAPTURE_TEST)
        run(['dart', 'format', 'lib', 'test'], app)
        run(['flutter', 'analyze', '--fatal-infos'], app)
        run(['flutter', 'test'], app)
    print('All Dart example and capture tests passed')


if __name__ == '__main__':
    main()
