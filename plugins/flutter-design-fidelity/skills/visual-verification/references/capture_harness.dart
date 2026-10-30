// Copy into test/support/ only if the project has no equivalent capture helper.
// Host widget tests only (dart:io); this is not an integration/device screenshot.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadCaptureFonts(Map<String, List<String>> fonts) async {
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

Future<void> captureWidget(
  WidgetTester tester, {
  required Widget child,
  required String output,
  required ThemeData theme,
  required Locale locale,
  required TextDirection direction,
  required Size logicalSize,
  required double pixelRatio,
  required double textScale,
  Iterable<LocalizationsDelegate<dynamic>> delegates = const [],
  Duration pumpDuration = const Duration(milliseconds: 100),
}) async {
  if (pixelRatio <= 0 || textScale <= 0 || logicalSize.isEmpty) {
    throw ArgumentError('Capture dimensions, DPR and scale must be positive');
  }
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = logicalSize * pixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: locale,
      supportedLocales: [locale],
      localizationsDelegates: delegates,
      home: RepaintBoundary(
        key: boundaryKey,
        child: Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQueryData(
              size: logicalSize,
              devicePixelRatio: pixelRatio,
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
  // Fixed pumping supports deterministic loading/spinner states; no unbounded settle.
  await tester.pump(pumpDuration);
  final exception = tester.takeException();
  if (exception != null) throw StateError('Capture failed: $exception');
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('PNG encoding returned no bytes');
      final file = File(output);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  });
}
