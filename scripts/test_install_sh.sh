#!/usr/bin/env bash
# Behavioural tests for Claude Code, Codex, and dual-agent vendoring.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

OUT="$WORK/stdout"
ERR="$WORK/stderr"
STATUS=0

PROJECT_SKILL_NAMES="design-tokens figma-to-widget visual-verification golden-tests architecture state-management responsive-adaptive a11y-and-rtl codebase-conventions flutter-adapt"
PERSONAL_SKILL_NAMES="performance review-gate"

FAILURES=0
ok()  { printf '  ok   %s\n' "$1"; }
bad() { FAILURES=$((FAILURES + 1)); printf '  FAIL %s\n' "$1"; }

expect_file() {
  if [ -f "$1" ]; then ok "$2"; else bad "$2 (missing $1)"; fi
}

expect_absent() {
  if [ ! -e "$1" ]; then ok "$2"; else bad "$2 (unexpected $1)"; fi
}

expect_contains() {
  if grep -Fq -- "$2" "$1"; then ok "$3"; else bad "$3 (missing '$2' in $1)"; fi
}

expect_not_contains() {
  if grep -Fq -- "$2" "$1"; then bad "$3 (found '$2' in $1)"; else ok "$3"; fi
}

expect_same() {
  if cmp -s "$1" "$2"; then ok "$3"; else bad "$3 ($1 differs from $2)"; fi
}

expect_status() {
  if [ "$STATUS" -eq "$1" ]; then ok "$2"; else bad "$2 (exit $STATUS, wanted $1)"; fi
}

expect_failure() {
  if [ "$STATUS" -ne 0 ]; then ok "$1"; else bad "$1 (exit 0)"; fi
}

expect_empty() {
  if [ ! -s "$1" ]; then ok "$2"; else bad "$2 ($1 has: $(head -n 1 "$1"))"; fi
}

# expect_skills <dir> <label> <names...>
expect_skills() {
  local dir="$1" label="$2" name missing=""
  shift 2
  for name in "$@"; do
    [ -f "$dir/$name/SKILL.md" ] || missing="$missing $name"
  done
  if [ -z "$missing" ]; then ok "$label"; else bad "$label (missing in $dir:$missing)"; fi
}

# A vendored skill has to stand alone: no link out of its own directory, and a local copy
# of the profile spec wherever its SKILL.md points at one.
expect_self_contained() {
  local dir="$1" where="${1#"$WORK"/}" md skill found=0 escaping="" unresolved=""
  for md in "$dir"/*/SKILL.md; do
    [ -f "$md" ] || continue
    found=$((found + 1))
    skill="$(dirname "$md")"
    grep -Fq '../' "$md" && escaping="$escaping $(basename "$skill")"
    if grep -Fq 'references/flutter-profile.md' "$md" && [ ! -f "$skill/references/flutter-profile.md" ]; then
      unresolved="$unresolved $(basename "$skill")"
    fi
  done
  if [ "$found" -eq 0 ]; then
    bad "skills are installed in $where (none found)"
    return
  fi
  if [ -z "$escaping" ]; then ok "no ../ links in $where"; else bad "no ../ links in $where (found in:$escaping)"; fi
  if [ -z "$unresolved" ]; then
    ok "profile spec is local wherever referenced in $where"
  else
    bad "profile spec is local wherever referenced in $where (missing for:$unresolved)"
  fi
}

# run_script <installer> <home> <args...> leaves $OUT, $ERR and $STATUS behind.
# The home is always a throwaway directory, so no test can reach the real $HOME.
run_script() {
  local script="$1" home="$2"
  shift 2
  STATUS=0
  FLUTTER_SKILLS_HOME="$home" bash "$script" "$@" >"$OUT" 2>"$ERR" || STATUS=$?
}

run_install() {
  run_script "$INSTALLER" "$@"
}

make_project() {
  local project="$1"
  mkdir -p "$project/lib"
  printf 'dependencies:\n  flutter:\n    sdk: flutter\n' > "$project/pubspec.yaml"
}

# What the 2.1.0 installer left at .claude/commands/flutter-adapt.md, trimmed to the
# frontmatter and a line of body. The description line is the part install.sh keys on.
write_stale_command() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'CMD'
---
description: Inspect this Flutter project and write .claude/flutter-profile.yaml and .claude/flutter-conventions.md so the skills describe this codebase instead of fighting it
allowed-tools: Read, Grep, Glob, Bash, Write
---

# Adapt the skills to this project

Read `.claude/skills/architecture/references/flutter-profile.md` first for
CMD
}

echo "== Codex project install =="
CODEX_PROJECT="$WORK/codex-project"
CODEX_TEST_HOME="$WORK/codex-home"
make_project "$CODEX_PROJECT"
run_install "$CODEX_TEST_HOME" --codex --project "$CODEX_PROJECT"
expect_status 0 "Codex project install succeeds"

expect_file "$CODEX_PROJECT/.agents/skills/design-tokens/SKILL.md" \
  "project skills use .agents/skills"
expect_file "$CODEX_PROJECT/.agents/skills/flutter-adapt/SKILL.md" \
  "flutter-adapt installs as a Codex skill"
expect_file "$CODEX_TEST_HOME/.agents/skills/review-gate/SKILL.md" \
  "machine-scoped Codex skills use the personal path"
expect_absent "$CODEX_PROJECT/.agents/skills/review-gate" \
  "machine-scoped skills are not copied into the project"
expect_absent "$CODEX_PROJECT/.claude" \
  "Codex-only install does not create Claude directories"
expect_contains "$OUT" "adapt with: \$flutter-adapt" \
  "Codex install names the Codex invocation"

ADAPT="$CODEX_PROJECT/.agents/skills/flutter-adapt/SKILL.md"
expect_file "$CODEX_PROJECT/.agents/skills/flutter-adapt/references/flutter-profile.md" \
  "vendored cross-skill references are copied locally"
expect_contains "$ADAPT" 'references/flutter-profile.md' \
  "vendored skill points at its local profile reference"
expect_not_contains "$ADAPT" '../architecture/references/flutter-profile.md' \
  "vendored skill no longer depends on its sibling"
expect_self_contained "$CODEX_PROJECT/.agents/skills"
expect_self_contained "$CODEX_TEST_HOME/.agents/skills"

echo "== Claude project install (default agent) =="
CLAUDE_PROJECT="$WORK/claude-project"
CLAUDE_TEST_HOME="$WORK/claude-home"
make_project "$CLAUDE_PROJECT"
run_install "$CLAUDE_TEST_HOME" --project "$CLAUDE_PROJECT"
expect_status 0 "Claude project install succeeds"

# shellcheck disable=SC2086 # the name lists are deliberately split
expect_skills "$CLAUDE_PROJECT/.claude/skills" "project skills use .claude/skills" $PROJECT_SKILL_NAMES
# shellcheck disable=SC2086
expect_skills "$CLAUDE_TEST_HOME/.claude/skills" \
  "machine-scoped Claude skills use the personal path" $PERSONAL_SKILL_NAMES
expect_absent "$CLAUDE_PROJECT/.claude/skills/performance" \
  "performance is not copied into the project"
expect_absent "$CLAUDE_PROJECT/.claude/skills/review-gate" \
  "review-gate is not copied into the project"
expect_absent "$CLAUDE_PROJECT/.agents" \
  "Claude-only install does not create Codex directories in the project"
expect_absent "$CLAUDE_TEST_HOME/.agents" \
  "Claude-only install does not create Codex directories in the personal path"
expect_contains "$OUT" "adapt with: /flutter-adapt" \
  "Claude install names the vendored invocation"
expect_not_contains "$OUT" "flutter-code-quality:flutter-adapt" \
  "vendored invocation is not plugin-namespaced"
expect_self_contained "$CLAUDE_PROJECT/.claude/skills"
expect_self_contained "$CLAUDE_TEST_HOME/.claude/skills"

echo "== dual project install =="
BOTH_PROJECT="$WORK/both-project"
BOTH_PROJECT_HOME="$WORK/both-project-home"
make_project "$BOTH_PROJECT"
run_install "$BOTH_PROJECT_HOME" --both --project "$BOTH_PROJECT"
expect_status 0 "dual project install succeeds"

for base in "$BOTH_PROJECT/.claude/skills" "$BOTH_PROJECT/.agents/skills"; do
  # shellcheck disable=SC2086
  expect_skills "$base" "both installs project skills in ${base#"$WORK"/}" $PROJECT_SKILL_NAMES
  expect_self_contained "$base"
done
for base in "$BOTH_PROJECT_HOME/.claude/skills" "$BOTH_PROJECT_HOME/.agents/skills"; do
  # shellcheck disable=SC2086
  expect_skills "$base" "both installs machine-scoped skills in ${base#"$WORK"/}" $PERSONAL_SKILL_NAMES
  expect_self_contained "$base"
done

echo "== dual personal install =="
BOTH_TEST_HOME="$WORK/both-home"
run_install "$BOTH_TEST_HOME" --both --all-personal
expect_status 0 "dual personal install succeeds"

for base in "$BOTH_TEST_HOME/.agents/skills" "$BOTH_TEST_HOME/.claude/skills"; do
  expect_file "$base/design-tokens/SKILL.md" "both installs design skills in ${base#"$WORK"/}"
  expect_file "$base/flutter-adapt/SKILL.md" "both installs flutter-adapt in ${base#"$WORK"/}"
  expect_file "$base/review-gate/SKILL.md" "both installs review-gate in ${base#"$WORK"/}"
  expect_self_contained "$base"
done

echo "== Codex machine-only install =="
PERSONAL_TEST_HOME="$WORK/personal-home"
run_install "$PERSONAL_TEST_HOME" --codex --personal
expect_status 0 "machine-only install succeeds"
expect_file "$PERSONAL_TEST_HOME/.agents/skills/performance/SKILL.md" \
  "--personal installs performance"
expect_file "$PERSONAL_TEST_HOME/.agents/skills/review-gate/SKILL.md" \
  "--personal installs review-gate"
expect_absent "$PERSONAL_TEST_HOME/.agents/skills/flutter-adapt" \
  "--personal omits project-scoped skills"
expect_not_contains "$OUT" "adapt with:" \
  "--personal does not offer an invocation it did not install"
expect_self_contained "$PERSONAL_TEST_HOME/.agents/skills"

echo "== --force =="
FORCE_PROJECT="$WORK/force-project"
FORCE_HOME="$WORK/force-home"
FORCE_SKILL="$FORCE_PROJECT/.claude/skills/architecture/SKILL.md"
FORCE_SOURCE="$ROOT/plugins/flutter-code-quality/skills/architecture/SKILL.md"
make_project "$FORCE_PROJECT"
run_install "$FORCE_HOME" --project "$FORCE_PROJECT"
expect_status 0 "first install succeeds"
printf '\nLOCAL EDIT\n' >> "$FORCE_SKILL"

run_install "$FORCE_HOME" --project "$FORCE_PROJECT"
expect_status 0 "re-install without --force succeeds"
expect_contains "$FORCE_SKILL" "LOCAL EDIT" \
  "without --force a local edit survives"
expect_contains "$OUT" "skip architecture" \
  "without --force the installed skill is reported as skipped"

run_install "$FORCE_HOME" --force --project "$FORCE_PROJECT"
expect_status 0 "re-install with --force succeeds"
expect_same "$FORCE_SKILL" "$FORCE_SOURCE" \
  "--force restores the shipped SKILL.md"
expect_contains "$OUT" "updated architecture" \
  "--force reports the skill as updated"
expect_self_contained "$FORCE_PROJECT/.claude/skills"

echo "== argument handling =="
HELP_HOME="$WORK/help-home"
run_install "$HELP_HOME" --help
expect_status 0 "--help exits 0"
expect_empty "$ERR" "--help writes nothing to stderr"
expect_contains "$OUT" "\`.claude/skills\`" \
  "--help prints the Claude path literally"
expect_contains "$OUT" "\`~/.agents/skills\`" \
  "--help prints the Codex personal path literally"
expect_absent "$HELP_HOME" "--help installs nothing"

MISSING_HOME="$WORK/missing-value-home"
run_install "$MISSING_HOME" --project
expect_failure "--project without a path fails"
expect_not_contains "$ERR" "unbound variable" \
  "--project without a path fails cleanly"
expect_contains "$ERR" "--project needs a path" \
  "--project without a path says what is missing"
expect_absent "$MISSING_HOME" "--project without a path installs nothing"

run_install "$MISSING_HOME" --project --force
expect_failure "--project followed by a flag fails"

CONFLICT_PROJECT="$WORK/conflict-project"
CONFLICT_HOME="$WORK/conflict-home"
make_project "$CONFLICT_PROJECT"
run_install "$CONFLICT_HOME" --personal --project "$CONFLICT_PROJECT"
expect_failure "--personal with --project fails"
expect_contains "$ERR" "mutually exclusive" \
  "--personal with --project explains the conflict"
expect_absent "$CONFLICT_PROJECT/.claude" "--personal with --project installs nothing in the project"
expect_absent "$CONFLICT_HOME" "--personal with --project installs nothing personally"

run_install "$CONFLICT_HOME" --all-personal --personal
expect_failure "--all-personal with --personal fails"
expect_absent "$CONFLICT_HOME" "--all-personal with --personal installs nothing"

run_install "$CONFLICT_HOME" --bogus
expect_failure "an unknown option fails"
expect_contains "$ERR" "unknown option: --bogus" \
  "an unknown option is reported on stderr"

echo "== paths with spaces =="
SPACE_REPO="$WORK/repo with space"
SPACE_PROJECT="$WORK/app with space"
SPACE_HOME="$WORK/home with space"
SPACE_CACHE="$SPACE_REPO/plugins/flutter-design-fidelity/skills/visual-verification/scripts"
mkdir -p "$SPACE_REPO"
cp "$INSTALLER" "$SPACE_REPO/install.sh"
cp -R "$ROOT/plugins" "$SPACE_REPO/"
mkdir -p "$SPACE_CACHE/__pycache__" "$SPACE_CACHE/.dart_tool"
: > "$SPACE_CACHE/.dart_tool/package_config.json"
: > "$SPACE_CACHE/__pycache__/x.pyc"
: > "$SPACE_CACHE/stray.pyc"
# Skill names may carry digits, so a link to one must still be localised.
DIGIT_LINK="$SPACE_REPO/plugins/flutter-design-fidelity/skills/golden-tests/SKILL.md"
sed 's|\.\./design-tokens/references|../l10n-2/references|' "$DIGIT_LINK" > "$DIGIT_LINK.tmp" \
  && mv "$DIGIT_LINK.tmp" "$DIGIT_LINK"
make_project "$SPACE_PROJECT"

run_script "$SPACE_REPO/install.sh" "$SPACE_HOME" --project "$SPACE_PROJECT"
expect_status 0 "install from a path with spaces succeeds"
expect_empty "$ERR" "install from a path with spaces writes nothing to stderr"
# shellcheck disable=SC2086
expect_skills "$SPACE_PROJECT/.claude/skills" \
  "project skills install into a path with spaces" $PROJECT_SKILL_NAMES
# shellcheck disable=SC2086
expect_skills "$SPACE_HOME/.claude/skills" \
  "machine-scoped skills install into a path with spaces" $PERSONAL_SKILL_NAMES
CACHES="$(find "$SPACE_PROJECT/.claude/skills" "$SPACE_HOME/.claude/skills" \
  \( -name __pycache__ -o -name '*.pyc' -o -name .dart_tool \) 2>/dev/null)"
if [ -z "$CACHES" ]; then
  ok "Python and Dart caches are stripped from installed skills"
else
  bad "Python and Dart caches are stripped from installed skills (found: $CACHES)"
fi
expect_file "$SPACE_CACHE/.dart_tool/package_config.json" "Dart cache in source tree is left alone"
expect_file "$SPACE_CACHE/__pycache__/x.pyc" "caches in the source tree are left alone"
expect_contains "$DIGIT_LINK" "../l10n-2/references/flutter-profile.md" \
  "the source copy links to a sibling whose name has a digit"
expect_self_contained "$SPACE_PROJECT/.claude/skills"
expect_self_contained "$SPACE_HOME/.claude/skills"

echo "== stale 2.1.0 command =="
STALE_PROJECT="$WORK/stale-project"
STALE_HOME="$WORK/stale-home"
STALE_PROJECT_CMD="$STALE_PROJECT/.claude/commands/flutter-adapt.md"
STALE_HOME_CMD="$STALE_HOME/.claude/commands/flutter-adapt.md"
make_project "$STALE_PROJECT"
write_stale_command "$STALE_PROJECT_CMD"
write_stale_command "$STALE_HOME_CMD"

run_install "$STALE_HOME" --codex --force --project "$STALE_PROJECT"
expect_status 0 "Codex install beside a stale command succeeds"
expect_file "$STALE_PROJECT_CMD" "a Codex-only install leaves the Claude command alone"
expect_not_contains "$OUT" "2.1.0" "a Codex-only install does not mention the Claude command"

run_install "$STALE_HOME" --project "$STALE_PROJECT"
expect_status 0 "install beside a stale command succeeds"
expect_file "$STALE_PROJECT_CMD" "without --force the stale project command is kept"
expect_file "$STALE_HOME_CMD" "without --force the stale personal command is kept"
expect_contains "$OUT" "warning: $STALE_PROJECT_CMD is the 2.1.0" \
  "without --force the stale project command is named"
expect_contains "$OUT" "warning: $STALE_HOME_CMD is the 2.1.0" \
  "without --force the stale personal command is named"
expect_contains "$OUT" "--force" "the warning says how to remove it"

run_install "$STALE_HOME" --force --project "$STALE_PROJECT"
expect_status 0 "install with --force beside a stale command succeeds"
expect_absent "$STALE_PROJECT_CMD" "--force removes the stale project command"
expect_absent "$STALE_HOME_CMD" "--force removes the stale personal command"
expect_contains "$OUT" "removed stale $STALE_PROJECT_CMD (2.1.0 command" \
  "--force reports the removal"

USER_PROJECT="$WORK/user-command-project"
USER_HOME="$WORK/user-command-home"
USER_CMD="$USER_PROJECT/.claude/commands/flutter-adapt.md"
make_project "$USER_PROJECT"
mkdir -p "$(dirname "$USER_CMD")"
printf -- '---\ndescription: My own adapt command\n---\n\nDo it my way.\n' > "$USER_CMD"
cp "$USER_CMD" "$WORK/user-command.orig"

run_install "$USER_HOME" --force --project "$USER_PROJECT"
expect_status 0 "install with --force beside a user command succeeds"
expect_same "$USER_CMD" "$WORK/user-command.orig" \
  "--force never touches a flutter-adapt command without the 2.1.0 marker"
expect_not_contains "$OUT" "stale" "a user command is not reported as stale"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "all installer tests passed"
  exit 0
fi
echo "$FAILURES installer test(s) failed"
exit 1
