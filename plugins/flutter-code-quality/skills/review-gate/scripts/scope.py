#!/usr/bin/env python3
"""Emit NUL-separated app-relative Dart paths without changing the index."""
import subprocess
import sys
from pathlib import Path


def git(*args):
    try:
        return subprocess.run(['git', *args], capture_output=True, check=False)
    except FileNotFoundError:
        return subprocess.CompletedProcess(['git', *args], 128, b'', b'git unavailable')


def paths(all_files=False, base=''):
    root = Path.cwd()
    repo = git('rev-parse', '--show-toplevel')
    if all_files or repo.returncode:
        if base:
            raise ValueError('--base requires a Git repository and cannot accompany --all')
        return sorted(str(p) for folder in ('lib', 'test', 'integration_test')
                      for p in Path(folder).rglob('*.dart') if p.is_file())
    if base:
        valid = git('rev-parse', '--verify', '--end-of-options', base + '^{commit}')
        if valid.returncode:
            raise ValueError('invalid --base commit')
        base = valid.stdout.decode().strip()
    elif git('rev-parse', '--verify', 'HEAD').returncode == 0:
        base = 'HEAD'
    raw = git('diff', '--no-relative', '--name-only', '-z', '--diff-filter=ACMR', base, '--', '.') if base else git('ls-files', '--full-name', '-z', '--', '.')
    untracked = git('ls-files', '--others', '--exclude-standard', '--full-name', '-z', '--', '.')
    if raw.returncode or untracked.returncode:
        raise ValueError('git could not enumerate files')
    repo_root = Path(repo.stdout.decode().strip())
    result = set()
    for name in (raw.stdout + untracked.stdout).split(b'\0'):
        if not name:
            continue
        p = repo_root / name.decode()
        if p.suffix == '.dart' and p.is_file() and not p.is_symlink():
            try:
                result.add(str(p.relative_to(root)))
            except ValueError:
                continue
    return sorted(result)


if __name__ == '__main__':
    try:
        for path in paths(sys.argv[1] == 'true', sys.argv[2]):
            sys.stdout.buffer.write(path.encode() + b'\0')
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        sys.exit(2)
