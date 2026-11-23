import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/secure_storage.dart';
import '../auth/auth_service.dart';
import 'live_audio.dart';

/// Where a live call is at; drives the screen.
enum LiveStatus { idle, connecting, listening, speaking, ended, failed }

/// One line of the live caption: who spoke and what they said.
class LiveLine {
  LiveLine(this.role, this.text);

  final String role; // "user" or "assistant"
  String text;

  bool get isUser => role == 'user';
}

typedef ChannelFactory = WebSocketChannel Function(Uri uri);
typedef TokenSource = Future<String?> Function();

/// Talks to the backend's /live WebSocket: streams the microphone up,
/// plays Liyana's voice as it arrives and keeps a running transcript.
/// Audio devices sit behind [LiveAudio] so this logic is testable.
class LiveVoiceClient extends ChangeNotifier {
  LiveVoiceClient({
    LiveAudio? audio,
    ChannelFactory? connect,
    TokenSource? accessToken,
    TokenSource? refreshToken,
    this.onTool,
  }) : _audio = audio ?? DeviceLiveAudio(),
       _connect = connect ?? WebSocketChannel.connect,
       _accessToken = accessToken ?? SecureStorage.getAccessToken,
       _refreshToken = refreshToken ?? _refreshOrNull;

  final LiveAudio _audio;
  final ChannelFactory _connect;
  final TokenSource _accessToken;
  final TokenSource _refreshToken;

  /// Liyana ran a tool (e.g. "create_task"); refresh that part of the app.
  final void Function(String tool)? onTool;

  static Future<String?> _refreshOrNull() async {
    try {
      return await AuthService.refreshToken();
    } catch (_) {
      return null;
    }
  }

  /// The backend's live endpoint: http(s)://host/api/v1 -> ws(s)://host/api/v1/live
  static Uri liveUri([String? apiBaseUrl]) {
    final base = Uri.parse(apiBaseUrl ?? AppConstants.apiBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    return base.replace(scheme: scheme, path: '${path}live');
  }

  LiveStatus _status = LiveStatus.idle;
  LiveStatus get status => _status;

  String? _error;
  String? get error => _error;

  bool _muted = false;
  bool get muted => _muted;

  final List<LiveLine> _lines = [];
  List<LiveLine> get lines => List.unmodifiable(_lines);

  /// Chat history id of this call, once the first turn is saved.
  String? conversationId;

  WebSocketChannel? _channel;
  StreamSubscription? _socketSub;
  StreamSubscription<Uint8List>? _micSub;
  bool _assistantTurnOpen = false;
  bool _closing = false;

  Future<void> start() async {
    if (_status == LiveStatus.connecting ||
        _status == LiveStatus.listening ||
        _status == LiveStatus.speaking) {
      return;
    }
    _closing = false;
    _error = null;
    _set(LiveStatus.connecting);

    if (!await _audio.requestMicPermission()) {
      return _fail('Liyana needs microphone access to talk with you.');
    }

    var token = await _accessToken();
    var result = await _open(token);
    if (result == _OpenResult.unauthorized) {
      // Access tokens are short-lived; refresh once and try again.
      token = await _refreshToken();
      result = token == null ? _OpenResult.unauthorized : await _open(token);
    }

    switch (result) {
      case _OpenResult.ready:
        await _startAudio();
      case _OpenResult.unauthorized:
        _fail('Please sign in again to talk with Liyana.');
      case _OpenResult.failed:
        if (_status != LiveStatus.failed) {
          _fail("Couldn't reach Liyana. Check your connection and try again.");
        }
    }
  }

  Future<_OpenResult> _open(String? token) async {
    await _closeSocket();
    final ready = Completer<_OpenResult>();

    try {
      final channel = _connect(liveUri());
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 10));

      _socketSub = channel.stream.listen(
        (data) {
          if (!ready.isCompleted && data is String) {
            final message = _decode(data);
            if (message['type'] == 'ready') {
              ready.complete(_OpenResult.ready);
              return;
            }
          }
          _onMessage(data);
        },
        onDone: () {
          final code = channel.closeCode;
          if (!ready.isCompleted) {
            ready.complete(
              code == 4401 ? _OpenResult.unauthorized : _OpenResult.failed,
            );
            return;
          }
          _onClosed(code, channel.closeReason);
        },
        onError: (_) {
          if (!ready.isCompleted) ready.complete(_OpenResult.failed);
        },
        cancelOnError: true,
      );

      channel.sink.add(jsonEncode({'type': 'auth', 'token': token ?? ''}));
      return await ready.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => _OpenResult.failed,
      );
    } catch (_) {
      return _OpenResult.failed;
    }
  }

  Future<void> _startAudio() async {
    try {
      await _audio.startPlayer(onIdle: _onPlaybackIdle);
      final mic = await _audio.startMic();
      _micSub = mic.listen((chunk) {
        if (_muted || _closing) return;
        _channel?.sink.add(chunk);
      });
      _set(LiveStatus.listening);
    } catch (_) {
      await end();
      _fail("Couldn't start the microphone.");
    }
  }

  void _onMessage(dynamic data) {
    if (data is List<int>) {
      // Liyana's voice: 24 kHz mono 16-bit PCM.
      _audio.play(data is Uint8List ? data : Uint8List.fromList(data));
      if (_status == LiveStatus.listening) _set(LiveStatus.speaking);
      return;
    }
    if (data is! String) return;

    final message = _decode(data);
    switch (message['type']) {
      case 'transcript':
        _addTranscript(
          message['role'] as String? ?? 'assistant',
          message['text'] as String? ?? '',
        );
      case 'interrupted':
        // The user started talking over Liyana: stop her right away.
        _audio.stopPlayback();
        _assistantTurnOpen = false;
        _set(LiveStatus.listening);
      case 'tool':
        final name = message['name'];
        if (name is String) onTool?.call(name);
      case 'turn_complete':
        _assistantTurnOpen = false;
        final id = message['conversation_id'];
        if (id is String) conversationId = id;
        notifyListeners();
      case 'error':
        _error = message['message'] as String?;
        notifyListeners();
    }
  }

  void _addTranscript(String role, String text) {
    if (text.isEmpty) return;
    final last = _lines.isEmpty ? null : _lines.last;
    final continues =
        last != null &&
        last.role == role &&
        (role == 'user' || _assistantTurnOpen);
    if (continues) {
      last.text = _tidy(last.text + text);
    } else {
      _lines.add(LiveLine(role, _tidy(text)));
    }
    if (role == 'assistant') _assistantTurnOpen = true;
    // Keep the caption short; the full call is saved to chat history.
    if (_lines.length > 30) _lines.removeRange(0, _lines.length - 30);
    notifyListeners();
  }

  static String _tidy(String text) => text.replaceAll(RegExp(r'\s+'), ' ');

  void _onPlaybackIdle() {
    if (_status == LiveStatus.speaking) _set(LiveStatus.listening);
  }

  void _onClosed(int? code, String? reason) {
    if (_closing) return;
    _stopAudio();
    if (code == null || code == 1000) {
      _set(LiveStatus.ended);
    } else {
      _fail(
        reason?.isNotEmpty == true ? reason! : 'The call with Liyana dropped.',
      );
    }
  }

  void toggleMute() {
    _muted = !_muted;
    notifyListeners();
  }

  /// Type instead of talking (e.g. in a quiet place).
  void sendText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'text', 'text': trimmed}));
  }

  Future<void> end() async {
    if (_closing) return;
    _closing = true;
    try {
      _channel?.sink.add(jsonEncode({'type': 'end'}));
    } catch (_) {}
    await _stopAudio();
    await _closeSocket();
    if (_status != LiveStatus.failed) _set(LiveStatus.ended);
  }

  Future<void> _stopAudio() async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _audio.stopMic();
      await _audio.stopPlayer();
    } catch (_) {}
  }

  Future<void> _closeSocket() async {
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _fail(String message) {
    _error = message;
    _set(LiveStatus.failed);
  }

  void _set(LiveStatus status) {
    _status = status;
    notifyListeners();
  }

  static Map<String, dynamic> _decode(String data) {
    try {
      final value = jsonDecode(data);
      return value is Map<String, dynamic> ? value : const {};
    } catch (_) {
      return const {};
    }
  }

  @override
  void dispose() {
    end();
    super.dispose();
  }
}

enum _OpenResult { ready, unauthorized, failed }
