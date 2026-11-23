import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/voice_service.dart';

void main() {
  test('strips markdown so it is not read aloud', () {
    expect(
      speakableText('Here are **3 tips**:\n- Use a [timer](https://x.y)\n- Take #breaks'),
      'Here are 3 tips: Use a timer Take breaks',
    );
  });

  test('leaves plain replies alone', () {
    const reply = 'Done! I\'ve added the task "Submit report", due Friday at 5 PM.';
    expect(speakableText(reply), reply);
  });
}
