# Project profile

## Resolution and precedence

Apply the user's current request first, then explicit project instructions and profile,
then evidence in the affected feature, then optional defaults for genuinely new projects.
Read `.agents/flutter-profile.yaml`; use `.claude/flutter-profile.yaml` only if absent.
If both exist, name the ignored legacy file; do not merge conflicting copies.

A missing file or field means **discover**, not Bloc, Freezed, GetIt, or AppTokens.
Read `pubspec.yaml`, resolved versions in `pubspec.lock`, SDK constraints/FVM settings,
and representative source in the affected feature. A dependency alone is weak evidence.
Respect existing wrappers and mixed-stack migration boundaries. If intent and live code
conflict, name the evidence and resolve only the decision that affects this task; do not
migrate the project as a side effect. Do not write a profile unless adaptation was requested.

Unknown facts remain omitted with a comment describing uncertainty. Never persist a
made-up default marked UNCERTAIN: downstream tools would still enforce that value.
For new projects, choose the smallest appropriate design and explain material choices.
Do not add a package merely because a skill example imports it.

## Fields

All fields are optional. A supplied value must match the following schema.

| Field | Values | Meaning |
|---|---|---|
| `state` | `bloc`, `riverpod`, `provider`, `signals`, `setstate` | Existing state stack for this work |
| `models` | `freezed`, `dart_mappable`, `json_serializable`, `manual` | Existing model tooling, not a mandate for union codegen |
| `structure` | `feature_first`, `layer_first` | Follow existing directories; custom layouts can remain omitted |
| `di` | `get_it`, `injectable`, `riverpod`, `provider`, `none` | How dependencies are supplied |
| `routing` | `go_router`, `auto_route`, `navigator` | Existing routing implementation |
| `tokens` | `theme_extension`, `theme_only`, `constants`, `none` | Existing visual-value source |
| `l10n` | `arb`, `easy_localization`, `slang`, `none` | Existing localization source |
| `locales` | YAML list of locale codes, e.g. `[en, ar_EG]` | Supported locales; language subtag determines RTL |
| `strictness` | `block`, `warn` | Severity of explicitly configured house conventions |

`tokens: none` permits inline visual values, including TextStyle. Reuse existing styles
where useful, but do not demand a token layer. `theme_only` uses ThemeData/ColorScheme/
TextTheme; `constants` uses existing constants; `theme_extension` uses the actual extension
name and API, which need not be AppTokens. Existing Material theme lookups remain valid.

`l10n: none` permits literal strings, including semantics labels. Otherwise use the
configured mechanism; ARB is not universal. Accessibility still applies.

The mechanical gate does not infer intent from dependency names. Missing token,
localization, or locale settings produce explicitly labelled advisory checks. A missing
strictness defaults to warn. With strictness block, explicit theme_extension/RTL settings
can block convention violations. Formatting, analysis, tests, and detected credentials
remain blocking under either strictness. Findings in this gate are not a comprehensive
security audit; credentials outside scanned Dart files require a dedicated secret scanner.

The gate validates YAML, unknown keys, enum values, duplicate keys and locale types.
It accepts quoted scalars and inline or block lists. Invalid supplied values exit 2.

## Example

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

## Adaptation

Invoke `$flutter-adapt` in Codex or `/flutter-code-quality:flutter-adapt` in a Claude Code
plugin (`/flutter-adapt` when vendored). It creates or updates the profile and conventions
within the user's requested scope. Existing user decisions survive regeneration unless
the user requested changing them. Each plugin includes this specification independently.
