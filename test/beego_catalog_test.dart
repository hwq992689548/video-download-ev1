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

    test('CDN stem prefix is the play vid', () {
      expect(
        BeegoCatalog.extractVidFromUrl(
          'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
          '198409541_c34f0e3e11b082be55fb8bed41e3d261_eocoQLcR.mp4?t=1',
        ),
        '198409541',
      );
    });

    test('extracts CDN filename stem from mp4 url', () {
      expect(
        BeegoCatalog.resourceStemFromUrl(
          'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
          '198409541_c34f0e3e11b082be55fb8bed41e3d261_eocoQLcR.mp4?t=6aa156'
          '&sign=abc&uuid=3899ab68-7856-b507-86b4-a6d76a7bcefa',
        ),
        '198409541_c34f0e3e11b082be55fb8bed41e3d261_eocoQLcR',
      );
    });

    test('rejects price-like titles', () {
      expect(BeegoCatalog.isValidLessonTitle('￥799'), isFalse);
      expect(BeegoCatalog.isValidLessonTitle('线路1'), isFalse);
      expect(BeegoCatalog.isValidLessonTitle('商品详情'), isFalse);
      expect(BeegoCatalog.isValidLessonTitle('高清'), isFalse);
      expect(BeegoCatalog.isValidLessonTitle('国际市场营销学的基本概念'), isTrue);
    });

    test('maps videoName from nested mall-style JSON', () {
      const json = '''
{
  "code": 200,
  "results": [
    {
      "videoId": "320356691",
      "videoName": "第1讲 绪论"
    }
  ]
}
''';
      final catalog = BeegoCatalog();
      catalog.ingestCatalogJson(json);
      expect(
        catalog.lookupTitleForUrl(
          'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
          '320356691_3a003e7b170d65b5a67a671418ffcecc_UwxXdY3S.mp4?t=1',
        ),
        '绪论',
      );
    });

    test('parses JSONP catalog payloads', () {
      const jsonp =
          '__jp0({"data":[{"pvideoId":"185726408","catName":"国际市场营销学的基本概念"}]})';
      final catalog = BeegoCatalog();
      catalog.ingestCatalogJson(jsonp);
      expect(
        catalog.lookupTitleForUrl('https://example.com/video/185726408_foo.mp4'),
        '国际市场营销学的基本概念',
      );
    });

    test('ignores product JSON without video ids', () {
      const json = '''
{
  "results": {
    "special": [
      {
        "course": [{"coursename": "系统分析师", "courseid": "26519"}]
      }
    ]
  }
}
''';
      final catalog = BeegoCatalog();
      catalog.ingestCatalogJson(json);
      expect(catalog.titles, isEmpty);
    });
  });
}
