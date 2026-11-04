import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sarisa/features/dji/models/drone_video_source.dart';
import 'package:sarisa/features/dji/services/local_ai_engine.dart';

void main() {
  const drone = DroneVideoSource(
    id: 'drone-1',
    modelId: 'mini4pro',
    displayName: 'DJI Mini 4 Pro',
    status: DroneConnectionStatus.streaming,
  );

  group('LocalAiEngine', () {
    test('processes a frame and returns its detection result', () async {
      final engine = LocalAiEngine.forTesting(
        analyzer: (_) async => const PersonFrameAnalysis(
          personCount: 2,
          maxConfidence: 0.91,
        ),
      );

      final event = await engine.submitFrame(
        source: drone,
        imagePath: '/frames/frame-001.jpg',
        latitude: 41.9981,
        longitude: 21.4254,
      );

      expect(event.droneId, 'drone-1');
      expect(event.droneName, 'DJI Mini 4 Pro');
      expect(event.personCount, 2);
      expect(event.maxConfidence, 0.91);
      expect(event.maxConfidencePercent, 91);
      expect(event.containsPerson, isTrue);
      expect(event.latitude, 41.9981);
      expect(event.longitude, 21.4254);
    });

    test('does not process frames from disabled drones', () async {
      var analyzerCalled = false;

      final engine = LocalAiEngine.forTesting(
        analyzer: (_) async {
          analyzerCalled = true;
          return const PersonFrameAnalysis(
            personCount: 0,
            maxConfidence: 0,
          );
        },
      );

      final disabledDrone = drone.copyWith(enabled: false);

      await expectLater(
        engine.submitFrame(
          source: disabledDrone,
          imagePath: '/frames/frame.jpg',
        ),
        throwsA(isA<StateError>()),
      );

      expect(analyzerCalled, isFalse);
    });

    test('processes frames sequentially, never concurrently', () async {
      final first = Completer<PersonFrameAnalysis>();
      final second = Completer<PersonFrameAnalysis>();
      final secondStarted = Completer<void>();

      var activeCalls = 0;
      var maximumActiveCalls = 0;
      var callCount = 0;

      Future<PersonFrameAnalysis> analyzer(String path) {
        activeCalls++;
        if (activeCalls > maximumActiveCalls) {
          maximumActiveCalls = activeCalls;
        }

        callCount++;

        if (path == 'second' && !secondStarted.isCompleted) {
          secondStarted.complete();
        }

        final result = path == 'first' ? first.future : second.future;

        return result.whenComplete(() {
          activeCalls--;
        });
      }

      final engine = LocalAiEngine.forTesting(analyzer: analyzer);

      final firstResult = engine.submitFrame(
        source: drone,
        imagePath: 'first',
      );

      final secondResult = engine.submitFrame(
        source: drone,
        imagePath: 'second',
      );

      expect(callCount, 1);
      expect(engine.queuedFrames, 1);

      first.complete(
        const PersonFrameAnalysis(personCount: 1, maxConfidence: 0.8),
      );

      await secondStarted.future;

      expect(callCount, 2);

      second.complete(
        const PersonFrameAnalysis(personCount: 0, maxConfidence: 0),
      );

      final results = await Future.wait([firstResult, secondResult]);

      expect(results[0].personCount, 1);
      expect(results[1].personCount, 0);
      expect(maximumActiveCalls, 1);
      expect(engine.isProcessing, isFalse);
    });

    test('rejects frames when the waiting queue is full', () async {
      final blocker = Completer<PersonFrameAnalysis>();

      final engine = LocalAiEngine.forTesting(
        maxQueuedFrames: 1,
        analyzer: (_) => blocker.future,
      );

      final first = engine.submitFrame(
        source: drone,
        imagePath: 'processing',
      );

      final second = engine.submitFrame(
        source: drone,
        imagePath: 'waiting',
      );

      expect(engine.queuedFrames, 1);

      await expectLater(
        engine.submitFrame(
          source: drone,
          imagePath: 'overflow',
        ),
        throwsA(isA<StateError>()),
      );

      blocker.complete(
        const PersonFrameAnalysis(personCount: 0, maxConfidence: 0),
      );

      await Future.wait([first, second]);
    });
  });
}
