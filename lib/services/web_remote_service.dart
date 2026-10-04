import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Actions supported by the Web Remote controller.
enum WebRemoteAction {
  up,
  down,
  left,
  right,
  select,
  back,
  home,
  playPause,
  rewind,
  fastForward,
  volumeUp,
  volumeDown,
  mute,
}

/// Service that hosts an embedded local HTTP server providing a zero-install
/// mobile web companion remote for Android TV and Desktop.
class WebRemoteService extends ChangeNotifier {
  static final WebRemoteService _instance = WebRemoteService._internal();
  factory WebRemoteService() => _instance;
  WebRemoteService._internal();

  static const int defaultPort = 8089;

  HttpServer? _server;
  int _port = defaultPort;
  String? _localIp;
  bool _isRunning = false;
  int _commandCount = 0;

  final StreamController<WebRemoteAction> _actionController =
      StreamController<WebRemoteAction>.broadcast();
  final StreamController<String> _textController =
      StreamController<String>.broadcast();

  bool get isRunning => _isRunning;
  int get port => _port;
  String? get localIp => _localIp;
  String get remoteUrl =>
      _localIp != null ? 'http://$_localIp:$_port' : 'http://localhost:$_port';
  int get commandCount => _commandCount;

  Stream<WebRemoteAction> get onAction => _actionController.stream;
  Stream<String> get onText => _textController.stream;

  @visibleForTesting
  void resetForTesting() {
    _commandCount = 0;
  }

  /// Starts the web remote HTTP server.
  Future<bool> startServer({int port = defaultPort}) async {
    if (_isRunning && _server != null) return true;

    _port = port;
    try {
      _localIp = await _detectLocalIp();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;
      notifyListeners();

      _server!.listen(
        _handleRequest,
        onError: (err) {
          debugPrint('[WebRemoteService] Server error: $err');
          _isRunning = false;
          notifyListeners();
        },
        onDone: () {
          _isRunning = false;
          notifyListeners();
        },
      );

      debugPrint('[WebRemoteService] Running at $remoteUrl');
      return true;
    } catch (e) {
      debugPrint('[WebRemoteService] Failed to start server: $e');
      _isRunning = false;
      notifyListeners();
      return false;
    }
  }

  /// Stops the web remote HTTP server.
  Future<void> stopServer() async {
    if (!_isRunning) return;
    try {
      await _server?.close(force: true);
    } catch (e) {
      debugPrint('[WebRemoteService] Error stopping server: $e');
    } finally {
      _server = null;
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Toggle server state on or off.
  Future<bool> toggleServer() async {
    if (_isRunning) {
      await stopServer();
      return false;
    } else {
      return await startServer();
    }
  }

  /// Dispatches an action programmatically and simulates native TV key event.
  void dispatchAction(WebRemoteAction action) {
    _commandCount++;
    _actionController.add(action);
    _simulateKeyEvent(action);
    notifyListeners();
  }

  /// Dispatches text input to the active app.
  void dispatchText(String text) {
    _commandCount++;
    _textController.add(text);
    notifyListeners();
  }

  void _simulateKeyEvent(WebRemoteAction action) {
    LogicalKeyboardKey? key;
    PhysicalKeyboardKey? physicalKey;

    switch (action) {
      case WebRemoteAction.up:
        key = LogicalKeyboardKey.arrowUp;
        physicalKey = PhysicalKeyboardKey.arrowUp;
        break;
      case WebRemoteAction.down:
        key = LogicalKeyboardKey.arrowDown;
        physicalKey = PhysicalKeyboardKey.arrowDown;
        break;
      case WebRemoteAction.left:
        key = LogicalKeyboardKey.arrowLeft;
        physicalKey = PhysicalKeyboardKey.arrowLeft;
        break;
      case WebRemoteAction.right:
        key = LogicalKeyboardKey.arrowRight;
        physicalKey = PhysicalKeyboardKey.arrowRight;
        break;
      case WebRemoteAction.select:
        key = LogicalKeyboardKey.select;
        physicalKey = PhysicalKeyboardKey.enter;
        break;
      case WebRemoteAction.back:
        key = LogicalKeyboardKey.escape;
        physicalKey = PhysicalKeyboardKey.escape;
        break;
      case WebRemoteAction.home:
        key = LogicalKeyboardKey.home;
        physicalKey = PhysicalKeyboardKey.home;
        break;
      case WebRemoteAction.playPause:
        key = LogicalKeyboardKey.mediaPlayPause;
        physicalKey = PhysicalKeyboardKey.mediaPlayPause;
        break;
      case WebRemoteAction.rewind:
        key = LogicalKeyboardKey.mediaRewind;
        physicalKey = PhysicalKeyboardKey.mediaRewind;
        break;
      case WebRemoteAction.fastForward:
        key = LogicalKeyboardKey.mediaFastForward;
        physicalKey = PhysicalKeyboardKey.mediaFastForward;
        break;
      case WebRemoteAction.volumeUp:
        key = LogicalKeyboardKey.audioVolumeUp;
        physicalKey = PhysicalKeyboardKey.audioVolumeUp;
        break;
      case WebRemoteAction.volumeDown:
        key = LogicalKeyboardKey.audioVolumeDown;
        physicalKey = PhysicalKeyboardKey.audioVolumeDown;
        break;
      case WebRemoteAction.mute:
        key = LogicalKeyboardKey.audioVolumeMute;
        physicalKey = PhysicalKeyboardKey.audioVolumeMute;
        break;
    }

    try {
      final now = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);
      ServicesBinding.instance.keyEventManager.handleKeyData(
        ui.KeyData(
          timeStamp: now,
          type: ui.KeyEventType.down,
          physical: physicalKey.usbHidUsage,
          logical: key.keyId,
          character: null,
          synthesized: true,
        ),
      );
      ServicesBinding.instance.keyEventManager.handleKeyData(
        ui.KeyData(
          timeStamp: now + const Duration(milliseconds: 30),
          type: ui.KeyEventType.up,
          physical: physicalKey.usbHidUsage,
          logical: key.keyId,
          character: null,
          synthesized: true,
        ),
      );
    } catch (e) {
      debugPrint('[WebRemoteService] Key injection error: $e');
    }
  }

  Future<String?> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Add CORS headers for cross-origin local requests
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    if (request.method == 'GET' && (path == '/' || path == '/index.html')) {
      request.response.headers.contentType = ContentType.html;
      request.response.write(_generateHtmlUi());
      await request.response.close();
      return;
    }

    if (request.method == 'GET' && path == '/api/status') {
      request.response.headers.contentType = ContentType.json;
      final payload = jsonEncode({
        'status': 'online',
        'device': 'Exalere TV',
        'commandsReceived': _commandCount,
      });
      request.response.write(payload);
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && path == '/api/action') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final actionName = json['action'] as String?;

        if (actionName != null) {
          final action = WebRemoteAction.values.firstWhere(
            (a) => a.name == actionName,
            orElse: () => WebRemoteAction.select,
          );
          dispatchAction(action);
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({'success': true, 'action': action.name}),
          );
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write(
            jsonEncode({'error': 'Missing action parameter'}),
          );
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': e.toString()}));
      }
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && path == '/api/text') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final text = json['text'] as String?;

        if (text != null && text.isNotEmpty) {
          dispatchText(text);
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'success': true, 'text': text}));
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write(
            jsonEncode({'error': 'Missing text parameter'}),
          );
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': e.toString()}));
      }
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not Found');
    await request.response.close();
  }

  String _generateHtmlUi() {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Exalere TV Remote</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
    body {
      background: #0f1015;
      color: #f1f5f9;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      min-height: 100vh;
      padding: 16px 12px;
      user-select: none;
    }
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      width: 100%;
      max-width: 380px;
      margin-bottom: 20px;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 20px;
      font-weight: 800;
      letter-spacing: 0.5px;
      background: linear-gradient(135deg, #6366f1, #a855f7);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .status-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      background: rgba(34, 197, 94, 0.15);
      color: #4ade80;
      border: 1px solid rgba(34, 197, 94, 0.3);
      padding: 4px 10px;
      border-radius: 999px;
      font-size: 12px;
      font-weight: 600;
    }
    .status-dot {
      width: 8px;
      height: 8px;
      background: #22c55e;
      border-radius: 50%;
      box-shadow: 0 0 8px #22c55e;
    }
    .remote-card {
      width: 100%;
      max-width: 380px;
      background: #181924;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 28px;
      padding: 24px 20px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 22px;
      box-shadow: 0 16px 40px rgba(0, 0, 0, 0.6);
    }
    /* D-PAD */
    .dpad-container {
      position: relative;
      width: 220px;
      height: 220px;
      background: #12131c;
      border-radius: 50%;
      border: 2px solid rgba(99, 102, 241, 0.25);
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: inset 0 4px 12px rgba(0, 0, 0, 0.6), 0 8px 24px rgba(0, 0, 0, 0.4);
    }
    .dpad-btn {
      position: absolute;
      background: transparent;
      border: none;
      color: #94a3b8;
      font-size: 24px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.1s ease;
      touch-action: manipulation;
    }
    .dpad-btn:active {
      color: #6366f1;
      transform: scale(0.9);
    }
    .dpad-up { top: 12px; left: 50%; transform: translateX(-50%); width: 70px; height: 50px; }
    .dpad-down { bottom: 12px; left: 50%; transform: translateX(-50%); width: 70px; height: 50px; }
    .dpad-left { left: 12px; top: 50%; transform: translateY(-50%); width: 50px; height: 70px; }
    .dpad-right { right: 12px; top: 50%; transform: translateY(-50%); width: 50px; height: 70px; }
    .dpad-center {
      width: 84px;
      height: 84px;
      background: linear-gradient(135deg, #4f46e5, #7c3aed);
      border-radius: 50%;
      border: 2px solid rgba(255, 255, 255, 0.15);
      color: #ffffff;
      font-weight: 700;
      font-size: 15px;
      cursor: pointer;
      box-shadow: 0 6px 18px rgba(99, 102, 241, 0.4);
      transition: transform 0.1s;
    }
    .dpad-center:active {
      transform: scale(0.92);
      box-shadow: 0 2px 8px rgba(99, 102, 241, 0.6);
    }
    /* ACTION ROW */
    .action-row {
      display: flex;
      justify-content: space-between;
      width: 100%;
      gap: 12px;
    }
    .btn-pill {
      flex: 1;
      height: 48px;
      background: #232535;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 14px;
      color: #cbd5e1;
      font-size: 14px;
      font-weight: 600;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      cursor: pointer;
      transition: all 0.12s;
    }
    .btn-pill:active {
      background: #31344c;
      transform: scale(0.96);
    }
    /* MEDIA CONTROLS */
    .media-grid {
      display: grid;
      grid-template-columns: repeat(5, 1fr);
      gap: 8px;
      width: 100%;
    }
    .btn-media {
      height: 44px;
      background: #232535;
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 12px;
      color: #94a3b8;
      font-size: 16px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.1s;
    }
    .btn-media:active {
      background: #6366f1;
      color: #fff;
      transform: scale(0.94);
    }
    /* TEXT INPUT BOX */
    .text-card {
      width: 100%;
      max-width: 380px;
      margin-top: 14px;
      background: #181924;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 20px;
      padding: 16px;
      display: flex;
      gap: 10px;
    }
    .text-input {
      flex: 1;
      background: #12131c;
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 12px;
      padding: 10px 14px;
      color: #f8fafc;
      font-size: 14px;
      outline: none;
    }
    .text-input:focus {
      border-color: #6366f1;
    }
    .btn-send {
      background: #6366f1;
      border: none;
      border-radius: 12px;
      color: #fff;
      padding: 0 16px;
      font-weight: 600;
      font-size: 14px;
      cursor: pointer;
      transition: transform 0.1s;
    }
    .btn-send:active {
      transform: scale(0.95);
    }
  </style>
</head>
<body>
  <div class="header">
    <div class="brand">
      <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor">
        <path d="M21 3H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 1.99-.9 1.99-2L23 5c0-1.1-.9-2-2-2zm0 14H3V5h18v12z"/>
      </svg>
      Exalere TV
    </div>
    <div class="status-badge">
      <div class="status-dot"></div>
      Connected
    </div>
  </div>

  <div class="remote-card">
    <div class="action-row">
      <button class="btn-pill" onclick="sendAction('back')">↩ Back</button>
      <button class="btn-pill" onclick="sendAction('home')">🏠 Home</button>
      <button class="btn-pill" onclick="sendAction('mute')">🔇 Mute</button>
    </div>

    <!-- D-PAD -->
    <div class="dpad-container">
      <button class="dpad-btn dpad-up" onclick="sendAction('up')">▲</button>
      <button class="dpad-btn dpad-left" onclick="sendAction('left')">◀</button>
      <button class="dpad-center" onclick="sendAction('select')">OK</button>
      <button class="dpad-btn dpad-right" onclick="sendAction('right')">▶</button>
      <button class="dpad-btn dpad-down" onclick="sendAction('down')">▼</button>
    </div>

    <!-- MEDIA CONTROLS -->
    <div class="media-grid">
      <button class="btn-media" onclick="sendAction('rewind')" title="Rewind 10s">⏪</button>
      <button class="btn-media" onclick="sendAction('playPause')" title="Play/Pause">⏯</button>
      <button class="btn-media" onclick="sendAction('fastForward')" title="Forward 10s">⏩</button>
      <button class="btn-media" onclick="sendAction('volumeDown')" title="Volume Down">🔉</button>
      <button class="btn-media" onclick="sendAction('volumeUp')" title="Volume Up">🔊</button>
    </div>
  </div>

  <!-- DIRECT KEYBOARD INPUT -->
  <div class="text-card">
    <input type="text" id="keyboardInput" class="text-input" placeholder="Type text to send to TV..." autocomplete="off">
    <button class="btn-send" onclick="sendText()">Send</button>
  </div>

  <script>
    function sendAction(action) {
      if (navigator.vibrate) navigator.vibrate(18);
      fetch('/api/action', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: action })
      }).catch(err => console.error(err));
    }

    function sendText() {
      const input = document.getElementById('keyboardInput');
      const val = input.value.trim();
      if (!val) return;
      if (navigator.vibrate) navigator.vibrate(25);
      fetch('/api/text', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: val })
      }).then(() => {
        input.value = '';
      }).catch(err => console.error(err));
    }

    document.getElementById('keyboardInput').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        sendText();
      }
    });
  </script>
</body>
</html>''';
  }

  @override
  void dispose() {
    stopServer();
    _actionController.close();
    _textController.close();
    super.dispose();
  }
}
