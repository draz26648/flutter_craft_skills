---
name: golden-tests
description: "Add or review Flutter visual regression tests for stable, significant UI states; investigate golden mismatches. Do not add goldens for every small widget edit."
---

# Golden Tests

> **Profile first.** Read `.agents/flutter-profile.yaml` in the project root, falling
> back to legacy `.claude/flutter-profile.yaml`. `locales`
> determines the matrix below — generate an RTL variant when the project ships an RTL
> locale, and skip it when it does not, rather than generating a variant nobody will ever
> look at. Field list:
> `../design-tokens/references/flutter-profile.md`, relative to this skill directory.

Visual verification proves a screen matches today. Goldens are what stop it drifting
tomorrow. Add coverage for stable shared components and significant screen states,
using the existing test framework. Small edits usually need the affected existing test,
not a new golden suite. If the project has no goldens, justify setup against the task.

## Structure

```
test/goldens/
├── flutter_test_config.dart      # font loading, once, for all golden tests
├── components/
│   ├── primary_button_test.dart
│   └── goldens/                   # generated PNGs, committed
└── screens/
    ├── login_screen_test.dart
    └── goldens/
```

## The matrix

Each golden test covers the axes that actually break layouts:

- **Devices** — one small phone (360x640), one large phone (430x932), one tablet if the
  app supports it
- **Themes** — supported themes (light and dark only when both ship)
- **Text scale** — 1.0 and 2.0
- **Locale and direction** — LTR and RTL if the app ships Arabic or Hebrew

Full cross-product is too many images to review. Cover 1.0/light/LTR on every device,
then relevant variants for supported dark mode, 2.0 text scale, and RTL. That catches the real failures
without generating sixty files nobody looks at.

## Writing one

The example below uses golden_toolkit APIs. Use it only when that package already
exists and its resolved version supports them. Otherwise prefer Flutter’s built-in
`matchesGoldenFile` and the project’s existing wrappers; do not add a dependency just
to follow this example. Cover loading, error, and empty states where visually meaningful.


```dart
void main() {
  testGoldens('PrimaryButton renders across states', (tester) async {
    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(devices: [Device.phone, Device.tabletPortrait])
      ..addScenario(widget: const PrimaryButton(label: 'Continue'), name: 'default')
      ..addScenario(widget: const PrimaryButton(label: 'Continue', isLoading: true), name: 'loading')
      ..addScenario(widget: const PrimaryButton(label: 'Continue', onPressed: null), name: 'disabled');

    await tester.pumpDeviceBuilder(builder, wrapper: materialAppWrapper(theme: AppTheme.light));
    await screenMatchesGolden(tester, 'primary_button_light');
  });
}
```

Load real fonts in `flutter_test_config.dart`. Without it every golden renders in
Ahem — solid black boxes — and the test verifies layout while proving nothing about
typography.

## The regeneration rule

```bash
flutter test --update-goldens
```

This command is how design drift enters a codebase. It always makes the tests pass,
which means a failing golden is only useful if someone looks at what changed.

Never run it as a reflex when a test fails. First determine whether the change was
intended. If it was, regenerate, then **open the changed PNGs and look at them** before
committing. If a golden changed and nobody can say why, that is a bug being committed,
not a test being updated.

In review, treat changed golden files as changed code.

## Common mistakes

- Wrapping every scenario in its own `MaterialApp` with an ad-hoc theme instead of a
  shared wrapper. The goldens then test the wrapper, not the widget.
- Goldens containing dates, timers, or random data. Freeze the clock and seed the data
  or the test fails on its own schedule.
- Not awaiting image loading. Network images render as blank space; use a fake image
  provider so the golden is deterministic.
- Committing goldens generated on a different platform. Font rasterization differs
  between macOS and Linux — generate them in CI, or pin the platform.
