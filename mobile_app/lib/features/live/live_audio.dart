import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart' hide IosAudioCategory;

/// Microphone in, speaker out, for a live call. The client only talks to
/// this interface so tests can use a fake.
abstract class LiveAudio {
  Future<bool> requestMicPermission();

  /// 16 kHz mono 16-bit PCM from the microphone.
  Future<Stream<Uint8List>> startMic();
  Future<void> stopMic();

  /// [onIdle] runs when everything queued has been played.
  Future<void> startPlayer({required void Function() onIdle});

  /// Queue 24 kHz mono 16-bit PCM for playback.
  void play(Uint8List pcm);

  /// Drop whatever is still queued (the user interrupted).
  Future<void> stopPlayback();
  Future<void> stopPlayer();
}

class DeviceLiveAudio implements LiveAudio {
  static const int micRate = 16000;
  static const int speakerRate = 24000;

  final AudioRecorder _recorder = AudioRecorder();
  void Function()? _onIdle;
  bool _playerReady = false;

  @override
  Future<bool> requestMicPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> startMic() {
    return _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: micRate,
        numChannels: 1,
        // Keep Liyana's own voice out of the microphone, so she isn't
        // "interrupted" by herself through the speaker.
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
        iosConfig: IosRecordConfig(
          categoryOptions: [
            IosAudioCategoryOption.defaultToSpeaker,
            IosAudioCategoryOption.allowBluetooth,
          ],
        ),
      ),
    );
  }

  @override
  Future<void> stopMic() async {
    if (await _recorder.isRecording()) await _recorder.stop();
  }

  Future<void> _setupPlayer() async {
    await FlutterPcmSound.setup(
      sampleRate: speakerRate,
      channelCount: 1,
      iosAudioCategory: IosAudioCategory.playAndRecord,
    );
    // Ask for "more" when under 0.1 s is left; with nothing left we
    // report idle so the screen switches back to "Listening".
    await FlutterPcmSound.setFeedThreshold(speakerRate ~/ 10);
    FlutterPcmSound.setFeedCallback((remaining) {
      if (remaining == 0) _onIdle?.call();
    });
    _playerReady = true;
  }

  @override
  Future<void> startPlayer({required void Function() onIdle}) async {
    _onIdle = onIdle;
    await _setupPlayer();
  }

  @override
  void play(Uint8List pcm) {
    if (!_playerReady || pcm.isEmpty) return;
    // Copy: feed() sends the whole underlying buffer, not just this view.
    final copy = Uint8List.fromList(pcm);
    FlutterPcmSound.feed(PcmArrayInt16(bytes: copy.buffer.asByteData()));
  }

  @override
  Future<void> stopPlayback() async {
    if (!_playerReady) return;
    // The plugin can't drop queued audio, so start a fresh player.
    _playerReady = false;
    await FlutterPcmSound.release();
    await _setupPlayer();
  }

  @override
  Future<void> stopPlayer() async {
    _playerReady = false;
    _onIdle = null;
    FlutterPcmSound.setFeedCallback(null);
    await FlutterPcmSound.release();
  }
}
