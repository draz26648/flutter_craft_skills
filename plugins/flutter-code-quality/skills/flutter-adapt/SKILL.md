---
name: flutter-adapt
description: "Inspect a Flutter project and create or regenerate its agent profile and conventions when explicitly requested. Preserve existing user decisions."
allowed-tools: Read, Grep, Glob, Bash, Write
disable-model-invocation: true
---

# Adapt the skills to this project

Two files come out of this:

- **`.agents/flutter-profile.yaml`** — the stack decisions. Nine fields, read by every
  skill and by the review gate.
- **`.agents/flutter-conventions.md`** — where this project keeps its shared widgets,
  typography, colours, and assets, and what its naming rules are.

Do both. Part 1 is below; Part 2 is at the end.

# Part 1 — the profile

Work out how this project is actually built, then write `.agents/flutter-profile.yaml`.

Read `../architecture/references/flutter-profile.md`, relative to this skill directory,
first for the field list and the meaning of each value. Do not invent values outside it.

## Rules for this skill

**Evidence, not vibes.** Every field you write carries a comment naming what you saw. A
dependency in `pubspec.yaml` is weak evidence on its own — packages linger long after the
code stops using them. Confirm in `lib/`.

**Say when you do not know.** Omit fields you cannot determine and add a comment with
the evidence needed to resolve them. Do not encode uncertainty as an enforceable default. A confidently wrong
profile is worse than no profile, because the skills then enforce the wrong conventions
with no sign anything is off.

**Preserve user decisions.** Read existing files first. An explicit request to create or
regenerate authorizes that work; do not ask again before an ordinary authorized write.
Preserve manual choices and explain changes. Ask only to resolve a material conflict or
to perform a migration/deletion outside the requested scope. Where the result goes
depends on what already exists:

| Already there | Write to |
|---|---|
| Neither file | `.agents/flutter-profile.yaml` |
| Only `.claude/flutter-profile.yaml` | Update it in place. Offer to move it — and `.claude/flutter-conventions.md` with it — to `.agents/`, and move both only if the user agrees. Never leave a copy in each directory. |
| Both | Update `.agents/flutter-profile.yaml`, and tell the user the `.claude/` copy is ignored: the review gate and every skill read `.agents/` first. Offer to delete the `.claude/` copy. |

Two profiles that disagree are worse than either one, because which of them applies
depends on a lookup order nobody remembers.

**Do not change any other file.** Not `pubspec.yaml`, not `analysis_options.yaml`, not
the code. This skill describes the project; it does not reform it.

## Steps

1. Confirm there is a `pubspec.yaml` with a `flutter:` dependency here. If not, say so and
   stop — the profile is meaningless outside a Flutter project.

2. Read `pubspec.yaml` in full. Note the dependency list and the `flutter:` section.

3. Determine each field from the signals below, checking `lib/` for each one rather than
   trusting the dependency alone.

   | Field | Look for |
   |---|---|
   | `state` | `flutter_bloc` + `extends Cubit`/`extends Bloc` → `bloc`; `riverpod`/`riverpod_annotation` + `Notifier`/`@riverpod` → `riverpod`; `provider` + `ChangeNotifier` → `provider`; `signals_flutter` → `signals`; none of these, with `setState(` in use → `setstate` |
   | `models` | `@freezed` → `freezed`; `@MappableClass` → `dart_mappable`; `@JsonSerializable` → `json_serializable`; hand-written `fromJson` → `manual` |
   | `structure` | `lib/features/<name>/` → `feature_first`; top-level `lib/data`, `lib/domain`, `lib/presentation` → `layer_first` |
   | `di` | `injectable` → `injectable`; `get_it` alone → `get_it`; neither, with `state: riverpod` → `riverpod`; neither, with `provider` → `provider`; otherwise `none` |
   | `routing` | `go_router` → `go_router`; `auto_route` → `auto_route`; `Navigator.push` only → `navigator` |
   | `tokens` | `ThemeExtension<` → `theme_extension`; a `theme/` directory building `ThemeData` with no extension → `theme_only`; an `AppColors`-style class of static constants → `constants`; colours written inline at call sites → `none` |
   | `l10n` | `generate: true` plus `.arb` files or `l10n.yaml` → `arb`; `easy_localization` → `easy_localization`; `slang` → `slang`; otherwise `none` |
   | `locales` | `.arb` filename suffixes (`app_ar.arb` → `ar`), or `supportedLocales` in the `MaterialApp` |

4. Preserve explicit `strictness`; for a new profile use `warn` and explain that
   convention rules are advisory while analyzer, formatter, tests and detected secrets
   still block. Do not infer strictness from repository size.

5. When stacks coexist, inspect the affected feature and any migration instructions.
   Local setState is compatible with Bloc/Riverpod. If the intended shared stack remains
   ambiguous, omit the field and record the uncertainty; a majority count is not intent.

6. Print a table of field, value, and evidence. Then write the file.

## Output format

```yaml
# .agents/flutter-profile.yaml
# Generated by flutter-adapt. Edit freely — it is read, not managed.
state: riverpod        # 14 files with @riverpod, no flutter_bloc dependency
models: freezed        # freezed 2.5.7, 22 @freezed classes
structure: feature_first  # lib/features/{wallet,auth,profile}
di: riverpod           # no get_it; repositories are providers
routing: go_router     # go_router 14.6.2, lib/core/router/app_router.dart
tokens: theme_extension   # ThemeExtension<AppTokens> in lib/core/theme/app_tokens.dart
l10n: arb              # generate: true, 3 .arb files under lib/l10n
locales: [en, ar]      # app_en.arb, app_ar.arb
strictness: warn       # initial adoption; preserve an explicit existing setting
```

Then, in your reply and not in the file:

- what you could not determine and what would settle it
- anything you found that the profile has no field for but that the skills will get wrong
  anyway — a custom navigation wrapper, a home-grown DI container, a token layer with two
  competing entry points. Those are worth naming even though nothing can be written for
  them, because the alternative is the user discovering it when a skill argues with their
  codebase.

# Part 2 — the conventions

Now write `.agents/flutter-conventions.md`, which is what makes generated code look like
the code already here.

## The rule that keeps this file useful

**Record locations and rules. Never enumerate contents.**

"Shared widgets live in `lib/core/widgets/`, named `App<Thing>`" stays true for years.
"The project has `AppButton`, `AppCard`, `AppChip`…" is wrong after the next merge, and a
stale list is worse than no list — it gets trusted, so the search that would have found
the real answer never happens.

Counts are fine as evidence (`14 widgets`), because a count that drifts is obviously
approximate. A list that drifts looks authoritative.

## What to determine

| Section | Establish |
|---|---|
| Shared components | Which directories hold reusable widgets, app-wide and per feature. The naming pattern (`App*`, `*Widget`, plain nouns). Roughly how many. |
| Typography | The file and class that own text styles, and the exact expression a widget uses to reach one. Whether inline `TextStyle` appears anywhere outside that file, and how often. |
| Colours and spacing | Same, for the token or theme entry point. Cross-check against the profile's `tokens`. |
| Assets | Which directories are declared under `flutter: assets:`. The naming convention. Which loader is used for SVG and for raster. Whether an asset-path constants class exists. |
| Naming | File-name pattern. The routed-widget suffix, with the count both ways (`*Page` 12, `*Screen` 0). The widget base class in normal use. |
| Imports | `package:` versus relative, whether barrel files are used, and whether the analyzer enforces either. |

Measure each one. A convention is what the code does in the majority of cases, not what a
style guide in the repo claims — if those disagree, write what the code does and say the
guide disagrees.

Where a project is genuinely inconsistent — six `*Page` and five `*Screen` — say so rather
than picking. "No established convention; match the surrounding feature" is a true and
useful instruction. Inventing a rule the codebase does not follow makes every future
change argue with half the repo.

## Output format

```markdown
# Codebase conventions

Generated by flutter-adapt. Regenerate after a significant refactor.
Locations and rules only — no component inventory, because a list goes stale and a stale
list gets trusted. Search live; this tells you where to search.

## Shared components
- `lib/core/widgets/` — app-wide, 14 widgets, named `App<Thing>`
- `lib/features/<feature>/presentation/widgets/` — feature-local
- Search both by suffix (`class .*Button`) before creating anything.

## Typography
- Source: `lib/core/theme/app_text_styles.dart` (`AppTextStyles`)
- Reach it with: `context.tokens.text.<name>`
- Inline `TextStyle(` outside that file: 3 occurrences, all in `legacy/` — not the pattern
  to copy.

## Assets
- Declared: `assets/images/`, `assets/icons/`
- Naming: snake_case
- SVG via `flutter_svg` (`SvgPicture.asset`); raster via `Image.asset`
- No asset-path constants class — paths are string literals at call sites.

## Naming
- Files: snake_case, `<feature>_<type>.dart`
- Routed widgets: `*Page` (12 vs 0 `*Screen`)
- Base class: `StatelessWidget`; `ConsumerWidget` where the widget reads a provider

## Imports
- `package:` throughout, including within a feature
- No barrel files
```

Keep it under about 60 lines. It is read on every code-writing task, and a long file gets
skimmed exactly where the specifics are.

If `.agents/flutter-conventions.md` or `.claude/flutter-conventions.md` already exists,
preserve manual decisions, report changes, and choose the directory by the same table as the
profile. Keep both generated files in the same directory.
