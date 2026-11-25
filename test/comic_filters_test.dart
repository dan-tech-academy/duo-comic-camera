import 'dart:typed_data';

import 'package:duo_comic_camera/editor/filters/comic_filters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

img.Image gradientImage(int w, int h) {
  final im = img.Image(width: w, height: h);
  for (final p in im) {
    p.r = p.x * 255 / (w - 1);
    p.g = p.y * 255 / (h - 1);
    p.b = 128;
    p.a = 255;
  }
  return im;
}

void main() {
  group('applyComicFilter', () {
    test('none giữ nguyên pixel', () {
      final src = gradientImage(16, 16);
      final before = src.getPixel(8, 8);
      final out = applyComicFilter(src.clone(), ComicFilterType.none);
      final after = out.getPixel(8, 8);
      expect(after.r, before.r);
      expect(after.g, before.g);
      expect(after.b, before.b);
    });

    test('noir ra grayscale: r == g == b', () {
      final out = applyComicFilter(gradientImage(16, 16).clone(), ComicFilterType.noir);
      for (final p in out) {
        expect(p.r, p.g);
        expect(p.g, p.b);
      }
    });

    test('chill tăng kênh xanh dương', () {
      final src = img.Image(width: 4, height: 4);
      for (final p in src) {
        p.r = 100;
        p.g = 100;
        p.b = 100;
      }
      final out = applyComicFilter(src, ComicFilterType.chill);
      final p = out.getPixel(0, 0);
      expect(p.b, greaterThan(p.r));
    });

    test('heat tăng kênh đỏ, giảm xanh dương', () {
      final src = img.Image(width: 4, height: 4);
      for (final p in src) {
        p.r = 100;
        p.g = 100;
        p.b = 100;
      }
      final out = applyComicFilter(src, ComicFilterType.heat);
      final p = out.getPixel(0, 0);
      expect(p.r, greaterThan(p.b));
    });

    test('posterize lượng tử hoá về đúng số mức', () {
      final src = img.Image(width: 8, height: 1);
      for (final p in src) {
        p.r = p.x * 255 / 7;
        p.g = p.r;
        p.b = p.r;
      }
      final out = posterize(src, 4);
      final values = <num>{};
      for (final p in out) {
        values.add(p.r);
      }
      expect(values.length, lessThanOrEqualTo(4));
      const step = 255 / 3;
      for (final v in values) {
        expect((v / step).round() * step, closeTo(v, 0.51));
      }
    });

    test('mọi filter chạy không crash và giữ kích thước', () {
      for (final type in ComicFilterType.values) {
        final out = applyComicFilter(gradientImage(24, 32).clone(), type);
        expect(out.width, 24, reason: type.name);
        expect(out.height, 32, reason: type.name);
      }
    });
  });

  group('processPhoto', () {
    test('resize về maxDim và encode PNG hợp lệ', () {
      final src = gradientImage(120, 90);
      final jpeg = img.encodeJpg(src);
      final result = processPhoto(
        FilterJob(bytes: jpeg, maxDim: 40, filter: ComicFilterType.none),
      );
      expect(result.width, 40);
      expect(result.height, 30);
      final decoded = img.decodePng(result.pngBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 40);
    });

    test('ảnh portrait resize theo chiều cao', () {
      final src = gradientImage(60, 120);
      final jpeg = img.encodeJpg(src);
      final result = processPhoto(
        FilterJob(bytes: jpeg, maxDim: 60, filter: ComicFilterType.cartoon),
      );
      expect(result.height, 60);
      expect(result.width, 30);
    });

    test('throw ArgumentError với bytes rác', () {
      expect(
        () => processPhoto(
          FilterJob(
            bytes: Uint8List.fromList([1, 2, 3, 4]),
            maxDim: 32,
            filter: ComicFilterType.none,
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
