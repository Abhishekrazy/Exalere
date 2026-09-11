import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpad/dpad.dart';
import 'package:provider/provider.dart';
import 'package:exalere/models/media_details.dart';
import 'package:exalere/models/media_item.dart';
import 'package:exalere/providers/app_provider.dart';
import 'package:exalere/ui/widgets/home/home_media_shelf.dart';
import 'package:exalere/ui/widgets/tv_focusable.dart';
import 'package:exalere/ui/widgets/tv/tv_episode_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TvSpatialNavigation navigates to right candidate and stops at edge',
    (tester) async {
      final focusNode1 = FocusNode(debugLabel: 'Item1');
      final focusNode2 = FocusNode(debugLabel: 'Item2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvFocusable(
                    focusNode: focusNode1,
                    autofocus: true,
                    child: const SizedBox(
                      width: 80,
                      height: 80,
                      child: Text('1'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  TvFocusable(
                    focusNode: focusNode2,
                    child: const SizedBox(
                      width: 80,
                      height: 80,
                      child: Text('2'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(focusNode1.hasFocus, isTrue);
      expect(focusNode2.hasFocus, isFalse);

      // Press D-Pad Right -> moves to Item 2
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusNode2.hasFocus, isTrue);
      expect(focusNode1.hasFocus, isFalse);

      // Press D-Pad Right again -> Nothing available to the right -> does nothing and stays on Item 2!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(focusNode2.hasFocus, isTrue);
    },
  );

  testWidgets(
    'TvSpatialNavigation navigates down and does nothing when at bottom edge',
    (tester) async {
      final focusTop = FocusNode(debugLabel: 'Top');
      final focusBottom = FocusNode(debugLabel: 'Bottom');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvFocusable(
                    focusNode: focusTop,
                    autofocus: true,
                    child: const SizedBox(
                      width: 100,
                      height: 50,
                      child: Text('Top'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TvFocusable(
                    focusNode: focusBottom,
                    child: const SizedBox(
                      width: 100,
                      height: 50,
                      child: Text('Bottom'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(focusTop.hasFocus, isTrue);

      // Press D-Pad Down -> moves to Bottom
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focusBottom.hasFocus, isTrue);

      // Press D-Pad Down again -> Nothing below -> stays on Bottom
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focusBottom.hasFocus, isTrue);

      // Press D-Pad Up -> moves back to Top
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focusTop.hasFocus, isTrue);

      // Press D-Pad Up again -> Nothing above -> stays on Top
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focusTop.hasFocus, isTrue);
    },
  );

  testWidgets(
    'TvSpatialNavigation stops at end of horizontal shelf and does not jump down to a shelf below on D-Pad Right',
    (tester) async {
      final ep1 = FocusNode(debugLabel: 'Episode1');
      final ep2 = FocusNode(debugLabel: 'Episode2');
      final related1 = FocusNode(debugLabel: 'Related1');
      final related2 = FocusNode(debugLabel: 'Related2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Row 1: Episodes (y: 50..150)
                Row(
                  children: [
                    TvFocusable(
                      focusNode: ep1,
                      autofocus: true,
                      child: const SizedBox(
                        width: 100,
                        height: 100,
                        child: Text('Ep 1'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TvFocusable(
                      focusNode: ep2,
                      child: const SizedBox(
                        width: 100,
                        height: 100,
                        child: Text('Ep 2'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60), // Clear vertical gap between rows
                // Row 2: Related (y: 210..310) - positioned further right
                Padding(
                  padding: const EdgeInsets.only(left: 150),
                  child: Row(
                    children: [
                      TvFocusable(
                        focusNode: related1,
                        child: const SizedBox(
                          width: 80,
                          height: 80,
                          child: Text('Related 1'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TvFocusable(
                        focusNode: related2,
                        child: const SizedBox(
                          width: 80,
                          height: 80,
                          child: Text('Related 2'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(ep1.hasFocus, isTrue);

      // Move Right to Ep 2
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(ep2.hasFocus, isTrue);

      // Press Right again on Ep 2:
      // Related 1 and Related 2 are further right (x: 150+ and 240+), but are in a row below!
      // Must NOT jump down to Related 1 or Related 2!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(ep2.hasFocus, isTrue);
      expect(related1.hasFocus, isFalse);
      expect(related2.hasFocus, isFalse);

      // Pressing Down on Ep 2 DOES move down to Related row
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(ep2.hasFocus, isFalse);
      expect(related1.hasFocus, isTrue);
    },
  );

  testWidgets(
    'TvSpatialNavigation stops at start of horizontal shelf and does not jump up to a button above on D-Pad Left',
    (tester) async {
      final resumeBtn = FocusNode(debugLabel: 'ResumeBtn');
      final seasonChip = FocusNode(debugLabel: 'SeasonChip');
      final ep1 = FocusNode(debugLabel: 'Episode1');
      final ep2 = FocusNode(debugLabel: 'Episode2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 0: Action button (y: ~50)
                  TvFocusable(
                    focusNode: resumeBtn,
                    child: const SizedBox(
                      width: 120,
                      height: 40,
                      child: Text('Resume'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Row 1: Season chip (y: ~110, small width ~50px)
                  TvFocusable(
                    focusNode: seasonChip,
                    child: const SizedBox(
                      width: 50,
                      height: 32,
                      child: Text('S1'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Row 2: Episodes row (y: ~162)
                  Row(
                    children: [
                      TvFocusable(
                        focusNode: ep1,
                        autofocus: true,
                        child: const SizedBox(
                          width: 200,
                          height: 120,
                          child: Text('Ep 1'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      TvFocusable(
                        focusNode: ep2,
                        child: const SizedBox(
                          width: 200,
                          height: 120,
                          child: Text('Ep 2'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(ep1.hasFocus, isTrue);

      // When on Ep 1 and pressing Left:
      // Must NOT jump UP to SeasonChip or ResumeBtn!
      // Must do NOTHING and stay on Ep 1!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(ep1.hasFocus, isTrue);
      expect(seasonChip.hasFocus, isFalse);
      expect(resumeBtn.hasFocus, isFalse);

      // Only pressing UP moves focus up to SeasonChip
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(ep1.hasFocus, isFalse);
      expect(seasonChip.hasFocus, isTrue);
    },
  );

  testWidgets(
    'TvSpatialNavigation UP from subpage choice moves directly to Back button, NEVER to sidebar',
    (tester) async {
      final sidebarHome = FocusNode(debugLabel: 'SidebarHome');
      final sidebarSettings = FocusNode(debugLabel: 'SidebarSettings');
      final backBtn = FocusNode(debugLabel: 'SubpageBack');
      final choiceYes = FocusNode(debugLabel: 'ChoiceYes');
      final choiceNo = FocusNode(debugLabel: 'ChoiceNo');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                // TV Sidebar (x: 0..72)
                Container(
                  width: 72,
                  color: Colors.black,
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      TvFocusable(
                        focusNode: sidebarHome,
                        child: const SizedBox(
                          width: 58,
                          height: 52,
                          child: Text('Home'),
                        ),
                      ),
                      const SizedBox(height: 100),
                      TvFocusable(
                        focusNode: sidebarSettings,
                        child: const SizedBox(
                          width: 58,
                          height: 52,
                          child: Text('Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
                // Subpage Content Area (x: 72..end)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(36, 20, 36, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Breadcrumb Button (x: ~108, y: ~20..52)
                        TvFocusable(
                          focusNode: backBtn,
                          child: const SizedBox(
                            width: 72,
                            height: 32,
                            child: Text('Back'),
                          ),
                        ),
                        const SizedBox(height: 60),
                        // Choice 1: 'Yes' (autofocused)
                        TvFocusable(
                          focusNode: choiceYes,
                          autofocus: true,
                          child: const SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: Text('Yes'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Choice 2: 'No'
                        TvFocusable(
                          focusNode: choiceNo,
                          child: const SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: Text('No'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(choiceYes.hasFocus, isTrue);
      expect(sidebarHome.hasFocus, isFalse);
      expect(backBtn.hasFocus, isFalse);

      // Press UP from 'Yes'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      // MUST go directly to 'Back' button, NEVER jump to 'Home' in sidebar!
      expect(backBtn.hasFocus, isTrue, reason: 'UP from Yes must focus Back');
      expect(sidebarHome.hasFocus, isFalse, reason: 'Must not focus sidebar');
      expect(choiceYes.hasFocus, isFalse);

      // Press DOWN from 'Back'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // MUST return directly to 'Yes'
      expect(
        choiceYes.hasFocus,
        isTrue,
        reason: 'DOWN from Back must return to Yes',
      );
      expect(backBtn.hasFocus, isFalse);
      expect(sidebarHome.hasFocus, isFalse);

      // Press DOWN from 'Yes'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(choiceNo.hasFocus, isTrue);

      // Press UP from 'No'
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(choiceYes.hasFocus, isTrue);
    },
  );

  testWidgets(
    'TvSpatialNavigation D-Pad Left from page content NEVER enters the sidebar',
    (tester) async {
      final sidebarHome = FocusNode(debugLabel: 'SidebarHome');
      final contentCard = FocusNode(debugLabel: 'ContentCard');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                // TV Sidebar (x: 0..72)
                Container(
                  width: 72,
                  color: Colors.black,
                  child: Center(
                    child: TvFocusable(
                      focusNode: sidebarHome,
                      child: const SizedBox(
                        width: 58,
                        height: 52,
                        child: Text('Home'),
                      ),
                    ),
                  ),
                ),
                // Page Content (x: 72..end)
                Expanded(
                  child: Center(
                    child: TvFocusable(
                      focusNode: contentCard,
                      autofocus: true,
                      child: const SizedBox(
                        width: 150,
                        height: 200,
                        child: Text('Content'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(contentCard.hasFocus, isTrue);
      expect(sidebarHome.hasFocus, isFalse);

      // Press D-Pad Left from content: MUST NOT move to sidebar! Must stay on content!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(
        contentCard.hasFocus,
        isTrue,
        reason: 'Left from content must stay on content',
      );
      expect(
        sidebarHome.hasFocus,
        isFalse,
        reason: 'Left must never jump into the TV sidebar',
      );
    },
  );

  testWidgets(
    'TvSpatialNavigation pressing Down focuses directly aligned bottom item, not side item',
    (tester) async {
      final watchButton = FocusNode(debugLabel: 'WatchButton');
      final bottomAlignedCard = FocusNode(debugLabel: 'BottomAlignedCard');
      final sideCard = FocusNode(debugLabel: 'SideCard');

      // Layout:
      // Row 0: Watch Button at left: 80, top: 100, width: 100, height: 40
      // Row 1:
      //   - BottomAlignedCard at left: 80, top: 200, width: 120, height: 160 (directly below Watch)
      //   - SideCard at left: 260, top: 170, width: 120, height: 160 (slightly higher, but far to the right)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 80,
                  top: 100,
                  width: 100,
                  height: 40,
                  child: TvFocusable(
                    focusNode: watchButton,
                    autofocus: true,
                    child: const Text('Watch'),
                  ),
                ),
                Positioned(
                  left: 260,
                  top: 170,
                  width: 120,
                  height: 160,
                  child: TvFocusable(
                    focusNode: sideCard,
                    child: const Text('Side Item'),
                  ),
                ),
                Positioned(
                  left: 80,
                  top: 200,
                  width: 120,
                  height: 160,
                  child: TvFocusable(
                    focusNode: bottomAlignedCard,
                    child: const Text('Bottom Item'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(watchButton.hasFocus, isTrue);

      // Press Down from Watch Button:
      // Must focus BottomAlignedCard (directly aligned vertically), NOT SideCard
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(
        bottomAlignedCard.hasFocus,
        isTrue,
        reason: 'Pressing Down must focus the directly aligned bottom item',
      );
      expect(
        sideCard.hasFocus,
        isFalse,
        reason: 'Pressing Down must not jump sideways',
      );
    },
  );

  testWidgets(
    'TvEpisodeCard short tap fires onTap, while holding OK fires onLongPress',
    (tester) async {
      bool tapped = false;
      bool longPressed = false;

      final ep = Episode(season: 1, episode: 1, title: 'Pilot');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: TvEpisodeCard(
                episode: ep,
                thumbnailUrl: null,
                title: 'Pilot',
                overview: 'First episode',
                resumePositionSeconds: 0,
                autofocus: true,
                onTap: () => tapped = true,
                onLongPress: () => longPressed = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Quick tap (press down then up before 550ms)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(longPressed, isFalse);

      // Reset
      tapped = false;
      longPressed = false;

      // 2. Hold OK (press down and hold for > 550ms)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
      expect(tapped, isFalse);

      // Release key after hold
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(
        tapped,
        isFalse,
        reason: 'Key release after long press must not trigger tap',
      );
    },
  );

  testWidgets(
    'Navigating to a screen that loads asynchronously and testing D-Pad focus traversal',
    (tester) async {
      final homeFocusNode = FocusNode(debugLabel: 'HomeCard');
      final playBtnFocusNode = FocusNode(debugLabel: 'PlayBtn');
      final myListFocusNode = FocusNode(debugLabel: 'MyListBtn');

      late void Function(void Function()) setScreenState;
      bool isLoading = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TvFocusable(
                focusNode: homeFocusNode,
                autofocus: true,
                child: const Text('Home Card'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(homeFocusNode.hasFocus, isTrue);

      // Now push details route
      final navContext = tester.element(find.text('Home Card'));
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (context) {
            return StatefulBuilder(
              builder: (ctx, setState) {
                setScreenState = setState;
                if (isLoading) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return Scaffold(
                  body: Row(
                    children: [
                      TvFocusable(
                        focusNode: playBtnFocusNode,
                        autofocus: true,
                        child: const Text('Play'),
                      ),
                      const SizedBox(width: 20),
                      TvFocusable(
                        focusNode: myListFocusNode,
                        child: const Text('My List'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // In loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Finish loading
      setScreenState(() {
        isLoading = false;
      });
      await tester.pump();
      await tester.pumpAndSettle();

      expect(playBtnFocusNode.hasFocus, isTrue);
      expect(homeFocusNode.hasFocus, isFalse);

      // Press Arrow Right
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(myListFocusNode.hasFocus, isTrue);
      expect(playBtnFocusNode.hasFocus, isFalse);
    },
  );

  testWidgets(
    'TvEpisodeCard with isLastCard:true does not leak focus to shelf below or disappear on D-Pad Right',
    (tester) async {
      final epLastFocusNode = FocusNode(debugLabel: 'LastEpisode');
      final relatedCardFocusNode = FocusNode(debugLabel: 'RelatedCard');

      final dummyEpisode = Episode(season: 1, episode: 16, title: 'Episode 16');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shelf 1: Episode Card (Last Card)
                  TvEpisodeCard(
                    episode: dummyEpisode,
                    thumbnailUrl: null,
                    title: 'Episode 16',
                    overview: 'Season Finale',
                    resumePositionSeconds: 0,
                    autofocus: true,
                    focusNode: epLastFocusNode,
                    isLastCard: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 40),
                  // Shelf 2: Related Cards below
                  TvFocusable(
                    focusNode: relatedCardFocusNode,
                    child: const SizedBox(
                      width: 120,
                      height: 180,
                      child: Text('Related Card'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(epLastFocusNode.hasFocus, isTrue);
      expect(relatedCardFocusNode.hasFocus, isFalse);

      // Press D-Pad Right on last card -> must NOT move to related card below, focus must remain on last episode
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(epLastFocusNode.hasFocus, isTrue);
      expect(relatedCardFocusNode.hasFocus, isFalse);

      // Even on rapid / repeated D-Pad Right -> focus must still stay on last episode
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(epLastFocusNode.hasFocus, isTrue);
      expect(relatedCardFocusNode.hasFocus, isFalse);

      // Press D-Pad Down -> Now it moves to related card below!
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(epLastFocusNode.hasFocus, isFalse);
      expect(relatedCardFocusNode.hasFocus, isTrue);
    },
  );

  testWidgets(
    'Moving down between category shelves in Dpad lands directly on next shelf in a single press',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appProvider = AppProvider();
      appProvider.setTvMode(true);

      final items1 = List.generate(
        5,
        (i) => MediaItem(
          id: 's1_item_$i',
          title: 'Shelf 1 Item $i',
          mediaType: MediaType.movie,
        ),
      );
      final items2 = List.generate(
        5,
        (i) => MediaItem(
          id: 's2_item_$i',
          title: 'Shelf 2 Item $i',
          mediaType: MediaType.movie,
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: appProvider,
          child: MaterialApp(
            builder: (context, child) => Dpad(child: child!),
            home: Scaffold(
              body: ListView(
                children: [
                  HomeMediaShelf(
                    title: 'Shelf 1',
                    icon: Icons.movie,
                    items: items1,
                    shelfPrefix: 's1',
                    onItemSelect: (_, _) {},
                  ),
                  HomeMediaShelf(
                    title: 'Shelf 2',
                    icon: Icons.tv,
                    items: items2,
                    shelfPrefix: 's2',
                    onItemSelect: (_, _) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find first card focus node
      final firstCardText = find.text('Shelf 1 Item 0');
      expect(firstCardText, findsOneWidget);

      // Tap first card to give it focus
      await tester.tap(firstCardText);
      await tester.pumpAndSettle();

      // Verify Shelf 1 card is focused
      expect(find.text('Shelf 1 Item 0'), findsOneWidget);

      // Press arrowDown once
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Focus must land on Shelf 2 in that single press!
      final currentFocus = FocusManager.instance.primaryFocus;
      expect(currentFocus, isNotNull);
      final focusedWidget = currentFocus!.context?.widget;
      expect(focusedWidget, isNotNull);

      // Verify focused node is inside Shelf 2
      final shelf2TextFinder = find.descendant(
        of: find.byWidget(currentFocus.context!.widget),
        matching: find.text('Shelf 2 Item 0'),
      );
      expect(shelf2TextFinder, findsOneWidget);
    },
  );
}
