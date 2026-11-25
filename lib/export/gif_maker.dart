import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Tham số render GIF comic.
class GifJob {
  const GifJob({
    required this.pngBytes,
    required this.focusA,
    required this.focusB,
    this.maxDim = 480,
    this.frames = 8,
    this.delayCs = 14,
  });

  /// PNG của canvas đã flatten (đã filter + sticker).
  final Uint8List pngBytes;

  /// Tâm 2 panel chính, toạ độ chuẩn hoá 0..1 — zoom-punch luân phiên giữa 2 tâm.
  final (double, double) focusA;
  final (double, double) focusB;

  /// Resize về cạnh dài tối đa này trước khi encode (GIF nhẹ để share).
  final int maxDim;

  /// Số frame cho 1 loop.
  final int frames;

  /// Delay mỗi frame, đơn vị 1/100 giây.
  final int delayCs;
}

/// Encode trong isolate để không drop frame UI.
Future<Uint8List> encodeComicGif(GifJob job) => Isolate.run(() => _encode(job));

/// GIF comic: pulse zoom mượt (1.00..1.08) + focus luân phiên giữa 2 panel
/// mỗi frame + shake ngang nhỏ — cảm giác "hoạt hình truyện tranh".
Uint8List _encode(GifJob job) {
  final src = img.decodePng(job.pngBytes);
  if (src == null) throw StateError('PNG không hợp lệ');
  // Resize theo cạnh DÀI — cả portrait lẫn landscape đều <= maxDim.
  img.Image base = src.clone();
  if (src.width > job.maxDim || src.height > job.maxDim) {
    base = src.width >= src.height
        ? img.copyResize(src, width: job.maxDim)
        : img.copyResize(src, height: job.maxDim);
  }
  final w = base.width;
  final h = base.height;

  final encoder = img.GifEncoder(
    repeat: 0,
    quantizerType: img.QuantizerType.octree,
    samplingFactor: 1,
    dither: img.DitherKernel.none,
  );

  for (var i = 0; i < job.frames; i++) {
    // Pulse mượt 1 chu kỳ/loop — cả 2 panel đều trải qua đỉnh zoom 1.08 và
    // đáy 1.00 (sin chu kỳ = frames, không sync với parity của focus switch).
    final zoom = 1.04 + 0.04 * math.sin(2 * math.pi * i / job.frames);
    final focus = i.isEven ? job.focusA : job.focusB;
    final shakeX = (i.isEven ? 1 : -1) * 0.012; // lắc nhẹ ±1.2% chiều rộng
    final sw = math.max(w, (w * zoom).round());
    final sh = math.max(h, (h * zoom).round());
    final scaled = (sw == w && sh == h) ? base : img.copyResize(base, width: sw, height: sh);
    final cx = ((focus.$1 + shakeX) * sw - w / 2).round().clamp(0, sw - w);
    final cy = (focus.$2 * sh - h / 2).round().clamp(0, sh - h);
    final frame = img.copyCrop(scaled, x: cx, y: cy, width: w, height: h);
    encoder.addFrame(frame, duration: job.delayCs);
  }
  final out = encoder.finish();
  if (out == null) throw StateError('Encode GIF thất bại');
  return out;
}
