import 'package:duo_comic_camera/export/gif_maker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('encodeComicGif', () {
    test('encode ra GIF animated đúng số frame, kích thước giới hạn', () async {
      // PNG nguồn 300x200: nửa trái đỏ, nửa phải xanh dương.
      final src = img.Image(width: 300, height: 200);
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 300; x++) {
          src.setPixelRgb(x, y, x < 150 ? 220 : 40, 30, x < 150 ? 40 : 220);
        }
      }
      final pngBytes = img.encodePng(src);

      final gif = await encodeComicGif(GifJob(
        pngBytes: pngBytes,
        focusA: (0.25, 0.5),
        focusB: (0.75, 0.5),
        frames: 8,
        delayCs: 10,
      ));

      final decoded = img.decodeGif(gif);
      expect(decoded, isNotNull);
      expect(decoded!.numFrames, 8);
      expect(decoded.width, lessThanOrEqualTo(480));
      expect(decoded.height, 200);
      for (final frame in decoded.frames) {
        expect(frame.width, decoded.width);
        expect(frame.height, decoded.height);
      }
    });

    test('ảnh lớn hơn maxDim được resize về maxDim', () async {
      final src = img.Image(width: 1200, height: 800);
      img.fill(src, color: img.ColorRgb8(120, 120, 120));
      final gif = await encodeComicGif(GifJob(
        pngBytes: img.encodePng(src),
        focusA: (0.5, 0.5),
        focusB: (0.5, 0.5),
        frames: 4,
        maxDim: 480,
      ));
      final decoded = img.decodeGif(gif)!;
      expect(decoded.numFrames, 4);
      expect(decoded.width, 480);
    });
  });
}
