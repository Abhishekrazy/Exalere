/// DNS-over-HTTPS resolvers the user can pick.
///
/// These matter together with anti-DPI: if the ISP interferes with plaintext DNS,
/// resolving the hostname over HTTPS is the half of the problem a fragmented
/// connection cannot fix on its own.
enum DohProvider {
  cloudflare,
  google,
  adguard,
  custom,
  off;

  String get label {
    switch (this) {
      case DohProvider.cloudflare:
        return 'Cloudflare (1.1.1.1)';
      case DohProvider.google:
        return 'Google (8.8.8.8)';
      case DohProvider.adguard:
        return 'AdGuard';
      case DohProvider.custom:
        return 'Custom';
      case DohProvider.off:
        return 'Off';
    }
  }

  /// Endpoint used to resolve names. `null` when this provider needs a custom URL
  /// or is disabled.
  String? get endpoint {
    switch (this) {
      case DohProvider.cloudflare:
        return 'https://cloudflare-dns.com/dns-query';
      case DohProvider.google:
        return 'https://dns.google/dns-query';
      case DohProvider.adguard:
        return 'https://dns.adguard-dns.com/dns-query';
      case DohProvider.custom:
      case DohProvider.off:
        return null;
    }
  }

  static DohProvider fromName(String? raw) {
    for (final provider in DohProvider.values) {
      if (provider.name == raw) return provider;
    }
    return DohProvider.cloudflare;
  }
}

/// How aggressively the anti-DPI proxy fragments a TLS handshake.
///
/// A TLS ClientHello carries the destination hostname in the clear, which is what
/// DPI boxes match on. Splitting it into small writes — with a pause between them
/// — usually defeats that inspection without breaking the handshake itself,
/// because TLS is a byte stream and the peer reassembles it.
class AntiDpiProfile {
  const AntiDpiProfile({
    required this.label,
    required this.chunkSize,
    required this.chunkDelayMs,
    required this.description,
  });

  final String label;

  /// Bytes written per fragment.
  final int chunkSize;

  /// Pause between fragments.
  final int chunkDelayMs;

  final String description;

  static const AntiDpiProfile light = AntiDpiProfile(
    label: 'Light',
    chunkSize: 64,
    chunkDelayMs: 2,
    description: 'Fewer, larger fragments. Least likely to disturb a server.',
  );

  static const AntiDpiProfile balanced = AntiDpiProfile(
    label: 'Balanced',
    chunkSize: 24,
    chunkDelayMs: 5,
    description: 'A good default: enough splitting to defeat most DPI.',
  );

  static const AntiDpiProfile aggressive = AntiDpiProfile(
    label: 'Aggressive',
    chunkSize: 8,
    chunkDelayMs: 12,
    description:
        'Maximum splitting. Use when Balanced is still blocked; may slow '
        'the initial connection.',
  );

  static const List<AntiDpiProfile> all = [light, balanced, aggressive];

  static AntiDpiProfile byLabel(String? label) {
    for (final profile in all) {
      if (profile.label == label) return profile;
    }
    return balanced;
  }
}

/// Persisted network-bypass preferences.
class NetworkProxySettings {
  const NetworkProxySettings({
    this.warpEnabled = false,
    this.antiDpiEnabled = false,
    this.antiDpiPort = 0,
    this.antiDpiProfileLabel = 'Balanced',
    this.dohProvider = DohProvider.cloudflare,
    this.customDohUrl = '',
  });

  /// Cloudflare WARP full-tunnel VPN. Requires the native tunnel module; when
  /// that is absent the UI reports it unavailable rather than pretending.
  final bool warpEnabled;

  final bool antiDpiEnabled;

  /// Port the local anti-DPI proxy listens on. `0` means "pick one at start".
  final int antiDpiPort;

  final String antiDpiProfileLabel;

  final DohProvider dohProvider;

  final String customDohUrl;

  AntiDpiProfile get antiDpiProfile =>
      AntiDpiProfile.byLabel(antiDpiProfileLabel);

  /// Effective DoH endpoint, or null when disabled/misconfigured.
  String? get dohEndpoint {
    if (dohProvider == DohProvider.off) return null;
    if (dohProvider == DohProvider.custom) {
      final url = customDohUrl.trim();
      return url.isEmpty ? null : url;
    }
    return dohProvider.endpoint;
  }

  bool get hasDoh => dohEndpoint != null;

  NetworkProxySettings copyWith({
    bool? warpEnabled,
    bool? antiDpiEnabled,
    int? antiDpiPort,
    String? antiDpiProfileLabel,
    DohProvider? dohProvider,
    String? customDohUrl,
  }) {
    return NetworkProxySettings(
      warpEnabled: warpEnabled ?? this.warpEnabled,
      antiDpiEnabled: antiDpiEnabled ?? this.antiDpiEnabled,
      antiDpiPort: antiDpiPort ?? this.antiDpiPort,
      antiDpiProfileLabel: antiDpiProfileLabel ?? this.antiDpiProfileLabel,
      dohProvider: dohProvider ?? this.dohProvider,
      customDohUrl: customDohUrl ?? this.customDohUrl,
    );
  }
}
