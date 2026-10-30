# Capture prerequisites and harness

Reuse the project's existing screenshot or golden harness first. When absent, copy
`capture_harness.dart` from this reference directory to `test/support/`. It uses only
Flutter SDK packages plus flutter_test and creates PNGs in a host widget test. It does
not simulate platform views, system UI, plugins, or device rendering. Use an existing
integration/device harness when those matter; report an unsupported capture honestly.

1. Identify the widget, reference export, viewport, DPR, theme, locale, direction, scale,
   UI state, and rendering platform. Record these alongside the capture command.
2. Load the project's bundled font families with loadCaptureFonts before pumping. Pass
   its asset paths; no guessed paths or system fonts. Missing fonts block typography
   comparison, not independent implementation. Use fake repositories/network images,
   fixed timestamps and fixed data. Inject the existing DI wrapper around the child.
3. Supply the project's theme and localization delegates. If a router or inherited
   dependency is required, reproduce its existing test wrapper instead of nesting apps.
4. Write a test like the following, adapting the imports and names to actual project code.

```dart
testWidgets('capture wallet loaded', (tester) async {
  await loadCaptureFonts({'Inter': ['assets/fonts/Inter-Regular.ttf']});
  await captureWidget(
    tester,
    child: const WalletScreen(), // wrap with fake providers as needed
    output: 'build/screenshots/wallet.png',
    theme: AppTheme.light,
    locale: const Locale('en'),
    direction: TextDirection.ltr,
    logicalSize: const Size(390, 844),
    pixelRatio: 2,
    textScale: 1,
  );
});
```

Run `flutter test test/capture_test.dart`, then verify the PNG exists and its dimensions
are 780x1688 for this example. Open both images. Compare only matching conditions with
the bundled compare.py. A capture is not a reviewed golden baseline and needs no
`--update-goldens`. The helper is compiled and exercised by test_flutter_examples.py.

If a screenshot reference has unknown scale or fonts, state assumptions and report a
qualitative comparison separately. Never say PASS because a prerequisite was unavailable.

API: https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html
