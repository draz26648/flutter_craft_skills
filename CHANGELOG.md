# Changelog

Skill text is the product here, so a wording change that alters what an agent does counts
as a release. Bump the `version` in the Claude and Codex manifests and in the marketplace
together; both hosts cache installed plugins. `scripts/validate.py` fails the build if
the copies disagree.

Versioning follows semver from the *consumer's* point of view. A check that starts
failing a project that previously passed is a breaking change, even though nothing about
the project changed — the gate's verdict is the contract.

## 3.0.0

### Changed

- Missing profile fields now mean discovery for agents and advisory convention checks
  for the gate. No implicit Bloc/Freezed/GetIt migration. New adaptation profiles use
  warn, retain manual decisions, and omit uncertain fields.
- Shared instructions honor tokens: none, theme_only, constants and each localization
  system. Descriptions and verification scope are narrower; small edits do not require
  a full golden/screenshot workflow.
- Riverpod examples distinguish 2.x/3.x APIs; lifecycle examples test disposal,
  invalidation and latest-request-wins behavior. Corrected opacity and rebuild guidance.

### Added

- A separate Dart analyzer/YAML helper package for the gate. Requires Dart >=3.9,
  Python 3 and a one-time dart pub get inside the skill's scripts/dart_checks directory.
- YAML validation for all fields, quoted values, block lists, duplicates and locale
  subtags. Syntax checks handle multiline expressions and ignore comments as code.
- Untracked/renamed Dart files, monorepo-relative scope, --base for PRs, and honest empty
  scope. These can surface defects previously missed, so this is a major release.
- A portable widget-test PNG capture helper and setup guide; it does not claim device
  or platform-view fidelity. Executable checks cover capture dimensions and pixels.
- Opt-in live host evaluation for Codex and Claude Code with identical task fixtures,
  independent Flutter tests, protected-file checks, and saved reports.

### Upgrade

Prepare the gate helper dependencies after updating. Review profile settings before
relying on blocking house conventions: unspecified settings are now advisory. Existing
explicit block settings remain effective; formatting, analysis, tests and detected
credentials still block. No account-wide settings or application dependencies are changed.

## 2.2.0

Codex support, additive. A project that passed the review gate under 2.1.0 still passes.
The two ways to get a different result both need a misconfiguration first: a `--profile`
path that does not exist, and a project holding a profile in both `.agents/` and
`.claude/`. Both are described below. Existing installs need a look before upgrading —
the marketplace was renamed, and a vendored 2.1.0 install leaves a stale command behind.
The README's "Upgrading from 2.1.0" section covers both.

### Added

- Codex plugin manifests for both plugin packages and a repo marketplace at
  `.agents/plugins/marketplace.json`.
- Codex vendoring through `install.sh --codex`; `--both` installs for Claude Code and
  Codex together. Codex project skills land in `.agents/skills` and personal skills in
  `~/.agents/skills`.
- Validation for Codex manifests, marketplace entries, and provider-neutral skill links.
- **`review-gate` names an ignored profile.** When `.agents/flutter-profile.yaml` and
  `.claude/flutter-profile.yaml` both exist, the report notes that the `.claude/` one was
  ignored. Two profiles that disagree used to be resolved by lookup order with nothing in
  the output to say so.
- `review-gate` documents two limits of its diff scope: a new file that was never
  `git add`-ed is not scanned, and an app in a subdirectory of its repository falls back
  to scanning everything. Both are fixed properly in 3.0.0, since scanning more files
  surfaces findings on projects that pass today.
- `validate.py` now fails the build when the Claude and Codex manifests or the marketplace
  entries disagree on description, keywords, homepage, license, or author; when the top
  `CHANGELOG.md` entry is not the version being shipped; when a skill links to another
  skill's file that `install.sh` cannot localise; and when a plugin ships a `commands/`
  file, which Codex would never see.
- An "Upgrading from 2.1.0" section in the README.

### Changed

- The suite and both marketplace catalogs now use the provider-neutral
  `flutter-craft-skills` name, following the GitHub repository's rename to
  `flutter_craft_skills`. An existing `draz-flutter` install keeps updating under its old
  name. Adding the new marketplace beside it installs every skill twice — remove the old
  one first.
- **`flutter-adapt` is now a skill rather than a command,** so Codex invokes it as
  `$flutter-adapt`. In Claude Code it is `/flutter-code-quality:flutter-adapt` from the
  plugin and `/flutter-adapt` when vendored. It still runs only when invoked
  (`disable-model-invocation: true` for Claude Code, `allow_implicit_invocation: false` in
  `agents/openai.yaml` for Codex): as a plain skill with `Write` in its tools, an agent
  could otherwise have started it mid-refactor and written files nobody asked for.
- New profiles and convention maps use `.agents/flutter-profile.yaml` and
  `.agents/flutter-conventions.md`. Existing `.claude/` files remain a supported fallback,
  and the review gate prefers `.agents/` when both exist. `flutter-adapt` now says exactly
  where it writes in each case — only `.claude/` files exist, both exist, neither — and
  offers to move the `.claude/` pair rather than leaving one of each.
- Bundled scripts and cross-skill references resolve relative to the loaded skill instead
  of relying on the Claude-only `CLAUDE_PLUGIN_ROOT` environment variable.
- `install.sh` takes exactly one of `--project`, `--personal`, and `--all-personal`, and
  exits `1` when given more. It used to take one and silently drop the rest, installing
  somewhere the user had not asked for.
- `install.sh` prints the invocation that works for what it installed — `/flutter-adapt`
  for a vendored Claude Code install — and only when it installed `flutter-adapt`.
- `install.sh` finds the `flutter-adapt` command a 2.1.0 install left in
  `.claude/commands/`, warns about it, and removes it under `--force`. It only touches a
  file carrying that command's own text.
- CI: `actions/checkout` and `actions/setup-python` move to v7, Flutter is pinned to
  3.41.9 and ruff to 0.16.5, and shellcheck now runs at its default severity over all four
  shell scripts, including `test_check_sh.sh`.

### Removed

- `plugins/flutter-code-quality/commands/flutter-adapt.md`, replaced by the
  `flutter-adapt` skill.

### Fixed

- **`compare.py` exited `1` when Pillow or numpy was missing.** `1` means "the screen
  differs", so an agent that had not installed the dependencies went off to change widget
  code. It exits `2`, "could not run", like every other failure to compare.
- **`check.sh --profile` with a path that does not exist used the defaults** and could
  exit `0` on conventions the project never asked for. It exits `2`, the same as an
  unrecognised profile value.
- **`install.sh` could not install from a path containing a space**, and `--project` with
  no path died on `unbound variable`. It also copied untracked `__pycache__` directories
  into installed skills.
- **`state-management` gave wrong advice in three places.** It told `provider` users to
  check `mounted` on a `ChangeNotifier`, which has no such property. It said every stack
  deduplicates equal states, which `setState` and `ChangeNotifier` do not. And the Riverpod
  `refresh()` example assigned `state` straight after an `await`, breaking its own rule 2.
- **`review-gate` listed a check the script does not run** — tests for new Cubit methods.
  That is a judgement call, and it now sits with the other judgement calls, for any state
  holder rather than only a Cubit.
- **`architecture`'s description** still said "Cubit or Bloc as the only bridge" and
  "feature-first" after the profile made both configurable.
- `.claude/skills` was called "legacy" in `review-gate` and `visual-verification`; it is
  where `install.sh` puts Claude Code skills by default.

## 2.1.0

Additive. Nothing's verdict changes: a project with no `.claude/flutter-profile.yaml` gets
byte-for-byte the behaviour it got under 2.0.1, and there is a test asserting it.

Until now the skills described exactly one stack — freezed, Cubit, an `AppTokens`
extension, ARB — and the README's answer for anyone else was to fork the repo, which
trades the convention problem for never receiving an update again. That was the real
ceiling on who could use these.

### Added

- **`.claude/flutter-profile.yaml`, a project profile.** Nine fields — `state`, `models`,
  `structure`, `di`, `routing`, `tokens`, `l10n`, `locales`, `strictness` — that say what
  the project actually does. Skills read it before applying any rule that names a package,
  a folder, or a severity. Every field defaults to what the skills already assumed, so the
  file is only worth writing where a project differs. Spec:
  `skills/architecture/references/flutter-profile.md`, duplicated into
  `flutter-design-fidelity` so each plugin stands alone.
- **`/flutter-code-quality:flutter-adapt`** generates the profile by inspecting
  `pubspec.yaml` and `lib/`. It records the evidence for each field it writes, marks what
  it could not determine rather than guessing, and refuses to pick a winner on its own when
  a project has two state stacks mid-migration.
- **Riverpod support.** `state-management` is now stack-agnostic: four rules that hold
  everywhere — exhaustive state shape, a liveness guard after every `await`, narrow
  rebuild subscriptions, no `BuildContext` in the state holder — with the code for them in
  `references/bloc.md` and `references/riverpod.md`, selected by the profile. `provider`,
  `signals`, and `setstate` get a translation table rather than a full reference.
- **`check.sh --profile PATH`**, and a `Profile:` line in the report naming what it
  applied. A skipped check prints as skipped with the setting that caused it — a check
  that vanishes silently is indistinguishable from one that passed.
- `validate.py` now resolves `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/references/<file>`
  links, checks `commands/` frontmatter, and fails the build if the two copies of the
  profile spec drift apart. The duplicate top-level `skills/` tree removed in 2.0.0 drifted
  because nothing compared the copies; this duplication is checked.
- **`codebase-conventions`, an eleventh skill.** Makes generated code look like the code
  already in the repository: search for an existing component by role before building a
  second one, resolve typography through the project's own source, reference only assets
  that exist and are declared, and match the file, class, and import naming already in
  use. It triggers on every code-writing task, because the failure it prevents is
  invisible — the code compiles, reads well in isolation, and quietly duplicates something
  that already existed under a different name.
- **`.claude/flutter-conventions.md`**, written by `/flutter-adapt` alongside the profile.
  It records *where* this project keeps its shared widgets, typography, and assets, and
  what its naming rules are — never a list of components. An enumerated inventory is stale
  within a week, and a stale list is worse than none because it gets trusted, so the search
  that would have found the real answer never runs.
- **Three checks in the gate, all warnings.** Inline `TextStyle(` in widget code; an asset
  path that does not resolve to a file on disk; a widget class defined in more than one
  file when the current change is part of the duplication. They warn rather than block
  because a new blocking check would fail projects that pass today, which this repo counts
  as a breaking change. The asset check is the one worth promoting in 3.0.0 — a path that
  does not resolve is a runtime crash, not a matter of style, and nothing else in the
  toolchain looks at it.
- 33 new assertions in `test_check_sh.sh` covering every profile-driven severity change
  and each new check, including that `strictness: warn` still blocks committed credentials
  and that a duplicate widget outside the current change is not reported.

### Changed

- **`review-gate` honours the profile.** `tokens: none` skips the colour, `EdgeInsets`,
  and radius checks; `tokens: theme_only` or `constants` drops them to warnings; `l10n:
  none` skips the hardcoded-string check; a declared LTR-only `locales` drops the
  directional-inset check to a warning; `strictness: warn` drops every convention finding.
  Formatting, static analysis, failing tests, and committed credentials block under every
  profile.
- **An unrecognised profile value exits `2` rather than falling back to the default.**
  Reading `riverpood` as `bloc` would enforce the opposite of what the project asked for
  with nothing in the output to say so.
- **`locales` has no default.** Leaving it out keeps the RTL check blocking, because the
  gate cannot tell whether the project ships an RTL language and the safe assumption is
  that it might. Declaring `locales: [en]` is what takes the downgrade.
- `install.sh` copies the profile spec into each vendored skill that references it and
  rewrites the link, since `${CLAUDE_PLUGIN_ROOT}` is unset outside a plugin install — the
  same failure mode `$SKILL_DIR` had in 2.0.0. It also installs `/flutter-adapt`.

### Fixed

- **`review-gate`'s description advertised a coverage check that does not exist.** The
  script has never measured coverage. Removed from the description rather than added to the
  script, which is a separate decision.
- **One of the two canary injections in `test_check_sh.sh` had no anchor assertion.** The
  malformed-pattern canary asserted its anchor was present; the missing-sample one did not,
  so a rename anywhere near it would have turned that test into a no-op that still reported
  a pass. Both assert now.

## 2.0.1

### Fixed

- **The "a broken check fails loudly" guarantee only held on macOS.** 2.0.0 detected a
  malformed pattern by testing for a grep exit code of 2 or higher. grep implementations
  disagree: given a PCRE lookahead, ugrep exits 2, but GNU grep prints a warning and exits
  1, which is indistinguishable from "no violations found". Since GNU grep is what Linux
  CI runs, the case the guarantee existed for was still silently green. Every check now
  declares a line its pattern is required to match, and a check that cannot find its own
  known violation reports itself broken rather than `ok`. This is behaviour-based, so it
  holds whatever grep is installed.

  No check shipped in 2.0.0 was actually broken; this closes the hole that would have let
  a future one hide. Caught by the canary test added in 2.0.0, running on Linux CI.

## 2.0.0

Breaking, because upgrading changes the verdict you get on code you have already shipped.
Nothing here is a new rule; it is the existing rules finally being enforced, plus two
scripts that used to fail open now failing closed.

### Breaking

- **`review-gate` will fail projects that passed under 1.0.0.** The TODO/FIXME check never
  ran (see below), the force-unwrap, `debugPrint`, commented-out-code and hardcoded-string
  checks were documented but never implemented, and all of them are live now. Run the gate
  once before upgrading anything else so the new findings arrive on their own.
- **`compare.py` errors instead of rescaling on a size mismatch.** A pipeline that quietly
  compared a 2x export against a 3x capture now exits `2` and explains that the export
  scale is wrong. Pass `--allow-resize` to keep the old behaviour, though the diff it
  produces was always noise.
- **`compare.py` fails localized defects that used to pass.** The new `--max-cluster`
  threshold (default 0.25) grades the worst cell of a 12×12 grid alongside the global
  share. Screens that scraped past the 2% global threshold on a single wrong-colored
  element will now fail — correctly.
- **Exit code `2` is new on both scripts** and means *the check could not run*, not *the
  code is fine*. Any CI step branching on `!= 0` is unaffected; one branching on `== 1`
  needs updating.
- **The top-level `skills/` directory is gone.** Only reachable by copying out of a git
  clone by hand, which the README has called the pre-v1.0.0 layout since 1.0.0. Marketplace
  and `install.sh` users are unaffected.

### Fixed

- **`review-gate` reported a passing check that could never fail.** The TODO/FIXME rule
  used `grep -E 'TODO(?!\()|FIXME'` — a PCRE negative lookahead handed to POSIX ERE. It
  exited 2 on every run, the call site sent stderr to `/dev/null` and ended in `|| true`,
  and the gate printed `ok: TODOs carry a ticket reference` for its entire life. Rewritten
  as an ERE match minus the ticket-carrying hits, and `check_pattern` now distinguishes
  grep's three exit states so a malformed pattern fails loudly instead of reporting clean.
- **`review-gate` failed on correct code.** `Color(0x...)` and numeric `EdgeInsets` were
  blocking with no path exclusions, so a project's own token layer — the one place those
  literals belong — failed by construction. Generated files (`*.g.dart`, `*.freezed.dart`,
  and similar), tests, and `theme/`, `tokens/`, `design_system/` are now carved out.
- **`review-gate` documented checks it did not run.** SKILL.md listed eight forbidden
  patterns; the script implemented five, one of them broken, plus one the doc never
  mentioned. The two lists are now identical, with severities stated.
- **`review-gate` could not name a failing test.** `flutter test` output went to
  `/dev/null`. Failures are captured and reported.
- **`review-gate` reported clean when it had not run.** No preconditions — pointed at a
  non-Flutter directory it produced an empty, passing report. It now exits `2`.
- **`visual-verification` wrote a diff image that measured 98% pure black.**
  `ImageChops.difference` is a near-zero delta wherever the images agree, so the artifact
  the skill told you to open carried no information. It is now the capture, faded, with
  differing pixels burned in as red.
- **`visual-verification` crashed with a raw traceback** on a missing or unreadable file.
  Clean message, exit `2`.
- **`$SKILL_DIR` is not a real variable.** Both skills instructed the model to resolve it
  by hand. Replaced with `${CLAUDE_PLUGIN_ROOT}`, which Claude Code sets and the shell
  expands on its own. `validate.py` rejects any reappearance of `$SKILL_DIR`.
- **`install.sh` could never update a vendored skill.** It skipped anything already
  present with no override, so a user who ran it once was pinned forever. Added `--force`.

### Added

- `--ignore-region X,Y,W,H` on `compare.py` (repeatable) for inherently dynamic content,
  so a status bar clock no longer forces the threshold up for the whole screen.
- `--skip-tests` and `--all` on `check.sh`.
- A "judgement the script cannot make" section in `review-gate`, naming the findings that
  need the diff read rather than grepped — whether a golden was reviewed or just
  regenerated, whether a force-unwrap's justification is true, whether a new dependency
  was necessary.
- Documentation of the exclusion carve-outs in `review-gate`, so the agent knows why some
  literals are not flagged rather than assuming the check is broken.
- `scripts/validate.py` — frontmatter, name/directory agreement, description limits,
  manifest/marketplace version agreement, duplicate skill names, dangling `scripts/` and
  `references/` links, and a guard against the duplicate tree returning.
- `scripts/test_check_sh.sh` and `scripts/test_compare.py` — 39 behavioural assertions,
  including a canary that injects a malformed pattern and asserts the gate refuses to
  report `ok`.
- `.github/workflows/validate.yml` running all three plus `shellcheck` and `ruff`.

### Removed

- **The duplicate top-level `skills/` tree.** It mirrored `plugins/*/skills/`, nothing
  synced them, and two of ten files had already drifted within a handful of commits.
  `install.sh` read from `plugins/`, so the mirror was dead weight that could only go
  stale. `plugins/` is now the only source of truth.

## 1.0.0

Initial release: `flutter-design-fidelity` (design-tokens, figma-to-widget,
visual-verification, golden-tests) and `flutter-code-quality` (architecture,
state-management, responsive-adaptive, a11y-and-rtl, performance, review-gate).
