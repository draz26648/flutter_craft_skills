---
name: responsive-adaptive
description: "Implement or debug Flutter layout across available widths, keyboard insets, orientations, and text scaling. Use for layout changes or overflow."
---

# Responsive and Adaptive Layout

A design file gives you one width. The app runs on hundreds. Every fixed dimension copied
from the artboard is a future overflow.

## Breakpoints

| Name | Width | Typical |
|---|---|---|
| compact | < 600 | phones, portrait |
| medium | 600–839 | small tablets, phones landscape, unfolded |
| expanded | ≥ 840 | tablets, desktop |

Reuse existing breakpoint definitions. These are suggested defaults only when the
project has none; place new definitions in its existing layout directory.

## Which tool for which decision

**`LayoutBuilder`** for how a component lays itself out. It reports the space the widget
actually has, which is what the widget needs to know. A card in a 400pt sidebar on a
1200pt screen should lay out as a narrow card — `MediaQuery` would tell it the screen is
wide and it would be wrong.

**`MediaQuery`** for screen-level decisions: navigation pattern, number of grid columns
for the whole page, whether to show a modal or a side panel.

Reading `MediaQuery.sizeOf(context)` inside a leaf widget is almost always the wrong tool.
Note `sizeOf` rather than `MediaQuery.of(context).size` — the latter subscribes the widget
to every MediaQuery change including keyboard appearance, causing rebuilds for unrelated MediaQuery changes.

## Rules

**No hardcoded screen dimensions.** `width: 390` is a bug regardless of what the design
says. Fixed sizes are only valid for things that are genuinely fixed: an icon, an avatar,
a fixed-height app bar.

**Avoid percentage-of-screen sizing for text containers.** `width: screenWidth * 0.8`
looks fine at the design width and breaks at 2.0 text scale. Let content determine height
and constrain with `ConstrainedBox` where a maximum is genuinely needed.

**Choose scrolling from content and constraints.** Use a scroll view for content that can
exceed available height. Use lazy slivers/builders for long content. Do not wrap an
existing scrollable blindly or put Expanded under unbounded scroll constraints. Preserve
platform scroll physics unless the product requires an override.

**Handle the keyboard.** Test forms with a visible keyboard on the smallest supported
viewport. Account for viewInsets without applying the same inset twice.

**Own safe-area handling once.** Check whether Scaffold, navigation, or a parent already
handles each inset. Apply SafeArea where needed; allow intentional edge-to-edge artwork.

## Orientation and foldables

Do not lock orientation without a product reason. If landscape is supported, a
two-column layout above the medium breakpoint is usually the right move rather than
stretching a single column to 900pt — a text line longer than about 75 characters is
measurably harder to read.

## Common mistakes

- `MediaQuery.of(context).size.width * 0.44` to fit two cards in a row. Use
  `GridView` or `Expanded` — the arithmetic version breaks the moment padding changes.
- Testing only on the simulator's default device. Check the smallest supported device
  and the largest, at 2.0 text scale, before considering layout work finished.
- Using `Wrap` where `Flexible` was needed. `Wrap` moves the overflowing item to the
  next line, which is rarely what a design intends for a row of two elements.
