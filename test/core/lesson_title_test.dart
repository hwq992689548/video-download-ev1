import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/core/lesson_title.dart';

void main() {
  test('picks the playing lesson heading', () {
    expect(
      pickLessonTitle(
        playing: '第一节 政治经济学的产生和发展',
        matches: ['第二节 某某', '第一节 政治经济学的产生和发展'],
      ),
      '第一节 政治经济学的产生和发展',
    );
  });

  test('parses JSON scrape from the page', () {
    const raw = '''
{"v":4,"playing":"第一节 政治经济学的产生和发展","matches":["第一节 政治经济学的产生和发展"],"title":"商品详情"}
''';
    final parsed = parseDomLessonScrape(raw);
    expect(parsed.chosen, '第一节 政治经济学的产生和发展');
  });

  test('parses double-encoded JSON string', () {
    const raw =
        '"{\\"v\\":4,\\"playing\\":\\"第一节 政治经济学的产生和发展\\",\\"matches\\":[],\\"title\\":\\"商品详情\\"}"';
    final parsed = parseDomLessonScrape(raw);
    expect(parsed.chosen, '第一节 政治经济学的产生和发展');
  });

  test('prefers 当前试听 merged with 第X节', () {
    expect(
      pickLessonTitle(
        trial: '政治经济学的研究任务',
        playing: '第一节 政治经济学的产生和发展',
        matches: [
          '第一节 政治经济学的产生和发展',
          '第3节 政治经济学的研究任务',
        ],
      ),
      '第3节 政治经济学的研究任务',
    );
  });

  test('parses stem-keyed titles from scrape JSON', () {
    const raw = '''
{"v":5,"trial":"政治经济学的研究任务","playing":"第3节 政治经济学的研究任务","matches":[],"byVid":{"198409541":"第3节 政治经济学的研究任务"},"byStem":{"198409541_c34f0e3e11b082be55fb8bed41e3d261_eocoQLcR":"第3节 政治经济学的研究任务"},"title":"商品详情"}
''';
    final parsed = parseDomLessonScrape(raw);
    expect(parsed.chosen, '第3节 政治经济学的研究任务');
    expect(
      parsed.byStem['198409541_c34f0e3e11b082be55fb8bed41e3d261_eocoQLcR'],
      '第3节 政治经济学的研究任务',
    );
  });

  test('parses a directory of vid titles from scrape JSON', () {
    const raw = '''
{"v":7,"trial":"政治经济学的研究任务","playing":"","byVid":{"198409541":"政治经济学的研究任务","198409564":"政治经济学的研究对象"},"byStem":{},"title":"商品详情"}
''';
    final parsed = parseDomLessonScrape(raw);
    expect(parsed.byVid['198409541'], '政治经济学的研究任务');
    expect(parsed.byVid['198409564'], '政治经济学的研究对象');
  });

  test('ignores product page titles', () {
    expect(looksLikeLessonTitle('商品详情'), isFalse);
    expect(looksLikeLessonTitle('大数据与会计-专科-全科基础班'), isFalse);
    expect(looksLikeLessonTitle('第一节 政治经济学的产生和发展'), isTrue);
  });
}
