import 'package:duo_comic_camera/editor/layouts.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(100, 200);

  group('computeRegions', () {
    test('splitVertical ratio 0.5 chia đôi', () {
      final r = computeRegions(size, DuoLayout.splitVertical, 0.5);
      expect(r.firstRect, const Rect.fromLTWH(0, 0, 50, 200));
      expect(r.secondRect, const Rect.fromLTWH(50, 0, 50, 200));
      expect(r.divider, [const Offset(50, 0), const Offset(50, 200)]);
      expect(r.firstClip, isNull);
    });

    test('splitVertical ratio 0.7 lệch 70/30', () {
      final r = computeRegions(size, DuoLayout.splitVertical, 0.7);
      expect(r.firstRect.width, 70);
      expect(r.secondRect.width, 30);
    });

    test('splitHorizontal ratio 0.5 chia đôi theo chiều ngang', () {
      final r = computeRegions(size, DuoLayout.splitHorizontal, 0.5);
      expect(r.firstRect, const Rect.fromLTWH(0, 0, 100, 100));
      expect(r.secondRect, const Rect.fromLTWH(0, 100, 100, 100));
      expect(r.divider, [const Offset(0, 100), const Offset(100, 100)]);
    });

    test('diagonalSlash: clip tam giác + divider từ dưới-trái lên trên-phải', () {
      final r = computeRegions(size, DuoLayout.diagonalSlash, 0.5);
      expect(r.firstClip, isNotNull);
      expect(r.secondClip, isNotNull);
      expect(r.divider, [const Offset(0, 200), const Offset(100, 0)]);
      expect(r.firstRect, const Rect.fromLTWH(0, 0, 100, 200));
    });

    test('diagonalBackslash: divider từ trên-trái xuống dưới-phải', () {
      final r = computeRegions(size, DuoLayout.diagonalBackslash, 0.5);
      expect(r.divider, [const Offset(0, 0), const Offset(100, 200)]);
    });

    test('pipTopLeft: inset ở góc trái trên, background phủ full', () {
      final r = computeRegions(size, DuoLayout.pipTopLeft, 0.5);
      expect(r.firstRect, const Rect.fromLTWH(0, 0, 100, 200));
      expect(r.secondRect.left, 14.0);
      expect(r.secondRect.top, 14.0);
      expect(r.secondRect.width, closeTo(38, 0.01));
    });

    test('pipBottomRight: inset ở góc phải dưới', () {
      final r = computeRegions(size, DuoLayout.pipBottomRight, 0.5);
      expect(r.secondRect.right, closeTo(100 - 14, 0.01));
      expect(r.secondRect.bottom, closeTo(200 - 14, 0.01));
    });
  });

  group('rotateOffset', () {
    test('xoay 90 độ', () {
      final out = rotateOffset(const Offset(1, 0), 3.14159265 / 2);
      expect(out.dx, closeTo(0, 1e-6));
      expect(out.dy, closeTo(1, 1e-6));
    });

    test('xoay 0 độ giữ nguyên', () {
      final out = rotateOffset(const Offset(3, -2), 0);
      expect(out, const Offset(3, -2));
    });
  });

  test('layoutInfoOf đánh đúng nhóm split/diagonal/pip', () {
    expect(layoutInfoOf(DuoLayout.splitVertical).isSplit, isTrue);
    expect(layoutInfoOf(DuoLayout.diagonalSlash).isDiagonal, isTrue);
    expect(layoutInfoOf(DuoLayout.pipTopLeft).isPip, isTrue);
    expect(kDuoLayouts.length, 8);
  });
}
