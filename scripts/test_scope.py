#!/usr/bin/env python3
"""Regression cases for worktrees, untracked files, PR bases and monorepos."""
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('scope', ROOT / 'plugins/flutter-code-quality/skills/review-gate/scripts/scope.py')
scope = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scope)


class ScopeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.previous = Path.cwd()
        os.chdir(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'test')
        self.git('config', 'user.email', 'test@example.invalid')
        self.write('apps/a/lib/old.dart')
        self.write('apps/b/lib/other.dart')
        self.git('add', '.')
        self.git('commit', '-qm', 'base')

    def tearDown(self):
        os.chdir(self.previous)
        self.temp.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', *args], text=True).strip()

    def write(self, path, content='void main() {}'):
        p = Path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)

    def test_changed_untracked_renamed_and_deleted(self):
        self.write('apps/a/lib/old.dart', '// modified')
        self.write('apps/a/lib/new file.dart')
        self.write('apps/a/lib/line\nbreak.dart')
        self.git('mv', 'apps/b/lib/other.dart', 'apps/b/lib/renamed.dart')
        self.assertEqual(set(scope.paths()), {'apps/a/lib/old.dart', 'apps/a/lib/new file.dart', 'apps/a/lib/line\nbreak.dart', 'apps/b/lib/renamed.dart'})
        Path('apps/a/lib/old.dart').unlink()
        self.assertNotIn('apps/a/lib/old.dart', scope.paths())

    def test_monorepo_and_base(self):
        base = self.git('rev-parse', 'HEAD')
        self.write('apps/a/lib/old.dart', '// committed change')
        self.git('add', '.')
        self.git('commit', '-qm', 'change')
        self.write('apps/a/lib/new.dart')
        self.write('apps/b/lib/new.dart')
        self.git('config', 'diff.relative', 'true')
        os.chdir('apps/a')
        self.assertEqual(scope.paths(), ['lib/new.dart'])
        self.assertEqual(scope.paths(base=base), ['lib/new.dart', 'lib/old.dart'])
        with self.assertRaises(ValueError):
            scope.paths(base='missing-ref')
        with self.assertRaises(ValueError):
            scope.paths(True, base)

    def test_clean_scope_is_empty(self):
        self.assertEqual(scope.paths(), [])

    def test_unborn_repo(self):
        os.mkdir('fresh')
        os.chdir('fresh')
        self.git('init', '-q')
        self.write('lib/first.dart')
        self.git('add', '.')
        self.write('lib/second.dart')
        self.assertEqual(scope.paths(), ['lib/first.dart', 'lib/second.dart'])


if __name__ == '__main__':
    unittest.main()
