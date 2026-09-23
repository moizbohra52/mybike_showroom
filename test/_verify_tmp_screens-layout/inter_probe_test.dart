// TEMPORARY verification probe (screens-layout verifier). Delete after use.
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/screens/gallery_screen.dart';
import 'package:mybike_showroom/core/routes/app_router.dart';
import 'package:mybike_showroom/core/storage/preference_store.dart';
import 'package:mybike_showroom/core/theme/app_theme.dart';
import 'package:mybike_showroom/core/theme/app_theme_mode.dart';
import 'package:mybike_showroom/core/theme/theme_controller.dart';

import '../helpers/fake_preference_store.dart';

final List<FlutterErrorDetails> errs = <FlutterErrorDetails>[];
void Function(FlutterErrorDetails)? _old;

void hook() {
  errs.clear();
  _old = FlutterError.onError;
  FlutterError.onError = errs.add;
}

void unhook() {
  FlutterError.onError = _old;
}

String summarize(FlutterErrorDetails d) {
  final String s = d.toString();
  final List<String> keep = <String>[];
  for (final String line in s.split('\n')) {
    final String t = line.trim();
    if (t.contains('overflowed') ||
        t.contains('file:///') ||
        t.startsWith('constraints:')) {
      keep.add(t);
    }
  }
  return keep.take(6).join(' | ');
}

Future<void> loadInter() async {
  final FontLoader loader = FontLoader('Inter');
  for (final String f in <String>[
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]) {
    final Uint8List bytes = File('assets/fonts/$f').readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(loadInter);

  testWidgets('I1 gallery 360x640 real Inter at scale 1.0 / 1.5', (
    WidgetTester tester,
  ) async {
    for (final double scale in <double>[1.0, 1.5]) {
      for (final ThemeData t in <ThemeData>[AppTheme.light, AppTheme.dark]) {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        hook();
        await tester.pumpWidget(
          MaterialApp(
            theme: t,
            builder: (BuildContext c, Widget? child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: const GalleryScreen(),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        unhook();
        print('I1 scale=$scale ${t.brightness} errs=${errs.length}');
        for (final FlutterErrorDetails d in errs) {
          print('I1   ${summarize(d)}');
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
    tester.view.reset();
  });

  testWidgets('I2 app shell 390x844 / 360x640 real Inter', (
    WidgetTester tester,
  ) async {
    for (final Size s in <Size>[const Size(390, 844), const Size(360, 640)]) {
      for (final double scale in <double>[1.0, 1.5]) {
        tester.view.physicalSize = s;
        tester.view.devicePixelRatio = 1.0;
        final GoRouter router = AppRouter.createRouter();
        hook();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bootstrapThemeModeProvider.overrideWithValue(AppThemeMode.light),
              preferenceStoreProvider.overrideWithValue(FakePreferenceStore()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              builder: (BuildContext c, Widget? child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              routerConfig: router,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        unhook();
        print('I2 $s scale=$scale errs=${errs.length}');
        for (final FlutterErrorDetails d in errs) {
          print('I2   ${summarize(d)}');
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
    tester.view.reset();
  });
}
