#!/usr/bin/env python3
"""Map parsed Dart findings to profile severities; never execute profile text."""
import json
import re
import subprocess
import sys

GENERATED = re.compile(r'\.(g|freezed|mocks|config|gr|pb|pbenum|pbjson)\.dart$')
TEST = re.compile(r'(^|/)(test|integration_test)/|_test\.dart$')
THEME = re.compile(r'(^|/)(theme|themes|tokens|design_system)/|app_(colors|theme|tokens|typography|spacing|elevation)\.dart$')


def main():
    tool, token, soft, rtl, strings, *paths = sys.argv[1:]
    labels = {
        'colors': ('no hardcoded colors in widget code', token),
        'insets': ('no numeric EdgeInsets', token),
        'rtl': ('use EdgeInsetsDirectional (start/end, not left/right)', rtl),
        'radius': ('no hardcoded radii', soft),
        'style': ('no inline TextStyle in widget code', soft),
        'strings': ('user-facing strings use project localization', strings),
        'asset': ('asset paths that do not resolve', 'warn'),
    }
    paths = [p for p in paths if not GENERATED.search(p) and not TEST.search(p)]
    result = subprocess.run(['dart', tool, 'scan'], input=json.dumps(paths)+'\n', text=True, capture_output=True, check=False)
    if result.returncode:
        print(result.stderr, file=sys.stderr)
        return 2
    groups = {rule: [] for rule in labels}
    for line in result.stdout.splitlines():
        finding = json.loads(line)
        rule, path = finding['rule'], finding['path']
        if rule in {'colors', 'insets', 'radius', 'style'} and THEME.search(path):
            continue
        if rule == 'strings' and re.search(r'(^|/)(l10n|generated|intl)/', path):
            continue
        groups[rule].append(finding)
    blocking = False
    for rule, (label, severity) in labels.items():
        if severity.startswith('skip:'):
            print(f'  skipped: {label} ({severity[5:]})')
            print(f'  note: not checked: {label}')
        elif groups[rule]:
            blocking |= severity == 'block'
            print(f"  {'FAIL' if severity == 'block' else 'WARN'}: {label} ({len(groups[rule])})")
            for finding in groups[rule][:8]:
                print(f"    {finding['path']}:{finding['line']}: {finding['detail']}")
        else:
            print(f'  ok: {label}')
    return int(blocking)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as error:
        print(f"syntax check could not run: {error}", file=sys.stderr)
        sys.exit(2)
