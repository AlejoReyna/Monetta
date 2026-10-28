import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/navigation/adaptive_storefront_scaffold.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';
import 'package:monetta_app/platform/system_layout_context.dart';

// These tests deliberately use FlutterTest's wide fallback glyphs. Compact
// brand geometry is tested separately using the actual bundled typefaces.
void main() {
  void view(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  testWidgets('fallback glyphs reflow at the full requested text size',
      (tester) async {
    view(tester, const Size(320, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: MonettaBottomNavigation(
            current: MonettaBottomDestination.catalog,
            bagCount: 2,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final destination in MonettaBottomDestination.values) {
      final label = find.byKey(Key('bottom-nav-${destination.name}-label'));
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.textScaler.scale(13), 39);
      expect(paragraph.didExceedMaxLines, isFalse);
      final action =
          tester.getRect(find.byKey(Key('bottom-nav-${destination.name}')));
      expect(action.width, greaterThanOrEqualTo(48));
      expect(action.height, greaterThanOrEqualTo(48));
      expect(tester.getRect(label).left, greaterThanOrEqualTo(action.left));
      expect(tester.getRect(label).right, lessThanOrEqualTo(action.right));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'short large-text windows expose every destination through overflow',
      (tester) async {
    view(tester, const Size(320, 320));
    MonettaBottomDestination? last;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: MonettaBottomNavigation(
            current: MonettaBottomDestination.home,
            bagCount: 2,
            onSelected: (value) => last = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('bottom-nav-surface'))).height,
      56,
    );
    for (final label in ['Inicio', 'Catálogo', 'Carrito (2)', 'Cuenta']) {
      await tester.tap(find.byKey(const Key('navigation-overflow')));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text(label)),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      final item = find
          .ancestor(
            of: find.text(label),
            matching:
                find.byType(CheckedPopupMenuItem<MonettaBottomDestination>),
          )
          .first;
      expect(tester.getRect(item).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(item).bottom, lessThanOrEqualTo(320));
      expect(
        MediaQuery.textScalerOf(tester.element(find.text(label))).scale(13),
        39,
      );
      await tester.tapAt(tester.getCenter(item));
      await tester.pumpAndSettle();
      expect(
        last,
        MonettaBottomDestination.values[
            ['Inicio', 'Catálogo', 'Carrito (2)', 'Cuenta'].indexOf(label)],
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('enlarged rail count stays inside its action at full text scale',
      (tester) async {
    view(tester, const Size(466, 678));
    tester.view.padding = const FakeViewPadding(right: 84, bottom: 34);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(3.2)),
          child: child!,
        ),
        home: SystemLayoutScope(
          geometry: const SystemLayoutContext(
            supported: true,
            barEdge: SystemBarEdge.right,
          ),
          child: AdaptiveStorefrontScaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: MonettaBottomNavigation(
              current: MonettaBottomDestination.bag,
              bagCount: 1,
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final count = find.byKey(const Key('rail-bag-count'));
    expect(
      tester.renderObject<RenderParagraph>(count).textScaler.scale(10),
      32,
    );
    final rect = tester.getRect(count);
    final action = tester.getRect(find.byKey(const Key('bottom-nav-bag')));
    expect(rect.left, greaterThanOrEqualTo(action.left));
    expect(rect.right, lessThanOrEqualTo(action.right));
    expect(rect.top, greaterThanOrEqualTo(action.top));
    expect(rect.bottom, lessThanOrEqualTo(action.bottom));
    expect(action.right, lessThanOrEqualTo(466));
    expect(find.byTooltip('Carrito, 1 artículo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'synthetic host inset is consumed once and a wide portrait keeps horizontal chrome',
      (tester) async {
    view(tester, const Size(466, 678));
    tester.view.padding = const FakeViewPadding(right: 84, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(right: 84, bottom: 34);
    const camera = Rect.fromLTWH(382, 0, 84, 170);
    final geometry = ValueNotifier(
      const SystemLayoutContext(
        supported: true,
        viewSize: Size(466, 678),
        barEdge: SystemBarEdge.right,
        occlusions: [ReservedRegion(bounds: camera, active: true)],
      ),
    );
    final draft = TextEditingController(text: 'Mi búsqueda');
    addTearDown(geometry.dispose);
    addTearDown(draft.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: ValueListenableBuilder(
          valueListenable: geometry,
          builder: (context, value, _) => SystemLayoutScope(
            geometry: value,
            child: AdaptiveStorefrontScaffold(
              appBar: AppBar(title: const Text('Monetta')),
              body: SizedBox.expand(
                key: const Key('native-body'),
                child: TextField(controller: draft),
              ),
              bottomNavigationBar: MonettaBottomNavigation(
                current: MonettaBottomDestination.catalog,
                bagCount: 1,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fieldState = tester.state(find.byType(TextField));
    expect(tester.getRect(find.byKey(const Key('native-body'))).right, 382);
    for (final destination in MonettaBottomDestination.values) {
      final rect =
          tester.getRect(find.byKey(Key('bottom-nav-${destination.name}')));
      expect(rect.overlaps(camera), isFalse);
      expect(rect.left, greaterThanOrEqualTo(382));
      expect(rect.right, lessThanOrEqualTo(466));
      expect(rect.bottom, lessThanOrEqualTo(644));
    }
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    geometry.value =
        const SystemLayoutContext(supported: true, viewSize: Size(1024, 1200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bottom-nav-surface')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('bottom-nav-surface'))).width,
      1024,
    );
    expect(tester.state(find.byType(TextField)), same(fieldState));
    expect(draft.text, 'Mi búsqueda');
    expect(tester.takeException(), isNull);
  });
}
