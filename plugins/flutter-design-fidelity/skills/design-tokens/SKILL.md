---
name: design-tokens
description: "Resolve Flutter visual values through the project’s existing theme, constants, or token extension. Honor projects with no token layer."
---

# Design Tokens

> **Profile first.** Read `.agents/flutter-profile.yaml` in the project root, falling
> back to legacy `.claude/flutter-profile.yaml`. `tokens`
> decides whether this skill applies at all: `theme_extension` (use the existing extension API), `theme_only` — resolve through `Theme.of(context)` and its `ColorScheme`
> and `TextTheme` instead of `context.tokens`, `constants` — resolve through the project's
> constants class, or `none` — the project has no token layer and hardcoded values are not
> a finding. Under `none`, do not ask the user to introduce a token layer.
> Field list: `references/flutter-profile.md`.

With a configured token layer, widget code describes structure and resolves visual
values through that source. Missing profile fields require discovery first. Every color,
spacing unit, radius, shadow, duration, and text style should follow that configured
source. For theme_only values without a ThemeData equivalent, preserve the existing
layout constants or local conventions rather than inventing a ThemeExtension.

## With a token-backed design system

Move the following visual literals to the existing token source when that source
represents the concept. These restrictions do not apply under tokens: none:

- `Color(0xFF...)`, `Colors.blue`, or any literal color
- `EdgeInsets.all(16)` or any numeric padding, margin, or gap
- `BorderRadius.circular(12)` or any numeric radius
- `TextStyle(fontSize: 14, fontWeight: FontWeight.w600)` inline
- `Duration(milliseconds: 300)` for animations
- Raw `BoxShadow` definitions

Write instead:

```dart
Container(
  padding: context.tokens.space.md,
  decoration: BoxDecoration(
    color: context.tokens.color.surfaceRaised,
    borderRadius: context.tokens.radius.card,
    boxShadow: context.tokens.elevation.low,
  ),
  child: Text('Balance', style: context.tokens.text.titleMedium),
)
```

## When a token does not exist

First look for an equivalent semantic token. If a new design concept is intentional,
add a semantic token even if its first use is on one screen. Avoid numeric aliases that
merely disguise a literal. Under tokens: none, inline values are allowed; under theme_only
or constants, extend the existing source only where it makes sense.

If a design uses a value that does not fit the existing scale — 14px spacing where the
scale is 4/8/12/16 — do not add a `space.s14` token. Report the mismatch and check whether it is an intentional optical adjustment. Follow
explicit design intent; ask only if choosing a value would materially change the result.
Continue independent work while that decision is unresolved.

## Naming convention

Figma variable paths map directly to Dart getters in camelCase:

| Figma variable | Dart getter |
|---|---|
| `color/surface/raised` | `tokens.color.surfaceRaised` |
| `color/text/secondary` | `tokens.color.textSecondary` |
| `spacing/md` | `tokens.space.md` |
| `radius/card` | `tokens.radius.card` |
| `type/title/medium` | `tokens.text.titleMedium` |

Semantic names only. `color.danger`, never `color.red`. A semantic name survives a
rebrand; a literal one does not, and renaming three hundred usages of `red` when the
brand changes is the exact cost this convention exists to avoid.

## Workflow when implementing from a design

1. Pull the frame. Enumerate every distinct visual value it uses.
2. Match each value against the existing token set.
3. Report uncertain values and their evidence; resolve material ambiguity without
   blocking unrelated implementation.
4. Implement through the configured source and actual project API.

## Dark mode

Tokens are defined per theme, resolved at call time. A widget that reads
`context.tokens.color.surfaceRaised` works in both themes with no conditional logic.
Repeated brightness-dependent visual values suggest a missing semantic token; theme
checks for genuinely different behavior are not automatically wrong.

## Common mistakes

- Reading tokens once into a local variable outside `build()`. Tokens must resolve per
  build or theme switching silently stops working.
- Introducing AppTokens when the project uses a differently named extension.
- Duplicating a Material ColorScheme role in an extension without a project convention
  requiring it. Theme lookups remain valid.
- Adding numeric aliases instead of meaningful semantic tokens.

See `references/theme-extension-template.dart` for the token class structure to follow
when setting this up in a project that does not have one yet.
