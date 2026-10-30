---
name: figma-to-widget
description: "Implement Flutter UI from a Figma frame or supplied design image, preserving layout intent and reusing project components. Not for unrelated mentions of Figma."
---

# Figma to Widget

> **Profile first.** Read `.agents/flutter-profile.yaml` in the project root, falling
> back to legacy `.claude/flutter-profile.yaml`. `tokens`
> decides how the values in a frame get resolved and `structure` decides where the new
> widget file goes. The mapping table below is stack-independent and holds under every
> profile. Field list:
> `../design-tokens/references/flutter-profile.md`, relative to this skill directory.

The failure mode this prevents: translating a design by reading pixel positions and
reproducing them with `Stack` and `Positioned`. That output matches the artboard exactly
and breaks on every other screen size. Figma's layout system maps cleanly onto Flutter's
— use the mapping, not the coordinates.

## Prerequisite

Check whether a connected Figma tool is available. If it is, pull the frame directly and
read real values. If it is not, say so before starting: without direct Figma access,
every value is being read off a rasterized image and is a guess. Use supplied screenshots as visual evidence, label inferred values, and implement what
is unambiguous. Request missing specs only when necessary; absence of Figma is not a
reason to block a screenshot-based task or claim measured values.

## The mapping

| Figma | Flutter |
|---|---|
| Auto Layout, vertical | `Column` |
| Auto Layout, horizontal | `Row` |
| Auto Layout gap | `spacing:` on Row/Column, or a `Gap` widget |
| Auto Layout padding | `Padding` with a directional token |
| Space between | `MainAxisAlignment.spaceBetween` |
| Hug contents | `MainAxisSize.min` |
| Fill container | `Expanded` inside a bounded Flex; otherwise constraints appropriate to the parent |
| Fixed width/height | `SizedBox`, only when the design truly requires it |
| Absolute position | `Stack` + `Positioned` — last resort only |
| Frame with clip | `ClipRRect` with a radius token |
| Component instance | An existing widget from the codebase |
| Component variant | A parameter or enum on that widget, not a new widget |

## Rules

**Auto Layout first.** If a frame uses Auto Layout, the output uses Row or Column. Reach
for `Stack` only when the design genuinely overlaps elements — an avatar badge, a
floating action button over content. Overlap is the only valid reason.

**Never hardcode the artboard width.** A 390pt frame is a reference, not a target.
Fixed widths appear only where the design is explicitly fixed regardless of screen —
an avatar, an icon, a fixed-size chip.

**Check for an existing component before building a new one.** A Figma component
instance almost always corresponds to a widget that already exists in the codebase.
Building a second `PrimaryButton` because the first was not found is the most common form
of duplication in agent-generated UI — and the usual cause is searching for the name you
expected rather than the role. Search by suffix (`class .*Button`), not by the name in
your head. The codebase-conventions skill carries the full search protocol and the
project's component locations.

**Variants are parameters.** A Figma component with Default, Hover, Disabled, and Loading
variants becomes one widget with a state parameter — not four widgets.

**Text is never `Text('...')` with an inline style.** Style comes from the tokens
(see the design-tokens skill), content comes from localization (see a11y-and-rtl).

## Workflow

1. Pull the frame and identify its layer tree.
2. Resolve values through the configured theme/token source. For tokens: none, inline
   values are valid. Label uncertain measurements and resolve consequential ambiguity.
3. Identify which layers are instances of existing components. Search the codebase for
   each. Reuse.
4. Write the widget tree following the mapping table above.
5. For substantial visual work, use visual-verification when capture and reference
   inputs exist. Otherwise run applicable layout/widget checks and report the missing
   visual comparison. Do not claim a pixel match without evidence.

## Common mistakes

- Nesting `Container` inside `Container` because the design has nested frames. Collapse
  them; one `Container` handles padding, color, and radius together.
- Producing one enormous `build()` method for the whole screen. Split at the same
  boundaries the design file uses for its components.
- Adding `SizedBox(height: n)` between every element instead of using the parent's
  `spacing` parameter. The design expresses it as an Auto Layout gap; express it the
  same way.
