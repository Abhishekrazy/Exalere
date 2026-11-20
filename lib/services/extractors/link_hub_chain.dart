/// LinkHub view pages (`linkshub.fun/view/…`, `fastilinks.*`) sit between a
/// download button and the real mirror.
///
/// The page's HTML already lists the destination mirrors — the Turnstile widget
/// is decoration on top of the same markup — so the chain is plain scraping:
/// view page → HubDrive file page → HubCloud page → signed CDN link.
///
/// Kept as pure helpers so the parsing is tested against recorded markup instead
/// of a live site, and so callers can bound how many hops they will pay for.
class LinkHubChain {
  const LinkHubChain._();

  /// Domains that serve the view page.
  static const List<String> viewHosts = ['linkshub.', 'fastilinks.'];

  static bool isViewUrl(String url) {
    final lowered = url.toLowerCase();
    return viewHosts.any(lowered.contains);
  }

  /// Direct-file mirrors listed by a view page.
  ///
  /// HubDrive pages print the HubCloud link immediately; DriveHub is a
  /// mirror-on-demand service (it uploads to pixeldrain/telegram on request),
  /// so it is kept but ranked after HubDrive.
  static List<String> hubDriveUrls(String html) {
    final matches = RegExp(
      r'''href=["'](https?://[^"']*(?:hubdrive|drivehub)\.[^"']*/file/[^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html);

    final urls = <String>[];
    final seen = <String>{};
    for (final match in matches) {
      final url = match.group(1);
      if (url == null) continue;
      final trimmed = url.trim().replaceAll('&amp;', '&');
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      urls.add(trimmed);
    }
    // HubDrive first, DriveHub second, everything else after.
    urls.sort((a, b) {
      final aDrive = a.toLowerCase().contains('hubdrive') ? 0 : 1;
      final bDrive = b.toLowerCase().contains('hubdrive') ? 0 : 1;
      return aDrive.compareTo(bDrive);
    });
    return urls;
  }

  /// The HubCloud page a HubDrive file page points at.
  static String? hubCloudUrl(String html) {
    final match = RegExp(
      r'''href=["'](https?://[^"']*hubcloud[^"']*/drive/[^"']+|https?://[^"']*vcloud[^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    final raw = match?.group(1);
    if (raw == null) return null;
    return raw.trim().replaceAll('&amp;', '&');
  }
}
