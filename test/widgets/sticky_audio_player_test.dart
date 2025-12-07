import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memories/widgets/sticky_audio_player.dart';

import '../helpers/fake_just_audio_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StickyAudioPlayer', () {
    setUp(() {
      JustAudioPlatform.instance = FakeJustAudioPlatform();
    });

    Widget createWidget({
      String? audioUrl,
      double? duration,
      String storyId = 'test-story-id',
      bool enablePositionUpdates = true,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StickyAudioPlayer(
              audioUrl: audioUrl,
              duration: duration,
              storyId: storyId,
              enablePositionUpdates: enablePositionUpdates,
            ),
          ),
        ),
      );
    }

    Future<void> pumpPlayer(WidgetTester tester, Widget widget) async {
      await tester.pumpWidget(widget);
      await tester.pump(const Duration(milliseconds: 200));
    }

    Future<void> disposePlayer(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('shows placeholder when audio URL is null', (tester) async {
      addTearDown(() => disposePlayer(tester));
      await pumpPlayer(
        tester,
        createWidget(
          audioUrl: null,
          enablePositionUpdates: false,
        ),
      );

      expect(
          find.text('Audio is not available for this story'), findsOneWidget);
      expect(find.byIcon(Icons.audio_file_outlined), findsOneWidget);
    });

    testWidgets('renders controls when audio URL and duration are provided',
        (tester) async {
      addTearDown(() => disposePlayer(tester));
      await pumpPlayer(
        tester,
        createWidget(
          audioUrl: 'https://example.com/audio.mp3',
          duration: 90.0,
          enablePositionUpdates: false,
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets(
        'renders controls when duration is missing but audio URL exists',
        (tester) async {
      addTearDown(() => disposePlayer(tester));
      await pumpPlayer(
        tester,
        createWidget(
          audioUrl: 'https://example.com/audio.mp3',
          duration: null,
          enablePositionUpdates: false,
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });
  });
}
