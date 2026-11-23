import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  Future<void> init() async {
    _isInitialized = await _stt.initialize(
      // Clears "listening" in the UI when recognition stops without a final
      // result (timeout, no speech, permission revoked).
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _onDone?.call();
      },
      onError: (_) => _onDone?.call(),
    );
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  bool get isAvailable => _isInitialized;
  bool get isListening => _stt.isListening;

  void Function()? _onDone;

  /// Starts listening; returns false when speech recognition is unavailable.
  /// [onResult] is called once with the final text (empty when nothing was
  /// recognised).
  Future<bool> startListening(void Function(String text) onResult) async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return false;

    var delivered = false;
    void deliver(String text) {
      if (delivered) return;
      delivered = true;
      _onDone = null;
      onResult(text);
    }

    _onDone = () => deliver('');

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          deliver(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );
    return true;
  }

  Future<void> stopListening() async {
    await _stt.stop();
  }

  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  void dispose() {
    _onDone = null;
    // Ignore failures: speech plugins aren't available on every platform,
    // and an unhandled error here would surface as a crash report.
    _stt.cancel().catchError((_) {});
    _tts.stop().catchError((_) {});
  }
}
