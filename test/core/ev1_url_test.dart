import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/core/ev1_url.dart';
import 'package:video_download_ev1/core/sniff_registry.dart';

void main() {
  test('Ev1Url.sameResource ignores query params', () {
    const a =
        'https://cdn.example.com/video/foo.ev1?t=1&sign=aaa';
    const b =
        'https://cdn.example.com/video/foo.ev1?t=2&sign=bbb';
    expect(Ev1Url.sameResource(a, b), isTrue);
    expect(Ev1Url.normalizeKey(a), '/video/foo.ev1');
  });

  test('same Baijiayun file matches across sign, host, and mp4/ev2', () {
    const mp4Play1 =
        'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
        '198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89.mp4'
        '?t=6aa16a56&sign=d9195272d0bebf50a2d81eea2c2b1fee'
        '&uuid=a27b4d57-7f6a-d5ba-dd7d-788e2ebdd7b3';
    const mp4Play2 =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
        '198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89.mp4'
        '?t=6aa16ac1&sign=6c69ba8fa3b7a183302a742facbff133'
        '&uuid=77153a8a-ad4c-a3d1-d5ad-be41d371c33c';
    const ev2 =
        'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
        '198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89_mp4/'
        '198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89.ev2?t=1';
    const other =
        'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
        '318761433_b33beda1dc128af4b64f9ba0c0e93fa2_qANuKKA9.mp4?t=1';

    expect(Ev1Url.sameResource(mp4Play1, mp4Play2), isTrue);
    expect(Ev1Url.sameResource(mp4Play1, ev2), isTrue);
    expect(Ev1Url.sameResource(mp4Play1, other), isFalse);
    expect(
      Ev1Url.resourceStem(mp4Play1),
      '198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89',
    );
  });

  test('SniffRegistry merges reload mp4 into the same sniff entry', () {
    final r = SniffRegistry();
    const first =
        'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
        '198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89.mp4?sign=1';
    const second =
        'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
        '198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89.mp4?sign=2';
    r.register('t', first);
    r.register('t', second);
    expect(r.entriesFor('t').length, 1);
    expect(r.entriesFor('t').first.url, second);
  });

  test('SniffRegistry deduplicates by ev1 path', () {
    final r = SniffRegistry();
    r.register('t', 'https://x.com/a.ev1?sign=1');
    r.register('t', 'https://x.com/a.ev1?sign=2');
    expect(r.entriesFor('t').length, 1);
    expect(r.entriesFor('t').first.url, contains('sign=2'));
  });

  test('rewritePlayUrl asks Baijiayun for ev1/ev2 instead of H5 mp4', () {
    const h5 =
        'https://www.baijiayun.com/vod/video/getPlayUrl?vid=198599077&client_type=h5&supports_format=m3u8,mp4&callback=__jp0';
    final rewritten = Ev1Url.rewritePlayUrl(h5);
    expect(rewritten, contains('client_type=pc'));
    expect(rewritten, contains('supports_format=ev1,ev2,m3u8,mp4'));
    expect(Ev1Url.rewritePlayUrl(rewritten), rewritten);
  });

    test('extractUrlsFromText finds ev1 in JSON and escaped slashes', () {
    const body = r'{"playurl":"https:\/\/cdn.example.com\/a.ev1?t=1&sign=x"}';
    expect(
      SniffRegistry.extractUrlsFromText(body),
      ['https://cdn.example.com/a.ev1?t=1&sign=x'],
    );
  });

  test('isBaijiayunDirectUrl matches VOD CDN mp4 and m3u8 only', () {
    const vod =
        'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89.mp4?t=6aa1200c&sign=82cd5cf797b231fa22262b6a4bae4b14&uuid=59bb4a37-418e-8230-2cf6-fc8a320f4743';
    const m3u8 =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/198599077_abc.m3u8?t=1';
    expect(SniffRegistry.isBaijiayunDirectUrl(vod), isTrue);
    expect(SniffRegistry.directFileExtension(vod), 'mp4');
    expect(SniffRegistry.isBaijiayunDirectUrl(m3u8), isTrue);
    expect(SniffRegistry.directFileExtension(m3u8), 'm3u8');
    expect(SniffRegistry.isSniffableUrl(vod), isTrue);
    expect(
      SniffRegistry.isBaijiayunDirectUrl('https://cdn.example.com/ad.mp4'),
      isFalse,
    );
    expect(
      SniffRegistry.isBaijiayunDirectUrl(
        'https://www.baijiayun.com/static/player.mp4',
      ),
      isFalse,
    );
  });

  test('SniffRegistry registers Baijiayun mp4/m3u8 and prefers ev for same vid', () {
    final r = SniffRegistry();
    const mp4 =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/198599077_abc.mp4?t=1';
    const ev =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/198599077_abc.ev2?t=2';
    r.register('t', mp4);
    expect(r.entriesFor('t').length, 1);
    expect(r.entriesFor('t').first.url, mp4);

    r.register('t', ev);
    expect(r.entriesFor('t').length, 1);
    expect(r.entriesFor('t').first.url, ev);

    r.register('t', mp4);
    expect(r.entriesFor('t').length, 1);
    expect(r.entriesFor('t').first.url, ev);

    final r2 = SniffRegistry();
    const playlist =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/198599078_abc.m3u8?t=1';
    r2.register('t', playlist);
    expect(r2.entriesFor('t').single.url, playlist);
  });

  test('updateEntry applies download file name immediately', () {
    final r = SniffRegistry();
    r.register(
      't',
      'https://dws4jd-video.baijiayun.com/00-x-upload/video/198599077_abc.mp4',
    );
    r.updateEntry(
      't',
      'https://dws4jd-video.baijiayun.com/00-x-upload/video/198599077_abc.mp4',
      status: SniffStatus.downloading,
      title: '自定义名称',
    );
    final entry = r.entriesFor('t').single;
    expect(entry.status, SniffStatus.downloading);
    expect(SniffRegistry.displayTitle(entry), '自定义名称');
  });
}
