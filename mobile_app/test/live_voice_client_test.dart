import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/live/live_audio.dart';
import 'package:mobile_app/features/live/live_voice_client.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeSink implements WebSocketSink {
  final List<Object?> sent = [];
  bool closed = false;

  @override
  void add(Object? data) => sent.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {}

  @override
  Future close([int? closeCode, String? closeReason]) async => closed = true;

  @override
  Future get done => Future.value();
}

/// A socket the test drives: [server] pushes messages to the app.
class FakeChannel with StreamChannelMixin implements WebSocketChannel {
  final StreamController<dynamic> server = StreamController<dynamic>();
  @override
  final FakeSink sink = FakeSink();
  int? _closeCode;

  @override
  Stream get stream => server.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  void closeWith(int code) {
    _closeCode = code;
    server.close();
  }

  List<Map<String, dynamic>> get sentJson => sink.sent
      .whereType<String>()
      .map((s) => jsonDecode(s) as Map<String, dynamic>)
      .toList();
}

class FakeAudio implements LiveAudio {
  bool allowMic = true;
  final StreamController<Uint8List> mic = StreamController<Uint8List>();
  final List<Uint8List> played = [];
  int stops = 0;
  void Function()? onIdle;

  @override
  Future<bool> requestMicPermission() async => allowMic;

  @override
  Future<Stream<Uint8List>> startMic() async => mic.stream;

  @override
  Future<void> stopMic() async {}

  @override
  Future<void> startPlayer({required void Function() onIdle}) async =>
      this.onIdle = onIdle;

  @override
  void play(Uint8List pcm) => played.add(pcm);

  @override
  Future<void> stopPlayback() async => stops++;

  @override
  Future<void> stopPlayer() async {}
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('live endpoint comes from the API base URL', () {
    expect(
      LiveVoiceClient.liveUri('https://api.example.com/api/v1').toString(),
      'wss://api.example.com/api/v1/live',
    );
    expect(
      LiveVoiceClient.liveUri('http://10.0.2.2:8000/api/v1/').toString(),
      'ws://10.0.2.2:8000/api/v1/live',
    );
  });

  test(
    'a full live turn: audio both ways, captions, tools, interrupt',
    () async {
      final channel = FakeChannel();
      final audio = FakeAudio();
      final tools = <String>[];
      final client = LiveVoiceClient(
        audio: audio,
        connect: (_) => channel,
        accessToken: () async => 'token-1',
        refreshToken: () async => null,
        onTool: tools.add,
      );

      final starting = client.start();
      await settle();
      expect(channel.sentJson.first, {'type': 'auth', 'token': 'token-1'});
      channel.server.add(jsonEncode({'type': 'ready'}));
      await starting;
      expect(client.status, LiveStatus.listening);

      // Microphone audio goes up as binary frames, unless muted.
      audio.mic.add(Uint8List.fromList([1, 2]));
      await settle();
      client.toggleMute();
      audio.mic.add(Uint8List.fromList([3, 4]));
      await settle();
      client.toggleMute();
      expect(channel.sink.sent.whereType<Uint8List>().toList(), [
        Uint8List.fromList([1, 2]),
      ]);

      channel.server
        ..add(
          jsonEncode({'type': 'transcript', 'role': 'user', 'text': 'add '}),
        )
        ..add(
          jsonEncode({'type': 'transcript', 'role': 'user', 'text': 'milk'}),
        )
        ..add(jsonEncode({'type': 'tool', 'name': 'create_task'}))
        ..add(Uint8List.fromList([9, 9]))
        ..add(
          jsonEncode({
            'type': 'transcript',
            'role': 'assistant',
            'text': 'Done, ',
          }),
        )
        ..add(
          jsonEncode({
            'type': 'transcript',
            'role': 'assistant',
            'text': 'added milk.',
          }),
        );
      await settle();

      expect(client.status, LiveStatus.speaking);
      expect(audio.played, [
        Uint8List.fromList([9, 9]),
      ]);
      expect(tools, ['create_task']);
      expect(client.lines.map((l) => '${l.role}: ${l.text}'), [
        'user: add milk',
        'assistant: Done, added milk.',
      ]);

      channel.server.add(jsonEncode({'type': 'interrupted'}));
      await settle();
      expect(audio.stops, 1);
      expect(client.status, LiveStatus.listening);

      channel.server.add(
        jsonEncode({'type': 'turn_complete', 'conversation_id': 'conv-1'}),
      );
      await settle();
      expect(client.conversationId, 'conv-1');

      client.sendText('thanks');
      await client.end();
      expect(channel.sentJson.map((m) => m['type']), ['auth', 'text', 'end']);
      expect(client.status, LiveStatus.ended);
    },
  );

  test('refreshes an expired token once and reconnects', () async {
    final first = FakeChannel();
    final second = FakeChannel();
    final channels = [first, second];
    final client = LiveVoiceClient(
      audio: FakeAudio(),
      connect: (_) => channels.removeAt(0),
      accessToken: () async => 'old',
      refreshToken: () async => 'new',
    );

    final starting = client.start();
    await settle();
    first.closeWith(4401);
    await settle();
    expect(second.sentJson.first['token'], 'new');
    second.server.add(jsonEncode({'type': 'ready'}));
    await starting;

    expect(client.status, LiveStatus.listening);
    await client.end();
  });

  test(
    'without microphone permission it explains instead of connecting',
    () async {
      var connected = false;
      final client = LiveVoiceClient(
        audio: FakeAudio()..allowMic = false,
        connect: (_) {
          connected = true;
          return FakeChannel();
        },
        accessToken: () async => 't',
        refreshToken: () async => null,
      );

      await client.start();

      expect(connected, isFalse);
      expect(client.status, LiveStatus.failed);
      expect(client.error, contains('microphone'));
    },
  );
}
