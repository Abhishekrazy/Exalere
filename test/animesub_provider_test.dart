import 'package:flutter_test/flutter_test.dart';

import 'package:exalere/services/animesub_provider.dart';

void main() {
  group('AnimeSub configuration form', () {
    const html = '''
      <form id="configForm">
        <input type="hidden" name="csrf" value="abc123">
        <input type="hidden" name="uiLanguage" value="en-US">
        <input type="checkbox" name="torrentSources[]" value="nyaa" checked>
        <input type="checkbox" name="torrentSources[]" value="dmhy">
        <input type="checkbox" name="enableP2P" checked>
        <input type="checkbox" name="hideUncached" checked>
        <select name="service[]">
          <option value="">none</option>
          <option value="torbox" selected>TorBox</option>
        </select>
        <textarea name="notes">hello</textarea>
      </form>
    ''';

    test('collects checked boxes, selected options and text values', () {
      final fields = AnimeSubProvider.parseConfigForm(html);

      expect(fields['csrf'], 'abc123');
      expect(fields['torrentSources[]'], 'nyaa');
      expect(fields.containsKey('dmhy'), isFalse);
      expect(fields['enableP2P'], 'on');
      expect(fields['hideUncached'], 'on');
      expect(fields['service[]'], 'torbox');
      expect(fields['notes'], 'hello');
    });

    test('falls back to the first option when none is selected', () {
      final fields = AnimeSubProvider.parseConfigForm('''
        <form id="configForm">
          <select name="mode"><option value="a">A</option><option value="b">B</option></select>
        </form>
      ''');
      expect(fields['mode'], 'a');
    });

    test('returns nothing without a form or names', () {
      expect(AnimeSubProvider.parseConfigForm('<p>no form</p>'), isEmpty);
      expect(
        AnimeSubProvider.parseConfigForm(
          '<form id="configForm"><input></form>',
        ),
        isEmpty,
      );
    });
  });

  group('AnimeSub token and subject handling', () {
    test('reads the token from a configure response', () {
      const body =
          '<a href="/u_AjfNX8pqHW72uDb_ylsDgA/manifest.json">install</a>';
      expect(AnimeSubProvider.parseToken(body), 'u_AjfNX8pqHW72uDb_ylsDgA');
      expect(
        AnimeSubProvider.parseToken('<p>invalid configuration</p>'),
        isNull,
      );
    });

    test('parses IMDb ids with season and episode', () {
      final movie = AnimeSubProvider.parseSubject('tt0111161');
      expect(movie.imdb, 'tt0111161');
      expect(movie.season, isNull);

      final episode = AnimeSubProvider.parseSubject('tt0388629:1:12');
      expect(episode.imdb, 'tt0388629');
      expect(episode.season, 1);
      expect(episode.episode, 12);
    });

    test('builds token URLs', () {
      expect(
        AnimeSubProvider.streamUri(
          'u_abc',
          'series',
          'tt0388629:1:1',
        ).toString(),
        'https://animesub.duckdns.org/u_abc/stream/series/tt0388629:1:1.json',
      );
      expect(
        AnimeSubProvider.manifestUri('u_abc').toString(),
        'https://animesub.duckdns.org/u_abc/manifest.json',
      );
    });
  });
}
