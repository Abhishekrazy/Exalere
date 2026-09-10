import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalPlayerService {
  static final ExternalPlayerService _instance = ExternalPlayerService._internal();
  factory ExternalPlayerService() => _instance;
  ExternalPlayerService._internal();

  /// Check which desktop players are installed
  Future<List<String>> detectPlayers() async {
    final List<String> detected = [];

    if (Platform.isWindows) {
      if (await _findMpvPath() != null) detected.add('MPV');
      if (await _findVlcPath() != null) detected.add('VLC');
    } else if (Platform.isMacOS) {
      if (await File('/Applications/IINA.app/Contents/MacOS/iina-cli').exists() ||
          await File('/Applications/IINA.app').exists()) {
        detected.add('IINA');
      }
      if (await File('/Applications/VLC.app').exists()) detected.add('VLC');
    } else if (Platform.isLinux) {
      if (await _isInPath('mpv')) detected.add('MPV');
      if (await _isInPath('vlc')) detected.add('VLC');
    }

    return detected;
  }

  /// Launch external player (MPV, VLC, or System default) with custom streaming headers
  Future<bool> launch({
    required String url,
    String? title,
    Map<String, String>? headers,
    String? preferredPlayer,
    int? startSeconds,
  }) async {
    try {
      if (Platform.isWindows) {
        return await _launchWindows(
          url: url,
          title: title,
          headers: headers,
          preferred: preferredPlayer,
          startSeconds: startSeconds,
        );
      } else if (Platform.isMacOS) {
        return await _launchMacOS(
          url: url,
          title: title,
          headers: headers,
          startSeconds: startSeconds,
        );
      } else if (Platform.isLinux) {
        return await _launchLinux(
          url: url,
          title: title,
          headers: headers,
          startSeconds: startSeconds,
        );
      }
    } catch (e) {
      debugPrint('External player process launch failed: $e');
    }

    // Fallback: system URL launcher
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  Future<bool> _launchWindows({
    required String url,
    String? title,
    Map<String, String>? headers,
    String? preferred,
    int? startSeconds,
  }) async {
    final mpvPath = await _findMpvPath();
    final vlcPath = await _findVlcPath();

    // Preference: user preferred or prioritize MPV (smoother DASH/HLS) then VLC
    final useMpv = (preferred?.toLowerCase() == 'mpv' && mpvPath != null) ||
        (mpvPath != null && preferred?.toLowerCase() != 'vlc') ||
        (vlcPath == null && mpvPath != null);

    if (useMpv) {
      final List<String> args = [
        '--idle=no',
        '--keep-open=no',
        '--force-window=yes',
      ];

      if (title != null && title.isNotEmpty) {
        args.add('--title=Exalere - $title');
      }

      if (headers != null && headers.isNotEmpty) {
        final List<String> headerFields = [];
        for (final entry in headers.entries) {
          final k = entry.key.toLowerCase();
          if (k == 'user-agent') {
            args.add('--user-agent=${entry.value}');
          } else if (k == 'referer') {
            args.add('--referrer=${entry.value}');
          } else {
            headerFields.add('${entry.key}: ${entry.value}');
          }
        }
        if (headerFields.isNotEmpty) {
          args.add('--http-header-fields=${headerFields.join(",")}');
        }
      }

      if (startSeconds != null && startSeconds > 0) {
        args.add('--start=$startSeconds');
      }

      args.add(url);
      debugPrint('Launching MPV: $mpvPath ${args.join(" ")}');
      await Process.start(mpvPath, args, mode: ProcessStartMode.detached);
      return true;
    }

    if (vlcPath != null) {
      final List<String> args = [
        '--http-forward-cookies',
      ];
      if (title != null && title.isNotEmpty) {
        args.add('--meta-title=Exalere - $title');
      }

      String? cookieVal;
      String? uaVal;
      String? refVal;

      if (headers != null && headers.isNotEmpty) {
        for (final entry in headers.entries) {
          final k = entry.key.toLowerCase();
          if (k == 'user-agent') {
            uaVal = entry.value;
          } else if (k == 'referer') {
            refVal = entry.value;
          } else if (k == 'cookie') {
            cookieVal = entry.value;
          }
        }
      }

      if (uaVal != null) {
        args.add('--http-user-agent=$uaVal');
      }
      if (refVal != null) {
        args.add('--http-referrer=$refVal');
      }
      if (cookieVal != null) {
        args.add('--http-cookie=$cookieVal');
      }

      if (startSeconds != null && startSeconds > 0) {
        args.add('--start-time=$startSeconds');
      }

      args.add(url);

      // Also append per-MRL options for maximum VLC compatibility
      if (uaVal != null) args.add(':http-user-agent=$uaVal');
      if (refVal != null) args.add(':http-referrer=$refVal');
      if (cookieVal != null) args.add(':http-cookie=$cookieVal');
      if (startSeconds != null && startSeconds > 0) args.add(':start-time=$startSeconds');

      debugPrint('Launching VLC: $vlcPath ${args.join(" ")}');
      await Process.start(vlcPath, args, mode: ProcessStartMode.detached);
      return true;
    }

    // Default to system browser/app
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  Future<bool> _launchMacOS({
    required String url,
    String? title,
    Map<String, String>? headers,
    int? startSeconds,
  }) async {
    const iinaCli = '/Applications/IINA.app/Contents/MacOS/iina-cli';
    if (await File(iinaCli).exists()) {
      final List<String> args = [];
      if (headers != null && headers.isNotEmpty) {
        final List<String> fields = [];
        for (final entry in headers.entries) {
          final k = entry.key.toLowerCase();
          if (k == 'user-agent') {
            args.add('--mpv-user-agent=${entry.value}');
          } else if (k == 'referer') {
            args.add('--mpv-referrer=${entry.value}');
          } else {
            fields.add('${entry.key}: ${entry.value}');
          }
        }
        if (fields.isNotEmpty) {
          args.add('--mpv-http-header-fields=${fields.join(",")}');
        }
      }
      if (startSeconds != null && startSeconds > 0) {
        args.add('--mpv-start=$startSeconds');
      }
      args.add(url);
      await Process.start(iinaCli, args, mode: ProcessStartMode.detached);
      return true;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  Future<bool> _launchLinux({
    required String url,
    String? title,
    Map<String, String>? headers,
    int? startSeconds,
  }) async {
    final hasMpv = await _isInPath('mpv');
    if (hasMpv) {
      final List<String> args = ['--idle=no', '--keep-open=no'];
      if (headers != null) {
        for (final entry in headers.entries) {
          final k = entry.key.toLowerCase();
          if (k == 'user-agent') args.add('--user-agent=${entry.value}');
          if (k == 'referer') args.add('--referrer=${entry.value}');
        }
      }
      if (startSeconds != null && startSeconds > 0) {
        args.add('--start=$startSeconds');
      }
      args.add(url);
      await Process.start('mpv', args, mode: ProcessStartMode.detached);
      return true;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  Future<String?> _findMpvPath() async {
    const candidates = [
      r'C:\Program Files\MPV Player\mpv.exe',
      r'C:\Program Files\mpv\mpv.exe',
      r'C:\Program Files (x86)\MPV Player\mpv.exe',
      r'C:\Program Files (x86)\mpv\mpv.exe',
    ];
    for (final p in candidates) {
      if (await File(p).exists()) return p;
    }
    if (await _isInPath('mpv.exe') || await _isInPath('mpv')) {
      return 'mpv.exe';
    }
    return null;
  }

  Future<String?> _findVlcPath() async {
    const candidates = [
      r'C:\Program Files\VideoLAN\VLC\vlc.exe',
      r'C:\Program Files (x86)\VideoLAN\VLC\vlc.exe',
    ];
    for (final p in candidates) {
      if (await File(p).exists()) return p;
    }
    if (await _isInPath('vlc.exe') || await _isInPath('vlc')) {
      return 'vlc.exe';
    }
    return null;
  }

  Future<bool> _isInPath(String exe) async {
    try {
      final cmd = Platform.isWindows ? 'where.exe' : 'which';
      final result = await Process.run(cmd, [exe]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
