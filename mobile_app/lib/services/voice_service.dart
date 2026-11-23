import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Reply text without markdown symbols, so text-to-speech doesn't read out
/// "asterisk" or "hash".
String speakableText(String text) {
  return text
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'[*_`#>]+'), '')
      .replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), '')
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]*\)'),
        (match) => match.group(1) ?? '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Turns the speech plugin's events into exactly one final answer.
///
/// Android reports "notListening" as soon as you stop talking and only
/// then delivers the recognised words, so the end of listening must never
/// be taken as "nothing was said". We keep the latest words heard and wait
/// a moment for the final result before finishing with them.
class SpeechCapture {
  SpeechCapture({
    required this.onFinished,
    this.onPartial,
    this.grace = const Duration(milliseconds: 1500),
  });

  /// Called once with what was said ('' when nothing was understood).
  final void Function(String text) onFinished;

  /// Called with the words so far while the user is still talking.
  final void Function(String text)? onPartial;

  /// How long to wait for the final words after listening stops.
  final Duration grace;

  String _latest = '';
  bool _finished = false;
  Timer? _timer;

  bool get isFinished => _finished;
  String get latest => _latest;

  void words(String text, {required bool isFinal}) {
    if (_finished) return;
    if (text.trim().isNotEmpty) _latest = text.trim();
    if (isFinal) {
      _finish();
    } else {
      onPartial?.call(_latest);
    }
  }

  void status(String status) {
    if (_finished) return;
    if (status == SpeechToText.doneStatus) {
      // "done" comes after the final result: nothing more is coming.
      _finish();
    } else if (status == SpeechToText.notListeningStatus) {
      // Words may still be on their way.
      _timer ??= Timer(grace, _finish);
    }
  }

  /// "No match" or a timeout: keep whatever was heard so far.
  void error() => _finish();

  void _finish() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    onFinished(_latest);
  }

  void cancel() {
    _finished = true;
    _timer?.cancel();
  }
}

class VoiceService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  String? _localeId;

  /// The capture in progress; plugin callbacks are routed to it.
  SpeechCapture? _capture;

  /// The last error from the speech plugin, e.g. "error_permission".
  String? lastError;

  Future<void> init() async {
    _isInitialized = await _stt.initialize(
      onStatus: (status) => _capture?.status(status),
      onError: (SpeechRecognitionError error) {
        lastError = error.errorMsg;
        debugPrint('Speech error: ${error.errorMsg}');
        _capture?.error();
      },
    );
    if (_isInitialized) _localeId = await _pickLocale();

    // Speaking is optional; a phone without a TTS engine can still listen.
    try {
      // speak() then waits until Liyana has finished talking.
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (error) {
      debugPrint('Text-to-speech setup failed: $error');
    }
  }

  /// English (US) when the phone has it, otherwise the phone's own
  /// language, so recognition never fails on a missing locale.
  Future<String?> _pickLocale() async {
    try {
      final locales = await _stt.locales();
      final ids = locales.map((l) => l.localeId.replaceAll('-', '_')).toSet();
      if (ids.contains('en_US')) return 'en_US';
      for (final id in ids) {
        if (id.startsWith('en_')) return id;
      }
      return (await _stt.systemLocale())?.localeId;
    } catch (_) {
      return null;
    }
  }

  bool get isAvailable => _isInitialized;
  bool get isListening => _stt.isListening;

  /// Starts listening; returns false when speech recognition is unavailable.
  /// [onResult] is called once with what was said (empty when nothing was
  /// understood); [onPartial] shows the words as they are recognised.
  Future<bool> startListening(
    void Function(String text) onResult, {
    void Function(String text)? onPartial,
  }) async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return false;

    _capture?.cancel();
    lastError = null;
    final capture = SpeechCapture(
      onPartial: onPartial,
      onFinished: (text) {
        _capture = null;
        onResult(text);
      },
    );
    _capture = capture;

    await _stt.listen(
      onResult: (SpeechRecognitionResult result) =>
          capture.words(result.recognizedWords, isFinal: result.finalResult),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: _localeId,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
    return true;
  }

  /// Stop listening and use what was heard so far.
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
    _capture?.cancel();
    _capture = null;
    // Ignore failures: speech plugins aren't available on every platform,
    // and an unhandled error here would surface as a crash report.
    _stt.cancel().catchError((_) {});
    _tts.stop().catchError((_) {});
  }
}
