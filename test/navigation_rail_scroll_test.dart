import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NavigationRail scrollable in short landscape', (tester) async {
    // Set small landscape height: 350px
    tester.binding.window.physicalSizeTestValue = const Size(800, 350);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          selectedIndex: 0,
                          labelType: NavigationRailLabelType.all,
                          leading: const Column(
                            children: [
                              SizedBox(height: 24),
                              Icon(Icons.movie),
                              Text('Exalere'),
                              SizedBox(height: 24),
                            ],
                          ),
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.home),
                              label: Text('Home'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.search),
                              label: Text('Search'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.live_tv),
                              label: Text('Live TV'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.video_library),
                              label: Text('My List'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.settings),
                              label: Text('Settings'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const Expanded(child: Center(child: Text('Content'))),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
  });
}
