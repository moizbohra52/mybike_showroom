// TEMPORARY verification probe (screens-layout verifier). Delete after use.
// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybike_showroom/common/screens/foundation_screen.dart';
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
        t.startsWith('constraints:') ||
        t.startsWith('size:') ||
        t.startsWith('direction:') ||
        t.startsWith('mainAxisSize')) {
      keep.add(t);
    }
  }
  return keep.take(8).join(' | ');
}

Future<GoRouter> pumpApp(
  WidgetTester tester, {
  required Size size,
  AppThemeMode themeMode = AppThemeMode.system,
  String initial = '/dashboard',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final GoRouter router = AppRouter.createRouter(initialLocation: initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bootstrapThemeModeProvider.overrideWithValue(themeMode),
        preferenceStoreProvider.overrideWithValue(FakePreferenceStore()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode.materialThemeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  return router;
}

Color? textColorOf(WidgetTester tester, Finder f) {
  final RenderParagraph p = tester.renderObject<RenderParagraph>(f);
  return p.text.style?.color;
}

String hex(Color? c) =>
    c == null ? 'null' : '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

void main() {
  testWidgets('P1 mobile 390x844 overflow source', (WidgetTester tester) async {
    hook();
    await pumpApp(tester, size: const Size(390, 844));
    unhook();
    print('P1 errors=${errs.length}');
    for (final FlutterErrorDetails d in errs) {
      print('P1 ${summarize(d)}');
    }
  });

  testWidgets('P1b mobile 360x640 overflow (light/dark)', (
    WidgetTester tester,
  ) async {
    for (final AppThemeMode m in <AppThemeMode>[
      AppThemeMode.light,
      AppThemeMode.dark,
    ]) {
      hook();
      await pumpApp(tester, size: const Size(360, 640), themeMode: m);
      unhook();
      print('P1b $m errors=${errs.length}');
      for (final FlutterErrorDetails d in errs) {
        print('P1b ${summarize(d)}');
      }
    }
  });

  testWidgets('P2 desktop sidebar selected state dark/light', (
    WidgetTester tester,
  ) async {
    for (final AppThemeMode m in <AppThemeMode>[
      AppThemeMode.light,
      AppThemeMode.dark,
    ]) {
      hook();
      await pumpApp(tester, size: const Size(1440, 900), themeMode: m);
      unhook();
      final Finder tile = find.widgetWithText(ListTile, 'Dashboard');
      final ListTile lt = tester.widget<ListTile>(tile);
      final Finder txt = find.descendant(
        of: tile,
        matching: find.text('Dashboard'),
      );
      final Finder icon = find.descendant(of: tile, matching: find.byType(Icon));
      final RichText rt = tester.widget<RichText>(
        find.descendant(of: icon, matching: find.byType(RichText)),
      );
      print(
        'P2 $m selected=${lt.selected} text=${hex(textColorOf(tester, txt))} '
        'icon=${hex(rt.text.style?.color)} errs=${errs.length}',
      );
      // Module card 'Dashboard' in the grid (FoundationModuleCard)
      final Finder card = find.widgetWithText(FoundationModuleCard, 'Dashboard');
      final Finder ctext = find.descendant(
        of: card,
        matching: find.text('Dashboard'),
      );
      final Card cw = tester.widget<Card>(
        find.descendant(of: card, matching: find.byType(Card)),
      );
      final Material mat = tester.widget<Material>(
        find
            .descendant(
              of: find.descendant(of: card, matching: find.byType(Card)),
              matching: find.byType(Material),
            )
            .first,
      );
      print(
        'P3 $m cardText=${hex(textColorOf(tester, ctext))} card.color=${hex(cw.color)} '
        'material=${hex(mat.color)}',
      );
    }
  });

  testWidgets('P4 tablet rail overflow at various sizes', (
    WidgetTester tester,
  ) async {
    for (final Size s in <Size>[
      const Size(900, 600),
      const Size(1000, 700),
      const Size(800, 1280),
      const Size(800, 940),
      const Size(800, 920),
    ]) {
      hook();
      await pumpApp(tester, size: s);
      unhook();
      final List<String> rail = errs
          .map(summarize)
          .where((String x) => x.contains('vertical') || x.contains('bottom'))
          .toList();
      print('P4 $s errs=${errs.length} railish=${rail.length}');
      for (final String r in rail) {
        print('P4   $r');
      }
    }
  });

  testWidgets('P5 module grid rows', (WidgetTester tester) async {
    for (final Size s in <Size>[
      const Size(360, 640),
      const Size(800, 1280),
      const Size(1440, 900),
    ]) {
      hook();
      await pumpApp(tester, size: s);
      unhook();
      final Finder cards = find.byType(FoundationModuleCard, skipOffstage: false);
      final Map<double, int> rows = <double, int>{};
      double maxRight = 0;
      for (final Element e in cards.evaluate()) {
        final RenderBox b = e.renderObject! as RenderBox;
        final Offset o = b.localToGlobal(Offset.zero);
        rows[o.dy] = (rows[o.dy] ?? 0) + 1;
        final double r = o.dx + b.size.width;
        if (r > maxRight) {
          maxRight = r;
        }
      }
      final Finder wrap = find.ancestor(
        of: cards.first,
        matching: find.byType(Wrap),
      );
      final RenderBox wb = tester.renderObject<RenderBox>(wrap.first);
      final LayoutBuilder lb = tester.widget<LayoutBuilder>(
        find.ancestor(of: wrap.first, matching: find.byType(LayoutBuilder)).first,
      );
      final RenderBox lbb = tester.renderObject<RenderBox>(
        find.byWidget(lb),
      );
      print(
        'P5 $s cardW=${(cards.evaluate().first.renderObject! as RenderBox).size.width} '
        'rows=${rows.values.toList()} wrapW=${wb.size.width} lbW=${lbb.size.width}',
      );
    }
  });

  testWidgets('P6 gallery dead end', (WidgetTester tester) async {
    hook();
    final GoRouter router = await pumpApp(tester, size: const Size(1280, 800));
    await tester.tap(find.text('Open Phase 2 Component Gallery'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    unhook();
    print(
      'P6 loc=${router.routeInformationProvider.value.uri} '
      'gallery=${find.byType(GalleryScreen).evaluate().length} '
      'back=${find.byType(BackButton).evaluate().length} canPop=${router.canPop()}',
    );
  });

  testWidgets('P7 mobile nav selected index on /showrooms', (
    WidgetTester tester,
  ) async {
    hook();
    await pumpApp(tester, size: const Size(390, 844), initial: '/showrooms');
    unhook();
    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    print(
      'P7 selectedIndex=${bar.selectedIndex} dests=${bar.destinations.length}',
    );
  });

  testWidgets('P8 tablet rail selected icon colour dark', (
    WidgetTester tester,
  ) async {
    hook();
    await pumpApp(tester, size: const Size(800, 1280), themeMode: AppThemeMode.dark);
    unhook();
    final Finder rail = find.byType(NavigationRail);
    final Finder sel = find.descendant(
      of: rail,
      matching: find.byIcon(Icons.space_dashboard),
    );
    final RichText rt = tester.widget<RichText>(
      find.descendant(of: sel, matching: find.byType(RichText)),
    );
    final Material m = tester.widget<Material>(
      find.descendant(of: rail, matching: find.byType(Material)).first,
    );
    print(
      'P8 selectedIcon=${hex(rt.text.style?.color)} railBg=${hex(m.color)} '
      'found=${sel.evaluate().length}',
    );
  });

  testWidgets('P9 gallery standalone overflows', (WidgetTester tester) async {
    for (final Size s in <Size>[
      const Size(360, 640),
      const Size(800, 1280),
      const Size(1440, 900),
    ]) {
      for (final ThemeData t in <ThemeData>[AppTheme.light, AppTheme.dark]) {
        tester.view.physicalSize = s;
        tester.view.devicePixelRatio = 1.0;
        hook();
        await tester.pumpWidget(
          MaterialApp(theme: t, home: const GalleryScreen()),
        );
        await tester.pump(const Duration(seconds: 1));
        unhook();
        print('P9 $s ${t.brightness} errs=${errs.length}');
        for (final FlutterErrorDetails d in errs) {
          print('P9   ${summarize(d)}');
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
    tester.view.reset();
  });
}
