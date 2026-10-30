---
name: review-gate
description: Audit Flutter changes before a commit or PR, after substantial implementation, or on request. Report formatting, analysis, tests, and scoped convention findings.
allowed-tools: Read, Grep, Glob, Bash
---

# Review Gate

Audit without editing application code. If the user requested implementation and fixes,
return findings to that workflow so it can fix them and rerun affected checks; do not
force a second permission request for already-authorized work. During a review-only task,
report findings without making those fixes. Tool frontmatter is a Claude Code hint, not a
portable security boundary; the same read-only audit rule applies in Codex.

Read the project profile using `../architecture/references/flutter-profile.md`. The
script validates every supplied field but does not infer missing intent from packages.
Missing configuration makes convention checks advisory, not a requirement to adopt Bloc,
Freezed, AppTokens or ARB. Explicit tokens: none and l10n: none skip the respective checks.

## Setup and execution

Resolve resources relative to this loaded SKILL.md, on either host. The gate requires
Flutter, Dart >=3.9, Python 3, Git for diff scope, and its isolated Dart parser package.
Prepare once after installation/update; this does not add dependencies to the app:

```bash
bash "<skill-directory>/scripts/prepare.sh"
```

Then run from the Flutter app root (the directory containing pubspec.yaml):

```bash
bash "<skill-directory>/scripts/check.sh"
```

Options:

- `--skip-tests`: explicit lint-only run; never describe it as tests passing.
- `--all`: audit all Dart files in lib/, test/ and integration_test/.
- `--base REF`: compare a PR against its merge-base commit, plus working changes and
  untracked files. Resolve the intended merge base first. Cannot accompany --all.
- `--profile PATH`: choose a profile explicitly; a missing file is an error.

With no base, changed files are compared with HEAD. Untracked and renamed files are
included without staging. Monorepo scope is confined to this app. A clean Git scope stays
empty; it does not silently scan the whole app. Non-Git projects scan all source/test
files. Analysis and tests remain whole-app. For a large workspace, run in each affected
Flutter package, respecting its workspace tooling.

Exit status: 0 no blockers (possibly warnings), 1 blocking findings, 2 unable to complete
a required check. A missing parser, invalid profile or malformed Dart is not a pass.
Inspect output before retrying; install missing prerequisites only within task scope.

## Checks and limits

- Formatting uses dart format with --output=none. Analysis uses flutter analyze
  --fatal-infos. Tests use flutter test unless explicitly skipped.
- Dart analyzer **syntax parsing** finds multiline Color/Colors, numeric insets, physical
  left/right insets, radius, TextStyle, literal Text, and literal asset paths. It ignores
  comments and string contents as code. This is not resolved type analysis: aliases and
  same-named custom constructors need review, and computed asset paths are not verified.
- Generated/test files and token/theme directories have documented exclusions in the
  script. Under tokens: none, TextStyle is allowed too. Constants/theme_only are advisory.
- RTL language subtags such as ar_EG and ar-EG normalize to ar. Only explicit RTL plus
  strictness: block makes directional conventions blocking. Physical coordinates may
  be intentional: assess the finding rather than rewriting blindly.
- Textual heuristics still flag print/debugPrint, TODOs, commented code, force unwraps,
  and likely credentials. Inspect false positives. Secret scanning covers scoped Dart
  files only; use the project's dedicated scanner for other file types and history.
- Asset existence is checked; verify pubspec declarations and package asset ownership
  when reviewing. Duplicate widget names are a hint, not proof of duplicated behavior.
- Changed golden PNGs and pubspec additions are surfaced for review. Review untracked
  visual assets too. Dependency additions need a concrete reason, not a skill example.

Convention strictness never downgrades formatter/analyzer/test failures or detected
credentials. Do not suppress a check merely to obtain a green report.

## Judgment and report

Inspect changed async logic for failure, disposal and out-of-order results; assess test
coverage against behavior. Inspect changed golden images before accepting new baselines.
Check whether new dependencies and components were needed. For a small edit, use relevant
existing tests; do not demand a new golden matrix for every widget.

Report BLOCKING, WORTH FIXING, and NOTES with file:line, evidence and impact. Separate
checks that passed, were skipped, and could not run. Say when nothing blocks; do not
manufacture findings or claim design verification based on compilation alone.
