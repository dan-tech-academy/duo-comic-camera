import 'dart:typed_data';

import 'package:duo_comic_camera/editor/editor_controller.dart';
import 'package:duo_comic_camera/editor/filters/comic_filters.dart';
import 'package:duo_comic_camera/editor/layouts.dart';
import 'package:duo_comic_camera/editor/stickers/sticker_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List fakeJpeg() {
  final im = img.Image(width: 12, height: 16);
  for (final p in im) {
    p.r = 200;
    p.g = 120;
    p.b = 60;
  }
  return img.encodeJpg(im);
}

/// Runner giả: không spawn isolate, trả PNG nhỏ kèm marker filter vào width
/// để test phân biệt cache theo filter.
Future<FilterResult> fakeRunner(FilterJob job) async {
  final im = img.Image(width: 8 + job.filter.index, height: 10);
  return FilterResult(pngBytes: img.encodePng(im), width: im.width, height: 10);
}

EditorController makeController() => EditorController(
      rearBytes: fakeJpeg(),
      frontBytes: fakeJpeg(),
      filterRunner: fakeRunner,
    );

void main() {
  test('init load preview filter none cho cả 2 camera', () async {
    final c = makeController();
    await c.init();
    expect(c.rearResult, isNotNull);
    expect(c.frontResult, isNotNull);
    expect(c.processing, isFalse);
    expect(c.filter, ComicFilterType.none);
  });

  test('setFilter chạy pipeline và cache lần 2 instant', () async {
    final c = makeController();
    await c.init();
    await c.setFilter(ComicFilterType.pop);
    expect(c.filter, ComicFilterType.pop);
    expect(c.rearResult!.width, 8 + ComicFilterType.pop.index);

    var calls = 0;
    Future<FilterResult> countingRunner(FilterJob job) async {
      calls++;
      return fakeRunner(job);
    }

    final c2 = EditorController(
      rearBytes: fakeJpeg(),
      frontBytes: fakeJpeg(),
      filterRunner: countingRunner,
    );
    await c2.init();
    expect(calls, 2);
    await c2.setFilter(ComicFilterType.pop);
    expect(calls, 4);
    await c2.setFilter(ComicFilterType.none); // cache hit -> không chạy lại
    expect(calls, 4);
  });

  test('swap đổi first/second result', () async {
    final c = makeController();
    await c.init();
    expect(identical(c.firstResult, c.rearResult), isTrue);
    c.swap();
    expect(identical(c.firstResult, c.frontResult), isTrue);
    expect(c.swapped, isTrue);
  });

  test('setSplitRatio clamp 0.25..0.75', () async {
    final c = makeController();
    c.setSplitRatio(0.1);
    expect(c.splitRatio, 0.25);
    c.setSplitRatio(0.95);
    expect(c.splitRatio, 0.75);
  });

  test('sticker: add/select/move/transform/remove/text', () async {
    final c = makeController();
    await c.init();
    c.addSticker(kStickerCatalog.first);
    expect(c.stickers.length, 1);
    final id = c.stickers.first.id;
    expect(c.selectedStickerId, id);

    c.moveSticker(id, const Offset(2, 2));
    expect(c.stickers.first.center.dx, 1.1); // clamp
    c.transformSticker(id, scale: 99, rotation: 0.5);
    expect(c.stickers.first.scale, StickerPlacement.maxScale);
    expect(c.stickers.first.rotation, 0.5);

    c.setStickerText(id, 'Xin chào!');
    expect(c.stickers.first.spec.text, 'Xin chào!');

    c.removeSticker(id);
    expect(c.stickers, isEmpty);
    expect(c.selectedStickerId, isNull);
  });

  test('setLayout/setAspect notify listeners', () async {
    final c = makeController();
    var notified = 0;
    c.addListener(() => notified++);
    c.setLayout(DuoLayout.pipTopLeft);
    c.setAspect(CanvasAspect.square);
    expect(c.layout, DuoLayout.pipTopLeft);
    expect(c.aspect, CanvasAspect.square);
    expect(notified, 2);
  });
}
