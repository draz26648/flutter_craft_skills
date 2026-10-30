---
name: visual-verification
description: "Capture and compare Flutter UI against a supplied reference after substantial visual changes or an explicit fidelity check. Report missing capture inputs honestly."
---

# Visual Verification

An agent with no feedback loop declares a screen finished the moment it compiles. That
is the single largest source of "looks roughly right but is wrong" UI. This skill
supplies the loop.

## Scope and prerequisites

Use this for substantial visual implementation or an explicit fidelity check. Small
nonvisual edits need the relevant existing tests, not a new screenshot pipeline. Confirm
a reference export and capture environment exist. If either is missing, report NOT
VERIFIED with the missing input, continue applicable tests, and do not claim a match.

Read `references/capture-workflow.md` when preparing capture. A portable host-test helper
is provided at `references/capture_harness.dart`; reuse existing project helpers first.

## The loop

1. Run the widget in the harness and capture a screenshot.
2. Diff it against the reference export from the design.
3. If the difference is above threshold, read the diff output to find where, fix, and
   repeat from step 1.
4. Stop when under threshold, or after four iterations — at which point report what is
   still off rather than continuing to guess.

Four iterations is a deliberate cap. Beyond that the remaining difference is usually
something the diff cannot fix on its own: a missing font, a wrong export scale, or a
design that was updated after the export.

## Running it

```bash
# Capture the current implementation
flutter test test/capture_test.dart  # create/adapt using the capture workflow first

# Diff against the reference
python3 "<skill-directory>/scripts/compare.py" \
  --actual build/screenshots/login_screen.png \
  --expected design/exports/login_screen.png \
  --output build/screenshots/login_screen_diff.png \
  --threshold 0.02
```

Resolve `<skill-directory>` from the loaded `SKILL.md` path, then run the bundled script
from its `scripts/` directory. Do not copy or reimplement it. A vendored install lives at
`.claude/skills/visual-verification` (Claude Code) or `.agents/skills/visual-verification`
(Codex) in the project, or at the same path under `~` for a personal install.

The comparison logic lives in a script rather than in prose so it executes without
loading into context. Anything deterministic belongs in a script — prose describing a
comparison algorithm costs tokens on every trigger and is less reliable than running the
algorithm.

First run only, install its dependencies:

```bash
python3 -m venv /tmp/flutter-visual-check
/tmp/flutter-visual-check/bin/pip install pillow numpy
# Use /tmp/flutter-visual-check/bin/python for compare.py
```

Exit codes: `0` match, `1` difference above threshold, `2` could not run — a missing file,
an unreadable image, or bad arguments. **A `2` is not a pass**, and it is not a failing
screen either; it means the comparison never happened.

## Two thresholds

`--threshold` (default 0.02) is the share of differing pixels across the whole image.
`--max-cluster` (default 0.25) is the share within the worst single cell of a 12×12 grid.
Either one being exceeded fails the comparison.

The second exists because a global percentage hides the defects that matter most. A
button rendered with the wrong color token covers about 1.5% of a phone screen — under
the global threshold, and the first thing anyone notices. Judged locally it is a solid
block of wrong, and it fails. When a run fails on the cluster threshold alone, the
problem is one specific element, not a global color or scale issue, and the output says
so.

If a screen has inherently dynamic content — a status bar clock, a live avatar — exclude
it with `--ignore-region X,Y,W,H` rather than raising the threshold until it passes.
Raising the threshold blinds the whole screen to fix one rectangle.

## Reading a diff

The output image is the capture, faded, with differing pixels burned in as red. Interpret
the red:

- **A sharp offset of the entire content block** — padding or a margin token is wrong.
- **Red outlining every glyph edge** — font weight, letter spacing, or line height.
- **A solid red block over one element** — wrong color token, or a missing opacity.
- **Red everywhere, evenly** — the export scale does not match the capture device pixel
  ratio. Fix the export, not the code.
- **Text differing in shape entirely** — the font is not bundled. Check `pubspec.yaml`
  before changing anything in the widget.

Alongside the image the script prints the bounding box of all differences and the
densest region. Read those before opening the PNG — they usually identify the element on
their own.

## Size mismatch is an error, not something to work around

If the capture and the reference are different sizes the script stops. That is
deliberate: rescaling one to fit the other manufactures edge noise along every boundary
in the image, which buries the real defect under artifacts. A size mismatch nearly always
means the export scale does not match the capture's device pixel ratio — fix that.
`--allow-resize` overrides it when you genuinely need a rough comparison, and the output
warns that the noise is expected.

## Export requirements

The reference export must match the capture conditions or the diff is meaningless:
same device pixel ratio, same logical width, same theme, same locale, same text scale.
Export at 2x from a 390pt frame and capture at 3x, and the diff will report failure on
a pixel-perfect implementation.

State these conditions in the test harness rather than assuming them.

## What this does not catch

Static comparison verifies one state on one device. It says nothing about scroll
behaviour, animation, keyboard interaction, text overflow at larger scale factors, or
RTL. Those need their own checks — see the a11y-and-rtl and responsive-adaptive skills.
Passing a visual diff is a floor, not a ceiling.
