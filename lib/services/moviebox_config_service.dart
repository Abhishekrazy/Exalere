import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MovieBoxConfig {
  final List<String> hostPool;
  final String secretKey;
  final String packageName;
  final String versionName;
  final String spCode;
  final List<int> versionCodes;
  final int lastSyncTimestamp;
  final String lastSyncStatus;

  const MovieBoxConfig({
    required this.hostPool,
    required this.secretKey,
    required this.packageName,
    required this.versionName,
    required this.spCode,
    required this.versionCodes,
    required this.lastSyncTimestamp,
    required this.lastSyncStatus,
  });

  Map<String, dynamic> toJson() => {
    'hostPool': hostPool,
    'secretKey': secretKey,
    'packageName': packageName,
    'versionName': versionName,
    'spCode': spCode,
    'versionCodes': versionCodes,
    'lastSyncTimestamp': lastSyncTimestamp,
    'lastSyncStatus': lastSyncStatus,
  };

  factory MovieBoxConfig.fromJson(Map<String, dynamic> json) {
    return MovieBoxConfig(
      hostPool: (json['hostPool'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.startsWith('http'))
              .toList() ??
          MovieBoxConfigService.defaultHostPool,
      secretKey: json['secretKey']?.toString() ??
          MovieBoxConfigService.defaultSecretKey,
      packageName: json['packageName']?.toString() ??
          MovieBoxConfigService.defaultPackageName,
      versionName: json['versionName']?.toString() ??
          MovieBoxConfigService.defaultVersionName,
      spCode: json['spCode']?.toString() ?? MovieBoxConfigService.defaultSpCode,
      versionCodes: (json['versionCodes'] as List<dynamic>?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .where((c) => c > 0)
              .toList() ??
          MovieBoxConfigService.defaultVersionCodes,
      lastSyncTimestamp: (json['lastSyncTimestamp'] as num?)?.toInt() ?? 0,
      lastSyncStatus: json['lastSyncStatus']?.toString() ?? 'Uninitialized',
    );
  }

  MovieBoxConfig copyWith({
    List<String>? hostPool,
    String? secretKey,
    String? packageName,
    String? versionName,
    String? spCode,
    List<int>? versionCodes,
    int? lastSyncTimestamp,
    String? lastSyncStatus,
  }) {
    return MovieBoxConfig(
      hostPool: hostPool ?? this.hostPool,
      secretKey: secretKey ?? this.secretKey,
      packageName: packageName ?? this.packageName,
      versionName: versionName ?? this.versionName,
      spCode: spCode ?? this.spCode,
      versionCodes: versionCodes ?? this.versionCodes,
      lastSyncTimestamp: lastSyncTimestamp ?? this.lastSyncTimestamp,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
    );
  }
}

/// Service that dynamically syncs API endpoints and signing keys
/// directly from https://github.com/mesamirh/MovieBox-TUI
class MovieBoxConfigService {
  static final MovieBoxConfigService _instance = MovieBoxConfigService._internal();
  factory MovieBoxConfigService() => _instance;

  static const String upstreamRepo = 'mesamirh/MovieBox-TUI';
  static const String upstreamBranch = 'main';
  static const String upstreamFallbackBranch = 'master';

  static const List<String> defaultHostPool = [
    'https://api6.aoneroom.com',
    'https://api5.aoneroom.com',
    'https://api4.aoneroom.com',
    'https://api4sg.aoneroom.com',
    'https://api3.aoneroom.com',
    'https://api6sg.aoneroom.com',
    'https://api.inmoviebox.com',
  ];

  static const String defaultSecretKey = '76iRl07s0xSN9jqmEWAt79EBJZulIQIsV64FZr2O';
  static const String defaultPackageName = 'com.community.oneroom';
  static const String defaultVersionName = '4.0.01.0813.03';
  static const String defaultSpCode = '40401';
  static const List<int> defaultVersionCodes = [
    50020117,
    50020118,
    50020119,
    50020120,
    50020121,
  ];

  static const String _prefKey = 'moviebox_upstream_config';

  final http.Client _client = http.Client();
  MovieBoxConfig _config = const MovieBoxConfig(
    hostPool: defaultHostPool,
    secretKey: defaultSecretKey,
    packageName: defaultPackageName,
    versionName: defaultVersionName,
    spCode: defaultSpCode,
    versionCodes: defaultVersionCodes,
    lastSyncTimestamp: 0,
    lastSyncStatus: 'Initialized with defaults',
  );

  bool _initialized = false;
  Completer<bool>? _syncCompleter;

  MovieBoxConfigService._internal();

  MovieBoxConfig get config => _config;
  List<String> get hostPool => _config.hostPool;
  String get secretKey => _config.secretKey;
  String get packageName => _config.packageName;
  String get versionName => _config.versionName;
  String get spCode => _config.spCode;
  List<int> get versionCodes => _config.versionCodes;
  int get lastSyncTimestamp => _config.lastSyncTimestamp;
  String get lastSyncStatus => _config.lastSyncStatus;

  /// Load persisted configuration from SharedPreferences and trigger background refresh if stale
  Future<void> init() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _config = MovieBoxConfig.fromJson(decoded);
          debugPrint('MovieBoxConfigService loaded cached config: ${_config.hostPool.length} hosts');
        }
      }
    } catch (e) {
      debugPrint('MovieBoxConfigService init cache load error: $e');
    }

    _initialized = true;

    // Check if background sync is needed (e.g. older than 6 hours or never synced)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sixHoursMs = 6 * 60 * 60 * 1000;
    if (nowMs - _config.lastSyncTimestamp > sixHoursMs) {
      unawaited(syncFromUpstream());
    }
  }

  /// Sync configuration from GitHub upstream repository
  Future<bool> syncFromUpstream({bool force = false}) async {
    if (_syncCompleter != null) {
      return _syncCompleter!.future;
    }

    _syncCompleter = Completer<bool>();

    try {
      debugPrint('Syncing MovieBox API endpoints from $upstreamRepo...');

      // 1. Fetch client.rs
      String? clientCode = await _fetchRawFile('src/providers/moviebox/client.rs', upstreamBranch);
      if (clientCode == null || clientCode.isEmpty) {
        clientCode = await _fetchRawFile('src/providers/moviebox/client.rs', upstreamFallbackBranch);
      }

      // 2. Fetch crypto.rs
      String? cryptoCode = await _fetchRawFile('src/providers/moviebox/crypto.rs', upstreamBranch);
      if (cryptoCode == null || cryptoCode.isEmpty) {
        cryptoCode = await _fetchRawFile('src/providers/moviebox/crypto.rs', upstreamFallbackBranch);
      }

      if (clientCode == null && cryptoCode == null) {
        throw Exception('Failed to download source files from upstream repository.');
      }

      // 3. Parse components
      List<String> parsedHosts = clientCode != null ? parseHostPool(clientCode) : [];
      String? parsedSecret = cryptoCode != null ? parseSecretKey(cryptoCode) : null;
      final parsedInfo = cryptoCode != null ? parseClientInfo(cryptoCode) : null;

      final updatedHosts = parsedHosts.isNotEmpty ? parsedHosts : _config.hostPool;
      final updatedSecret = (parsedSecret != null && parsedSecret.length >= 16)
          ? parsedSecret
          : _config.secretKey;
      final updatedPkg = parsedInfo?['packageName']?.toString() ?? _config.packageName;
      final updatedVer = parsedInfo?['versionName']?.toString() ?? _config.versionName;
      final updatedSp = parsedInfo?['spCode']?.toString() ?? _config.spCode;
      final updatedCodes = (parsedInfo?['versionCodes'] as List<int>?) ?? _config.versionCodes;

      final now = DateTime.now().millisecondsSinceEpoch;
      final statusMessage = 'Synced ${updatedHosts.length} hosts from $upstreamRepo';

      _config = MovieBoxConfig(
        hostPool: updatedHosts,
        secretKey: updatedSecret,
        packageName: updatedPkg,
        versionName: updatedVer,
        spCode: updatedSp,
        versionCodes: updatedCodes,
        lastSyncTimestamp: now,
        lastSyncStatus: statusMessage,
      );

      // Persist to disk
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_config.toJson()));

      debugPrint('MovieBoxConfigService successfully updated: $statusMessage');
      _syncCompleter!.complete(true);
      return true;
    } catch (e) {
      debugPrint('MovieBoxConfigService sync failed: $e');
      _config = _config.copyWith(
        lastSyncStatus: 'Sync failed: $e',
      );
      _syncCompleter!.complete(false);
      return false;
    } finally {
      _syncCompleter = null;
    }
  }

  /// Download raw file from GitHub with timeout
  Future<String?> _fetchRawFile(String path, String branch) async {
    final url = 'https://raw.githubusercontent.com/$upstreamRepo/$branch/$path';
    try {
      final resp = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Exalere-Flutter/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
        return resp.body;
      }
    } catch (e) {
      debugPrint('Fetch raw file error for $url: $e');
    }
    return null;
  }

  /// Parse HOST_POOL array from Rust client.rs source
  static List<String> parseHostPool(String source) {
    try {
      final hostPoolRegex = RegExp(
        r'const\s+HOST_POOL\s*:\s*&\[&str\]\s*=\s*&\[([\s\S]*?)\];',
      );
      final match = hostPoolRegex.firstMatch(source);
      if (match != null && match.groupCount >= 1) {
        final content = match.group(1)!;
        final urlRegex = RegExp(r'"(https?://[^"]+)"');
        final hosts = <String>[];
        for (final m in urlRegex.allMatches(content)) {
          final url = m.group(1)!.trim();
          if (url.startsWith('http') && !hosts.contains(url)) {
            hosts.add(url);
          }
        }
        if (hosts.isNotEmpty) {
          return hosts;
        }
      }
    } catch (e) {
      debugPrint('Error parsing HOST_POOL: $e');
    }
    return [];
  }

  /// Parse SECRET_KEY_DEFAULT from Rust crypto.rs source
  static String? parseSecretKey(String source) {
    try {
      final secretRegex = RegExp(
        r'const\s+SECRET_KEY_DEFAULT\s*:\s*&str\s*=\s*"([^"]+)";',
      );
      final match = secretRegex.firstMatch(source);
      if (match != null && match.groupCount >= 1) {
        final secret = match.group(1)!.trim();
        if (secret.length >= 16) {
          return secret;
        }
      }
    } catch (e) {
      debugPrint('Error parsing SECRET_KEY_DEFAULT: $e');
    }
    return null;
  }

  /// Parse package_name, version_name, sp_code, version_codes from crypto.rs
  static Map<String, dynamic> parseClientInfo(String source) {
    final result = <String, dynamic>{};

    try {
      final pkgMatch = RegExp(r'"package_name"\s*:\s*"([^"]+)"').firstMatch(source);
      if (pkgMatch != null) result['packageName'] = pkgMatch.group(1);

      final verMatch = RegExp(r'"version_name"\s*:\s*"([^"]+)"').firstMatch(source);
      if (verMatch != null) result['versionName'] = verMatch.group(1);

      final spMatch = RegExp(r'"sp_code"\s*:\s*"([^"]+)"').firstMatch(source);
      if (spMatch != null) result['spCode'] = spMatch.group(1);

      final codesMatch = RegExp(r'version_codes\s*=\s*\[([\s\S]*?)\];').firstMatch(source);
      if (codesMatch != null) {
        final nums = RegExp(r'\b([0-9]{6,})\b')
            .allMatches(codesMatch.group(1)!)
            .map((m) => int.tryParse(m.group(1)!) ?? 0)
            .where((n) => n > 0)
            .toList();
        if (nums.isNotEmpty) {
          result['versionCodes'] = nums;
        }
      }
    } catch (e) {
      debugPrint('Error parsing client info: $e');
    }

    return result;
  }
}
