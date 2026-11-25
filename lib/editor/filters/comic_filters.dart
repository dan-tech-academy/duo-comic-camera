import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Các filter phong cách comic. Mọi filter chạy pixel-level bằng package
/// `image` trong isolate (qua `compute`) nên kết quả preview == kết quả xuất.
enum ComicFilterType { none, pop, halftone, cartoon, noir, vintage, chill, heat }

class ComicFilter {
  const ComicFilter(this.type, this.label, this.tagline);

  final ComicFilterType type;
  final String label;
  final String tagline;
}

const List<ComicFilter> kComicFilters = [
  ComicFilter(ComicFilterType.none, 'Gốc', 'Ảnh nguyên bản'),
  ComicFilter(ComicFilterType.pop, 'POP!', 'Màu rực, tương phản mạnh'),
  ComicFilter(ComicFilterType.halftone, 'Halftone', 'Chấm in truyện tranh CMYK'),
  ComicFilter(ComicFilterType.cartoon, 'Cartoon', 'Posterize kiểu hoạt hình'),
  ComicFilter(ComicFilterType.noir, 'Noir', 'Đen trắng tương phản + vignette'),
  ComicFilter(ComicFilterType.vintage, 'Vintage', 'Sepia truyện xưa'),
  ComicFilter(ComicFilterType.chill, 'Chill', 'Tông xanh mát'),
  ComicFilter(ComicFilterType.heat, 'Heat', 'Tông cam nóng'),
];

num _clamp255(num v) => v.clamp(0, 255);

/// Posterize: lượng tử hoá kênh màu về [levels] mức — nét vẽ hoạt hình.
img.Image posterize(img.Image src, int levels) {
  final step = 255 / (levels - 1);
  for (final p in src) {
    p.r = _clamp255((p.r / step).round() * step);
    p.g = _clamp255((p.g / step).round() * step);
    p.b = _clamp255((p.b / step).round() * step);
  }
  return src;
}

img.Image applyComicFilter(img.Image src, ComicFilterType type) {
  switch (type) {
    case ComicFilterType.none:
      return src;
    case ComicFilterType.pop:
      final out = img.adjustColor(src, saturation: 1.5, contrast: 1.18);
      for (final p in out) {
        p.r = _clamp255(p.r * 1.05 + 4);
      }
      return out;
    case ComicFilterType.halftone:
      final boosted = img.adjustColor(src, saturation: 1.25, contrast: 1.12);
      return img.colorHalftone(boosted, size: 5, angle: 160);
    case ComicFilterType.cartoon:
      final flat = posterize(src, 5);
      return img.adjustColor(flat, saturation: 1.35, contrast: 1.08);
    case ComicFilterType.noir:
      final gray = img.grayscale(src);
      img.contrast(gray, contrast: 165);
      return img.vignette(gray, start: 0.35, end: 0.95, amount: 0.55);
    case ComicFilterType.vintage:
      final sepia = img.sepia(src);
      return img.vignette(
        img.adjustColor(sepia, contrast: 1.05),
        start: 0.4,
        amount: 0.4,
      );
    case ComicFilterType.chill:
      for (final p in src) {
        p.r = _clamp255(p.r * 0.82);
        p.g = _clamp255(p.g * 1.02 + 2);
        p.b = _clamp255(p.b * 1.18 + 8);
      }
      return src;
    case ComicFilterType.heat:
      for (final p in src) {
        p.r = _clamp255(p.r * 1.18 + 8);
        p.g = _clamp255(p.g * 1.02);
        p.b = _clamp255(p.b * 0.78);
      }
      return src;
  }
}

/// Dữ liệu đầu vào cho isolate xử lý filter.
class FilterJob {
  const FilterJob({
    required this.bytes,
    required this.maxDim,
    required this.filter,
    this.intensity = 1.0,
  });

  final Uint8List bytes;
  final int maxDim;
  final ComicFilterType filter;

  /// 0..1 — độ mạnh của filter: blend alpha giữa ảnh gốc và ảnh đã filter.
  final double intensity;
}

/// Kết quả xử lý: PNG bytes + kích thước ảnh sau bake/resize.
class FilterResult {
  const FilterResult({required this.pngBytes, required this.width, required this.height});

  final Uint8List pngBytes;
  final int width;
  final int height;

  double get aspect => width / height;
}

/// Pipeline: decode JPEG -> bake EXIF orientation -> resize về maxDim ->
/// apply filter -> encode PNG. Chạy được trong isolate (top-level function).
FilterResult processPhoto(FilterJob job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) {
    throw ArgumentError('Không decode được ảnh');
  }
  var out = img.bakeOrientation(decoded);
  if (out.width > job.maxDim || out.height > job.maxDim) {
    out = img.copyResize(
      out,
      width: out.width >= out.height ? job.maxDim : null,
      height: out.height > out.width ? job.maxDim : null,
      interpolation: img.Interpolation.linear,
    );
  }
  final preFilter = out.clone();
  out = applyComicFilter(out, job.filter);
  final t = job.intensity.clamp(0.0, 1.0);
  if (t < 1.0 && job.filter != ComicFilterType.none) {
    // Blend pixel-wise giữa ảnh gốc (trước filter) và ảnh đã filter.
    if (out.width != preFilter.width || out.height != preFilter.height) {
      out = img.copyResize(out, width: preFilter.width, height: preFilter.height);
    }
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final a = preFilter.getPixel(x, y);
        final b = out.getPixel(x, y);
        out.setPixelRgb(
          x,
          y,
          _clamp255(a.r + (b.r - a.r) * t),
          _clamp255(a.g + (b.g - a.g) * t),
          _clamp255(a.b + (b.b - a.b) * t),
        );
      }
    }
  }
  return FilterResult(
    pngBytes: img.encodePng(out),
    width: out.width,
    height: out.height,
  );
}
