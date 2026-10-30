#!/usr/bin/env bash
# Vendor the skills directly into a project or into a personal skills directory,
# as an alternative to installing through a Claude Code or Codex marketplace.
#
# Marketplace install (recommended):
#   claude plugin marketplace add draz26648/flutter_craft_skills
#   claude plugin install flutter-design-fidelity@flutter-craft-skills
#   claude plugin install flutter-code-quality@flutter-craft-skills
#
# Codex marketplace install:
#   codex plugin marketplace add draz26648/flutter_craft_skills
#   codex plugin add flutter-design-fidelity@flutter-craft-skills
#   codex plugin add flutter-code-quality@flutter-craft-skills

set -euo pipefail

PROJECT=""
PERSONAL_ONLY=false
ALL_PERSONAL=false
FORCE=false
AGENT=claude

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

  --project <path>   Copy project-scoped skills into the selected agent's project path
  --personal         Copy only the machine-scoped skills into the personal path
  --all-personal     Copy every skill into the personal path
  --claude           Install for Claude Code (default)
  --codex            Install for Codex
  --both             Install for both Claude Code and Codex
  --force            Overwrite skills that are already installed, and remove the
                     2.1.0 flutter-adapt command if one is found
  -h, --help         Show this message

Give exactly one of --project, --personal, or --all-personal.

Without --force an already-installed skill is left alone, so local edits survive.
That also means it never updates — re-run with --force to take a new version, and
diff first if you have adapted it.

Claude Code uses `.claude/skills` and `~/.claude/skills`. Codex uses `.agents/skills`
and `~/.agents/skills`. With --project, the machine-scoped skills (performance,
review-gate) also go to the selected personal path so they follow you across projects.

Vendoring is the right choice when you want the skills committed to the repo and
reviewable in pull requests alongside the code they govern. Otherwise prefer the
marketplace, which gives you updates.
USAGE
}

die() {
  echo "install.sh: $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --project)
      # A missing value, or the next flag in its place, is a mistake rather than a path.
      case "${2:-}" in ''|-*) die "--project needs a path" ;; esac
      PROJECT="$2"; shift 2 ;;
    --personal) PERSONAL_ONLY=true; shift ;;
    --all-personal) ALL_PERSONAL=true; shift ;;
    --claude) AGENT=claude; shift ;;
    --codex) AGENT=codex; shift ;;
    --both) AGENT=both; shift ;;
    --force) FORCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "install.sh: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Each scope installs to a different place, so taking one and dropping the others would
# put the skills somewhere the user did not ask for.
SCOPES=0
[ -n "$PROJECT" ] && SCOPES=$((SCOPES + 1))
[ "$PERSONAL_ONLY" = true ] && SCOPES=$((SCOPES + 1))
[ "$ALL_PERSONAL" = true ] && SCOPES=$((SCOPES + 1))
if [ "$SCOPES" -eq 0 ]; then
  usage >&2
  exit 1
fi
[ "$SCOPES" -eq 1 ] || die "--project, --personal, and --all-personal are mutually exclusive"

ROOT="$(cd "$(dirname "$0")" && pwd)"
DESIGN="$ROOT/plugins/flutter-design-fidelity/skills"
QUALITY="$ROOT/plugins/flutter-code-quality/skills"
PROFILE_SPEC="$QUALITY/architecture/references/flutter-profile.md"
PERSONAL_ROOT="${FLUTTER_SKILLS_HOME:-$HOME}"

# Arrays rather than echoed lists, so a clone under a path with spaces still installs.
PROJECT_SKILLS=(
  "$DESIGN/design-tokens" "$DESIGN/figma-to-widget" "$DESIGN/visual-verification"
  "$DESIGN/golden-tests" "$QUALITY/architecture" "$QUALITY/state-management"
  "$QUALITY/responsive-adaptive" "$QUALITY/a11y-and-rtl" "$QUALITY/codebase-conventions"
  "$QUALITY/flutter-adapt"
)
PERSONAL_SKILLS=("$QUALITY/performance" "$QUALITY/review-gate")

# The 2.1.0 installer vendored flutter-adapt as a command. Its description line was
# copied verbatim (only the spec path was rewritten), so it identifies that file without
# claiming a user's own command of the same name.
STALE_COMMAND_MARKER='Inspect this Flutter project and write .claude/flutter-profile.yaml'

# Cross-skill links work while a whole plugin is installed, but not when the skills are
# vendored independently. Give each vendored skill its own copy of the shared spec.
localise_profile_link() {
  local skill_dir="$1" md="$1/SKILL.md"
  [ -f "$md" ] || return 0
  grep -Eq '\.\./[a-z0-9-]+/references/flutter-profile\.md' "$md" || return 0
  mkdir -p "$skill_dir/references"
  cp "$PROFILE_SPEC" "$skill_dir/references/flutter-profile.md"
  sed -E 's|\.\./[a-z0-9-]+/references/flutter-profile\.md|references/flutter-profile.md|g' \
    "$md" > "$md.tmp" && mv "$md.tmp" "$md"
}

# A working clone can hold untracked Python caches. Drop them from the copy only.
strip_caches() {
  find "$1" -type d \( -name __pycache__ -o -name .dart_tool \) -prune -exec rm -rf {} +
  find "$1" -type f -name '*.pyc' -exec rm -f {} +
}

copy_skill() {
  local src="$1" dest="$2" name
  name="$(basename "$src")"
  if [ -d "$dest/$name" ]; then
    if [ "$FORCE" = true ]; then
      rm -rf "${dest:?}/${name:?}"
      cp -r "$src" "$dest/"
      strip_caches "$dest/$name"
      localise_profile_link "$dest/$name"
      echo "  updated $name"
    else
      echo "  skip $name (already installed — re-run with --force to update)"
    fi
  else
    cp -r "$src" "$dest/"
    strip_caches "$dest/$name"
    localise_profile_link "$dest/$name"
    echo "  added $name"
  fi
}

# The 2.1.0 command still writes .claude/flutter-profile.yaml and would sit beside the
# flutter-adapt skill as a second /flutter-adapt. Only a file carrying its marker is touched.
check_stale_command() {
  local cmd="$1"
  [ -f "$cmd" ] || return 0
  grep -Fq "$STALE_COMMAND_MARKER" "$cmd" || return 0
  if [ "$FORCE" = true ]; then
    rm -f "$cmd"
    echo "  removed stale $cmd (2.1.0 command, replaced by the flutter-adapt skill)"
  else
    echo "  warning: $cmd is the 2.1.0 flutter-adapt command, which still writes"
    echo "           .claude/flutter-profile.yaml. Re-run with --force to remove it, or delete it by hand."
  fi
}

install_for_agent() {
  local agent="$1" project_dest personal_dest invocation s
  case "$agent" in
    claude)
      project_dest="$PROJECT/.claude/skills"
      personal_dest="$PERSONAL_ROOT/.claude/skills"
      # Vendored skills are not namespaced by their plugin.
      invocation="/flutter-adapt"
      ;;
    codex)
      project_dest="$PROJECT/.agents/skills"
      personal_dest="$PERSONAL_ROOT/.agents/skills"
      invocation="\$flutter-adapt"
      ;;
  esac

  if [ "$ALL_PERSONAL" = true ]; then
    echo "Copying all skills for $agent to $personal_dest/"
    mkdir -p "$personal_dest"
    for s in "${PROJECT_SKILLS[@]}" "${PERSONAL_SKILLS[@]}"; do copy_skill "$s" "$personal_dest"; done
    printf '  adapt with: %s\n' "$invocation"

  elif [ "$PERSONAL_ONLY" = true ]; then
    echo "Copying machine-scoped skills for $agent to $personal_dest/"
    mkdir -p "$personal_dest"
    for s in "${PERSONAL_SKILLS[@]}"; do copy_skill "$s" "$personal_dest"; done
    echo "  note: flutter-adapt not installed — it needs the architecture skill, which"
    echo "        --personal does not copy. Use --project or --all-personal for it."

  else
    echo "Copying project skills for $agent to $project_dest/"
    mkdir -p "$project_dest"
    for s in "${PROJECT_SKILLS[@]}"; do copy_skill "$s" "$project_dest"; done
    echo "Copying machine-scoped skills for $agent to $personal_dest/"
    mkdir -p "$personal_dest"
    for s in "${PERSONAL_SKILLS[@]}"; do copy_skill "$s" "$personal_dest"; done
    printf '  adapt with: %s\n' "$invocation"
  fi

  if [ "$agent" = claude ]; then
    [ -z "$PROJECT" ] || check_stale_command "$PROJECT/.claude/commands/flutter-adapt.md"
    check_stale_command "$PERSONAL_ROOT/.claude/commands/flutter-adapt.md"
  fi
}

if [ -n "$PROJECT" ]; then
  [ -f "$PROJECT/pubspec.yaml" ] || echo "Warning: no pubspec.yaml at $PROJECT — is that a Flutter project?"
fi

case "$AGENT" in
  claude|codex) install_for_agent "$AGENT" ;;
  both)
    install_for_agent claude
    install_for_agent codex
    ;;
esac

cat <<'NEXT'

Done.

Next:
  1. Restart the agent if its skills directory did not exist before.
  2. Verify the installed */skills/*/SKILL.md files.
  3. Run flutter-adapt to generate .agents/flutter-profile.yaml, so the skills describe
     your stack rather than the defaults they ship with.
NEXT
