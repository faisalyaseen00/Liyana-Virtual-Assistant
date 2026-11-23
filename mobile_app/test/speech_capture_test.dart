import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/voice_service.dart';

void main() {
  late List<String> finished;
  late List<String> partials;

  SpeechCapture capture({Duration grace = const Duration(milliseconds: 30)}) =>
      SpeechCapture(
        onFinished: finished.add,
        onPartial: partials.add,
        grace: grace,
      );

  setUp(() {
    finished = [];
    partials = [];
  });

  test(
    'the bug: "notListening" arrives before the words, words still sent',
    () async {
      final c = capture();
      c.words('make a task', isFinal: false);
      c.status('notListening'); // you stopped talking
      c.words('make a task to buy milk', isFinal: true); // words arrive late

      expect(finished, ['make a task to buy milk']);
      expect(partials, ['make a task']);
    },
  );

  test('no final result after stopping: sends the last words heard', () async {
    final c = capture();
    c.words('remind me at 5', isFinal: false);
    c.status('notListening');
    expect(finished, isEmpty); // still waiting for the final words

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(finished, ['remind me at 5']);
  });

  test('"done" finishes straight away with what was heard', () {
    final c = capture();
    c.words('hello liyana', isFinal: false);
    c.status('done');
    expect(finished, ['hello liyana']);
  });

  test('an error keeps the words heard so far', () {
    final c = capture();
    c.words('show my tasks', isFinal: false);
    c.error();
    expect(finished, ['show my tasks']);
  });

  test('silence finishes with empty text so the app can say so', () async {
    final c = capture();
    c.status('notListening');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(finished, ['']);
  });

  test('finishes exactly once', () async {
    final c = capture();
    c.words('one', isFinal: true);
    c.status('notListening');
    c.status('done');
    c.error();
    c.words('two', isFinal: true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(finished, ['one']);
  });

  test('a cancelled capture never reports', () async {
    final c = capture();
    c.words('partial', isFinal: false);
    c.status('notListening');
    c.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(finished, isEmpty);
  });
}
