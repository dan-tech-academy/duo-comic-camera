import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Layout duo: cách xếp 2 ảnh (camera sau + camera trước) trong 1 khung.
enum DuoLayout {
  splitVertical,
  splitHorizontal,
  diagonalSlash,
  diagonalBackslash,
  pipTopLeft,
  pipTopRight,
  pipBottomLeft,
  pipBottomRight,
  comicPage3,
  comicPage4,
}

class DuoLayoutInfo {
  const DuoLayoutInfo(this.layout, this.label,
      {this.isPip = false,
      this.isDiagonal = false,
      this.isSplit = false,
      this.isComicPage = false});

  final DuoLayout layout;
  final String label;
  final bool isPip;
  final bool isDiagonal;
  final bool isSplit;
  final bool isComicPage;
}

const List<DuoLayoutInfo> kDuoLayouts = [
  DuoLayoutInfo(DuoLayout.splitVertical, 'Chia dọc', isSplit: true),
  DuoLayoutInfo(DuoLayout.splitHorizontal, 'Chia ngang', isSplit: true),
  DuoLayoutInfo(DuoLayout.diagonalSlash, 'Chéo /', isDiagonal: true),
  DuoLayoutInfo(DuoLayout.diagonalBackslash, 'Chéo \\', isDiagonal: true),
  DuoLayoutInfo(DuoLayout.pipTopLeft, 'PiP trái trên', isPip: true),
  DuoLayoutInfo(DuoLayout.pipTopRight, 'PiP phải trên', isPip: true),
  DuoLayoutInfo(DuoLayout.pipBottomLeft, 'PiP trái dưới', isPip: true),
  DuoLayoutInfo(DuoLayout.pipBottomRight, 'PiP phải dưới', isPip: true),
  DuoLayoutInfo(DuoLayout.comicPage3, 'Truyện 3 ô', isComicPage: true),
  DuoLayoutInfo(DuoLayout.comicPage4, 'Truyện 4 ô', isComicPage: true),
];

DuoLayoutInfo layoutInfoOf(DuoLayout layout) =>
    kDuoLayouts.firstWhere((e) => e.layout == layout);

/// Tỉ lệ khung xuất (width / height).
enum CanvasAspect {
  square(1.0, '1:1'),
  portrait(0.8, '4:5'),
  classic(0.75, '3:4');

  const CanvasAspect(this.value, this.label);

  final double value;
  final String label;
}

/// Kết quả tính vùng hiển thị của 2 ảnh trong khung.
///
/// Với split/diagonal: [firstClip]/[secondClip] là polygon clip (null = rect
/// đầy đủ khung), [firstRect]/[secondRect] là rect chứa ảnh.
/// Với PiP: ảnh thứ nhất phủ toàn khung, ảnh thứ hai nằm trong [secondRect].
/// [divider] là đoạn line để vẽ gutter đen (nếu có).
class DuoRegions {
  const DuoRegions({
    required this.firstRect,
    required this.secondRect,
    this.firstClip,
    this.secondClip,
    this.divider,
    this.extraCells = const [],
  });

  final Rect firstRect;
  final Rect secondRect;
  final Path? firstClip;
  final Path? secondClip;
  final List<Offset>? divider;

  /// Panel phụ của template truyện tranh nhiều ô: (rect, true = ảnh thứ nhất).
  /// firstRect/secondRect vẫn là 2 ô chính chứa ảnh sau/trước.
  final List<(Rect, bool)> extraCells;
}

/// Tính vùng cho từng layout. [ratio] (0.3..0.7) chỉ áp dụng cho split.
DuoRegions computeRegions(Size size, DuoLayout layout, double ratio) {
  final w = size.width;
  final h = size.height;
  final full = Offset.zero & size;

  switch (layout) {
    case DuoLayout.splitVertical:
      final x = w * ratio;
      return DuoRegions(
        firstRect: Rect.fromLTWH(0, 0, x, h),
        secondRect: Rect.fromLTWH(x, 0, w - x, h),
        divider: [Offset(x, 0), Offset(x, h)],
      );
    case DuoLayout.splitHorizontal:
      final y = h * ratio;
      return DuoRegions(
        firstRect: Rect.fromLTWH(0, 0, w, y),
        secondRect: Rect.fromLTWH(0, y, w, h - y),
        divider: [Offset(0, y), Offset(w, y)],
      );
    case DuoLayout.diagonalSlash:
      // Đường chia từ dưới-trái (0,h) lên trên-phải (w,0).
      final firstPath = Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(0, h)
        ..close();
      final secondPath = Path()
        ..moveTo(w, 0)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      return DuoRegions(
        firstRect: full,
        secondRect: full,
        firstClip: firstPath,
        secondClip: secondPath,
        divider: [Offset(0, h), Offset(w, 0)],
      );
    case DuoLayout.diagonalBackslash:
      // Đường chia từ trên-trái (0,0) xuống dưới-phải (w,h).
      final firstPath = Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h)
        ..close();
      final secondPath = Path()
        ..moveTo(0, 0)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      return DuoRegions(
        firstRect: full,
        secondRect: full,
        firstClip: firstPath,
        secondClip: secondPath,
        divider: [const Offset(0, 0), Offset(w, h)],
      );
    case DuoLayout.pipTopLeft:
    case DuoLayout.pipTopRight:
    case DuoLayout.pipBottomLeft:
    case DuoLayout.pipBottomRight:
      final insetW = w * 0.38;
      final insetH = insetW * 4 / 3;
      const margin = 14.0;
      final dx = (layout == DuoLayout.pipTopLeft || layout == DuoLayout.pipBottomLeft)
          ? margin
          : w - insetW - margin;
      final dy = (layout == DuoLayout.pipTopLeft || layout == DuoLayout.pipTopRight)
          ? margin
          : h - insetH - margin;
      return DuoRegions(
        firstRect: full,
        secondRect: Rect.fromLTWH(dx, dy, insetW, insetH),
      );
    case DuoLayout.comicPage3:
      // Ô wide-shot trên (ảnh sau), dưới: close-up cam trước trái + crop ảnh sau phải.
      const g = 10.0; // gutter trắng giữa các ô
      final topH = h * 0.55;
      final bw = (w - g) / 2;
      final bottomH = h - topH - g;
      return DuoRegions(
        firstRect: Rect.fromLTWH(0, 0, w, topH),
        secondRect: Rect.fromLTWH(0, topH + g, bw, bottomH),
        extraCells: [
          (Rect.fromLTWH(bw + g, topH + g, bw, bottomH), true),
        ],
      );
    case DuoLayout.comicPage4:
      // Lưới 2x2 so le: sau-trái-trên / trước-phải-trên / trước-trái-dưới / sau-phải-dưới.
      const g = 10.0;
      final cw = (w - g) / 2;
      final ch = (h - g) / 2;
      return DuoRegions(
        firstRect: Rect.fromLTWH(0, 0, cw, ch),
        secondRect: Rect.fromLTWH(cw + g, 0, cw, ch),
        extraCells: [
          (Rect.fromLTWH(0, ch + g, cw, ch), false),
          (Rect.fromLTWH(cw + g, ch + g, cw, ch), true),
        ],
      );
  }
}

/// Xoay vector [v] một góc [radians] — dùng để quy đổi delta pan của sticker
/// đang bị xoay về hệ toạ độ canvas.
Offset rotateOffset(Offset v, double radians) {
  final c = math.cos(radians);
  final s = math.sin(radians);
  return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
}
