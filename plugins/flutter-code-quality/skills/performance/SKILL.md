---
name: performance
description: "Diagnose Flutter jank, expensive rebuilds, image memory, or long-list performance. Use for relevant list/image changes or measured performance issues."
---

# Performance

## Build methods

`build()` runs often. It allocates the widget tree and nothing else.

Never inside `build()`: network calls, JSON parsing, sorting or filtering a large list,
`DateTime.now()` formatting in a loop, regex compilation, or creating a controller.
Move computation to the existing state layer or a suitable service, cache only where
useful, and let build read the result. Do not introduce Cubit into another stack.

**`const` wherever possible.** Const instances can skip parent-driven updates when identical; state and inherited
dependency changes can still rebuild their elements. Follow existing lint settings.

**Extract widgets rather than helper methods.** A `Widget _buildHeader()` rebuilds with
the parent every time. A separate identical const instance can skip that parent-driven update, though state
and inherited dependencies can still rebuild it. This is the most
common and most impactful structural fix in a Flutter codebase.

## Lists

Always `ListView.builder` or `ListView.separated` — never `ListView(children: [...])` for
anything that is not a short fixed list, because the non-builder form constructs every
child immediately regardless of visibility.

Provide `itemExtent` when the row height is known. It lets the framework skip layout for
off-screen items and makes scroll-to-index instant instead of linear.

Give items stable `ValueKey`s so reordering moves elements rather than rebuilding them.

For long lists, `addAutomaticKeepAlives: false` and `addRepaintBoundaries: false` when
items are simple — the defaults help complex items and cost memory on simple ones.

## Repaint boundaries

`RepaintBoundary` isolates a subtree so its repaints do not force neighbours to repaint.
Worth adding around: an animating element inside static content, a video or camera
preview, a chart that updates independently, a list item with its own animation.

Not worth adding everywhere. Each boundary is a separate layer with memory cost. Add
them where the repaint rainbow in DevTools shows something flashing that should not be.

## Images

For oversized raster images rendered at known bounds, set suitable `cacheWidth` or
`cacheHeight` where the platform/decoder supports them. Preserve resolution for zooming. Without it a
2000px image decodes at full size to fill a 100px avatar, holding roughly 16MB of memory
for something that needs 40KB. On a scrolling list of avatars this is the difference
between a smooth list and an out-of-memory crash on a mid-range Android device.

```dart
Image.network(url, cacheWidth: (100 * devicePixelRatio).round())
```

Reuse the project’s image loader and caching policy. Add a disk-cache dependency only
when requirements justify it. Reserve the final image bounds to prevent layout jumps.

## Animations

Prefer implicit animations (`AnimatedContainer`, `AnimatedOpacity`) for simple state
transitions. Use `AnimationController` when the animation needs to be interruptible,
reversible, or driven by a gesture.

Animate with `AnimatedBuilder` and a `child` parameter so the static subtree is built
once rather than every frame.

Prefer FadeTransition or AnimatedOpacity for opacity animation rather than rebuilding
a large subtree every frame. Intermediate opacity can require offscreen compositing;
measure raster cost rather than assuming an animation widget removes that cost.

## Profiling

Profile in profile mode. Debug mode numbers are meaningless — the assertions and lack of
AOT compilation make everything several times slower.

In DevTools: the timeline against the device refresh budget (about 16.7ms at 60Hz
or 8.3ms at 120Hz), the repaint rainbow for unnecessary
repaints, and the memory view for image cache growth during scrolling.

Measure before optimizing. The bottleneck is regularly not where it seems, and a
restructure done on a guess costs a day and changes nothing.

## Common mistakes

- `setState` on a whole screen when one small widget changed.
- `Opacity(opacity: 0)` still lays out and can receive hit tests, but does not paint
  its child. Choose Visibility, Offstage, or IgnorePointer according to layout, focus,
  semantics, and hit-testing requirements. See
  https://api.flutter.dev/flutter/widgets/Opacity-class.html .
- Rebuilding a `ScrollController` or `TextEditingController` in `build()`. They belong in
  `initState` and need disposing.
