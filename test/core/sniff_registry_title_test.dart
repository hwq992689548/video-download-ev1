import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/core/lesson_title.dart';
import 'package:video_download_ev1/core/sniff_registry.dart';

void main() {
  const url =
      'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
      '320356691_3a003e7b170d65b5a67a671418ffcecc_UwxXdY3S.mp4?t=1';

  test('drops generic page titles like 商品详情', () {
    final registry = SniffRegistry();
    registry.register('tab', url, title: '商品详情');
    expect(registry.entriesFor('tab').single.title, isNull);
  });

  test('page-title backfill only fills empty names', () {
    final registry = SniffRegistry();
    registry.register('tab', url, title: '绪论');
    registry.backfillMissingTitles('tab', '系统分析师', source: 'onTitleChanged');
    expect(registry.entriesFor('tab').single.title, '绪论');
  });

  test('play vid from CDN stem gets 当前试听, other files stay empty', () {
    final registry = SniffRegistry();
    const playing =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
        '198409541_c34f0e3e11b082be55fb8bed41e3d261_eocoQLcR.mp4?t=1';
    const other =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
        '198409564_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_iz2fwXiy.mp4?t=1';
    registry.register('tab', other);
    registry.register('tab', playing);
    registry.trackPlayVid(
      'tab',
      'https://m.beegoedu.com/rest/mall/getPlayToken?vid=198409541',
    );
    registry.applyDomLessonScrape(
      'tab',
      const DomLessonScrape(
        trial: '政治经济学的研究任务',
        chosen: '第3节 政治经济学的研究任务',
      ),
    );
    final entries = registry.entriesFor('tab');
    expect(
      entries.firstWhere((e) => e.url == playing).title,
      '政治经济学的研究任务',
    );
    expect(entries.firstWhere((e) => e.url == other).title, isNull);
  });

  test('directory vid map names every sniffed file without clicking it', () {
    final registry = SniffRegistry();
    const playing =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
        '198409541_c34f0e3e11b082be55fb8bed41e3d261_eocoQLcR.mp4?t=1';
    const other =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
        '198409564_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_iz2fwXiy.mp4?t=1';
    registry.register('tab', other);
    registry.register('tab', playing);
    registry.applyDomLessonScrape(
      'tab',
      const DomLessonScrape(
        trial: '政治经济学的研究任务',
        chosen: '第3节 政治经济学的研究任务',
        byVid: {
          '198409541': '政治经济学的研究任务',
          '198409564': '政治经济学的研究对象',
        },
      ),
    );
    final entries = registry.entriesFor('tab');
    expect(
      entries.firstWhere((e) => e.url == playing).title,
      '政治经济学的研究任务',
    );
    expect(
      entries.firstWhere((e) => e.url == other).title,
      '政治经济学的研究对象',
    );
  });

  test('catalog lesson title replaces course page title', () {
    final registry = SniffRegistry();
    registry.register('tab', url, title: '系统分析师');
    registry.ingestCatalog(
      'tab',
      '''
{
  "data": [
    {
      "pvideoId": "320356691",
      "catName": "第1讲 绪论",
      "level": 3
    }
  ]
}
''',
    );
    expect(registry.entriesFor('tab').single.title, '绪论');
  });
}
