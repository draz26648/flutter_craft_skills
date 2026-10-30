# Flutter Craft Skills

Twelve shared skills for Flutter projects, packaged for **Codex and Claude Code**.
Both hosts use the same SKILL.md files, references and scripts. Host-specific manifests
and invocation metadata live beside them and are checked for consistency.

## Install

Claude Code:

```text
/plugin marketplace add draz26648/flutter_craft_skills
/plugin install flutter-design-fidelity@flutter-craft-skills
/plugin install flutter-code-quality@flutter-craft-skills
/reload-plugins
/flutter-code-quality:flutter-adapt
```

Codex:

```bash
codex plugin marketplace add draz26648/flutter_craft_skills
codex plugin add flutter-design-fidelity@flutter-craft-skills
codex plugin add flutter-code-quality@flutter-craft-skills
```

Then invoke `$flutter-adapt` in the Flutter project. Adaptation is explicit-only on both
hosts. Other skills are selected when their descriptions fit the task; a small edit should
not activate every verification workflow.

For vendoring instead of marketplace installation:

```bash
bash install.sh --both --project /path/to/flutter-app
# Or --codex / --claude instead of --both.
```

Project skills use `.agents/skills` (Codex) or `.claude/skills` (Claude Code). The installer
puts performance and review-gate in the corresponding personal skills directory. Use
`--all-personal` for all skills there. Existing installs are preserved unless --force is
supplied; review local edits before replacing them. `FLUTTER_SKILLS_HOME` can point at an
isolated home for testing without touching personal installations.

## Project intent wins

Resolution order: current user request, explicit project instructions/profile, evidence
in the affected feature, then optional defaults for a genuinely new project. Missing
profile fields trigger discovery, never an implicit migration to Bloc, Freezed or GetIt.

`flutter-adapt` creates `.agents/flutter-profile.yaml` and `.agents/flutter-conventions.md`.
It preserves manual choices and leaves uncertain fields omitted. Legacy `.claude/` files
remain supported; `.agents/` wins when both exist. Conventions describe locations and
rules, not a stale inventory of every component.

```yaml
state: riverpod
models: manual
structure: feature_first
di: riverpod
routing: go_router
tokens: theme_only
l10n: arb
locales: [en, ar_EG]
strictness: warn
```

All fields are optional. The complete schema is in
[the profile reference](plugins/flutter-code-quality/skills/architecture/references/flutter-profile.md).
`tokens: none` allows inline visual values and TextStyle. `l10n: none` allows literals;
otherwise use the selected ARB/easy_localization/slang mechanism. Do not add AppTokens or
ARB to a project just because an example uses them.

## Skills

| Plugin | Skills |
|---|---|
| flutter-design-fidelity | design-tokens, figma-to-widget, visual-verification, golden-tests |
| flutter-code-quality | architecture, codebase-conventions, state-management, responsive-adaptive, a11y-and-rtl, performance, review-gate, flutter-adapt |

Design skills work with supplied reference images as well as connected Figma tools.
Unknown measurements are labelled. Missing capture inputs are reported as not verified.
The bundled [capture guide](plugins/flutter-design-fidelity/skills/visual-verification/references/capture-workflow.md)
provides a host widget-test helper; device/plugin rendering needs the appropriate project
integration harness. Goldens cover stable significant states rather than every tiny edit.

## Review gate

Requires Flutter, Dart >=3.9, Python 3 and Git for diff scope. From the installed skill:

```bash
bash /path/to/review-gate/scripts/prepare.sh
cd /path/to/flutter-app
bash /path/to/review-gate/scripts/check.sh
```

The helper has its own locked dependencies; it does not modify the app's pubspec.
The audit does not edit app source. Flutter commands may refresh their normal tool caches.

- `--base REF` compares against a chosen PR merge-base, plus working changes/untracked files.
- `--all` scans lib/, test/ and integration_test/; incompatible with --base.
- `--skip-tests` explicitly omits the test run.
- `--profile PATH` selects a profile; invalid or missing explicit profiles fail.

Changed/untracked/renamed files are included without staging, including monorepo apps.
A clean diff has no convention findings to scan; analysis/tests remain whole-app.
YAML validation covers every profile field. Dart syntax parsing handles multiline UI
expressions and avoids comments/string contents; it does not resolve imported types.
Remaining textual checks and duplicate names need human judgment. The credential heuristic
covers scoped Dart files, not the whole repository or history.

Exit codes: **0** no blockers, **1** findings block, **2** a required check could not run.
Missing intent makes convention rules advisory. Explicit block settings can enforce token
and RTL conventions; formatter, analyzer, tests and detected credentials always block.

## Validation

```bash
python3 scripts/validate.py
bash scripts/test_install_sh.sh
python3 scripts/test_scope.py
(cd plugins/flutter-code-quality/skills/review-gate/scripts/dart_checks && dart pub get && dart analyze && dart test)
bash scripts/test_check_sh.sh
python3 scripts/test_flutter_examples.py
# In a Python environment containing pillow and numpy:
python3 scripts/test_compare.py
```

CI runs structural, installer, shell, parser, gate, image-comparison and executable Dart
example tests. Riverpod 2.x and 3.x lifecycle fixtures compile separately. The capture
fixture verifies image dimensions and actual pixels. Installer tests exercise both hosts,
project/personal scopes, paths with spaces, and localized resource references.

Live behavior evaluation is separate and opt-in; it uses installed, authenticated host
CLIs and consumes account usage. It runs in temporary projects and saves reviewable code,
CLI logs and a JSON verdict under build/host-evaluations:

```bash
python3 scripts/evaluate_hosts.py --host both
```

It tests stack preservation without a profile, shared-component reuse, tokens: none,
a narrow copy change, and honest reporting when no reference image exists. The result is
limited to these fixtures and the host versions/models used, not proof of universal
behavior or identical automatic selection across hosts. No live model calls run in CI.

## Upgrading

3.0.0 changes the review contract: new-file/monorepo coverage and multiline checks can
find previously missed problems. Prepare the helper dependencies after installation and
review explicit profile strictness. See [CHANGELOG.md](CHANGELOG.md).

From 2.1.0, the marketplace name changed to flutter-craft-skills. Install the plugins
under the new name. The vendored flutter-adapt command became a skill; install.sh --force
removes only the recognizable legacy command, preserving user-authored commands. Do not
keep divergent profile copies in both .agents and .claude.
