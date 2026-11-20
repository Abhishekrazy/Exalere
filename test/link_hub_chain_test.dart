import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/extractors/link_hub_chain.dart';

/// A LinkHub view page lists its mirrors in plain HTML; the Turnstile widget is
/// decoration over the same markup. These tests pin the parsing, because a wrong
/// hop costs a request and a chain walks several.
void main() {
  group('LinkHub chain', () {
    test('recognises view pages only', () {
      expect(
        LinkHubChain.isViewUrl('https://links.linkshub.fun/view/BawTYQtdP4'),
        isTrue,
      );
      expect(
        LinkHubChain.isViewUrl('https://fastilinks.beauty/view/R386nQpWmm'),
        isTrue,
      );
      expect(LinkHubChain.isViewUrl('https://hubcloud.mov/drive/abc'), isFalse);
    });

    test('reads mirrors, dedupes and prefers HubDrive', () {
      const html = '''
        <a href="https://new2.drivehub.dad/file/6313613">DriveHub</a>
        <a href="https://hubdrive.blog/file/1862402834">HubDrive</a>
        <a href="https://hubdrive.blog/file/1862402834">same again</a>
        <a href="https://example.com/about">About</a>
      ''';

      final urls = LinkHubChain.hubDriveUrls(html);

      expect(urls, [
        'https://hubdrive.blog/file/1862402834',
        'https://new2.drivehub.dad/file/6313613',
      ]);
    });

    test('finds the HubCloud page behind a HubDrive file', () {
      const html = '''
        <h4><a href="https://hubcloud.mov/tg/go?id=abc">Join</a></h4>
        <h5><a href="https://hubcloud.mov/drive/vsur13sas4qsffu">[HubCloud]</a></h5>
        <a href="https://vcloud.my/xyz?token=a&amp;b=c">V-Cloud</a>
      ''';

      expect(
        LinkHubChain.hubCloudUrl(html),
        'https://hubcloud.mov/drive/vsur13sas4qsffu',
      );
      // Entities are restored, or the request signature breaks.
      expect(
        LinkHubChain.hubCloudUrl(
          '<a href="https://vcloud.my/x?t=1&amp;u=2">v</a>',
        ),
        'https://vcloud.my/x?t=1&u=2',
      );
    });

    test('a page without a mirror yields nothing', () {
      expect(LinkHubChain.hubDriveUrls('<div>Nothing here</div>'), isEmpty);
      expect(LinkHubChain.hubCloudUrl('<div>Nothing here</div>'), isNull);
    });
  });
}
