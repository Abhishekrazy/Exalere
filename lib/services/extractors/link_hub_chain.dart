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

  /// Pages that sit between a site's download button and the real mirror.
  ///
  /// `mdrive.lol/archive/<id>/` is the same shape as a LinkHub view page: the
  /// HTML already lists the HubCloud anchors, so one request reaches the mirror
  /// instead of the two a HubDrive hop would cost.
  static const List<String> viewHosts = [
    'linkshub.',
    'fastilinks.',
    'mdrive.lol/archive/',
  ];

  static bool isViewUrl(String url) {
    final lowered = url.toLowerCase();
    return viewHosts.any(lowered.contains);
  }

  /// Direct-file mirrors listed by a view page.
  ///
  /// Only HubDrive hosts are returned: a DriveHub page is a mirror-on-demand
  /// service (it uploads to pixeldrain/telegram when asked), so fetching it can
  /// never yield a file — asking anyway cost a request and a ten-second timeout
  /// per post.
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
      if (trimmed.isEmpty) continue;
      // DriveHub is listed next to HubDrive but has no file behind it.
      final lowered = trimmed.toLowerCase();
      if (lowered.contains('drivehub.')) continue;
      if (!seen.add(trimmed)) continue;
      urls.add(trimmed);
    }
    return urls;
  }

  /// Every HubCloud page a view page lists, in document order.
  static List<String> hubCloudUrls(String html) {
    final matches = RegExp(
      r'''href=["'](https?://[^"']*hubcloud[^"']*/drive/[^"']+|https?://[^"']*vcloud[^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html);
    final urls = <String>[];
    final seen = <String>{};
    for (final match in matches) {
      final raw = match.group(1);
      if (raw == null) continue;
      final trimmed = raw.trim().replaceAll('&amp;', '&');
      if (trimmed.isEmpty || !seen.add(trimmed)) continue;
      urls.add(trimmed);
    }
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
