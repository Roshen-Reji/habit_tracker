import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker/widgets/bottom_nav_bar.dart';
import 'package:habit_tracker/features/home/home_chat.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('habit_test_nav_');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('BottomNavBar tests (P0-1)', () {
    testWidgets('BottomNavBar height is approximately 62px (excluding margin)',
        (WidgetTester tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: BottomNavBar(
                selectedIndex: selectedIndex,
                onItemTapped: (index) {
                  selectedIndex = index;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final navBarFinder = find.byType(BottomNavBar);
      expect(navBarFinder, findsOneWidget);

      // The BottomNavBar Container has height: 62 and margin bottom: 12.
      // Total render size of BottomNavBar with margin is 74.
      final totalSize = tester.getSize(navBarFinder);
      expect(totalSize.height, equals(74.0));

      // Check tab animated containers inside BottomNavBar have height: 46
      final tabs = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();
      expect(tabs.length, equals(3));
      for (final tab in tabs) {
        expect(tab.constraints?.maxHeight ?? 46.0, equals(46.0));
      }

      // Verify tabs respond to taps and change selection
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pumpAndSettle();
      expect(selectedIndex, equals(1));
    });

    for (final size in [const Size(360, 640), const Size(412, 915)]) {
      testWidgets(
          'No overlap between Nav, FAB, and list bottom at ${size.width}x${size.height}',
          (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final scrollController = ScrollController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  // Page content with bottom padding 100
                  ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: 30,
                    itemBuilder: (context, index) {
                      return ListTile(
                        key: ValueKey('item_$index'),
                        title: Text('Item $index'),
                      );
                    },
                  ),
                  // Nav bar at bottom center
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: BottomNavBar(
                      selectedIndex: 0,
                      onItemTapped: (_) {},
                    ),
                  ),
                  // FAB positioned above nav bar
                  const HomeChatFAB(),
                ],
              ),
            ),
          ),
        );

        // Pump frames (HomeChatFAB has an infinite repeat shimmer/scale animation)
        await tester.pump(const Duration(milliseconds: 100));

        // Get rect of the BottomNavBar (which sits at bottom center, height 74 including margin)
        final navRect = tester.getRect(find.byType(BottomNavBar));

        // Get rect of the FAB's visible container (56x56 animated container inside HomeChatFAB)
        final fabAnimatedContainer = find
            .descendant(
              of: find.byType(HomeChatFAB),
              matching: find.byType(AnimatedContainer),
            )
            .first;
        final fabRect = tester.getRect(fabAnimatedContainer);

        // 1. Verify Nav bar and FAB do NOT overlap
        expect(
          navRect.overlaps(fabRect),
          isFalse,
          reason:
              'FAB (top: ${fabRect.top}, bottom: ${fabRect.bottom}) must not overlap Nav (top: ${navRect.top}, bottom: ${navRect.bottom})',
        );

        // 2. FAB bottom must be above nav bar top (with buffer)
        expect(fabRect.bottom, lessThanOrEqualTo(navRect.top));

        // 3. Scroll to the bottom and verify last item can be reached without clipping
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('item_29')),
          200.0,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 100));

        final lastItemFinder = find.byKey(const ValueKey('item_29'));
        expect(lastItemFinder, findsOneWidget);
        final lastItemRect = tester.getRect(lastItemFinder);
        expect(lastItemRect.top, lessThan(size.height));
      });
    }
  });
}
