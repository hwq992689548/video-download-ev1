import 'package:flutter_test/flutter_test.dart';

import 'package:video_download_ev1/core/beego_catalog.dart';

void main() {
  group('BeegoCatalog', () {
    test('maps leaf pvideoId to normalized lesson title', () {
      const json = '''
{
  "data": [
    {
      "catId": 87570,
      "level": 1,
      "pvideoId": "",
      "catName": "第一章 国际市场营销学导论",
      "childList": [
        {
          "catId": 87571,
          "level": 2,
          "pvideoId": "",
          "catName": "第一节国际市场营销学的基本概念",
          "childList": [
            {
              "catId": 87572,
              "level": 3,
              "pvideoId": "185726408",
              "catName": "国际市场营销学的基本概念",
              "childList": []
            }
          ]
        }
      ]
    }
  ]
}
''';

      final catalog = BeegoCatalog();
      catalog.ingestCatalogJson(json);

      expect(
        catalog.lookupTitleForUrl(
          'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
          '185726408_977a448fe8060560f94b0d9e741f2752_VDmS8In1_mp4/'
          '185726408_977a448fe8060560f94b0d9e741f2752_VDmS8In1.ev2',
        ),
        '国际市场营销学的基本概念',
      );
    });

    test('strips section prefix from level-2 video names', () {
      const json = '''
{
  "data": [
    {
      "level": 2,
      "pvideoId": "185726409",
      "catName": "第二节企业开展国际市场营销的动因",
      "childList": []
    }
  ]
}
''';

      final catalog = BeegoCatalog();
      catalog.ingestCatalogJson(json);

      expect(
        catalog.lookupTitleForUrl(
          'https://example.com/video/185726409_foo.ev2',
        ),
        '企业开展国际市场营销的动因',
      );
      expect(
        catalog.lookupTitleForUrl(
          'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
          '185726409_foo.mp4?t=1',
        ),
        '企业开展国际市场营销的动因',
      );
      expect(
        catalog.lookupTitleForUrl(
          'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
          '185726409_foo.mp4?t=1',
        ),
        '企业开展国际市场营销的动因',
      );
    });

    test('rejects price-like titles', () {
      expect(BeegoCatalog.isValidLessonTitle('￥799'), isFalse);
      expect(BeegoCatalog.isValidLessonTitle('线路1'), isFalse);
      expect(BeegoCatalog.isValidLessonTitle('国际市场营销学的基本概念'), isTrue);
    });
  });
}
