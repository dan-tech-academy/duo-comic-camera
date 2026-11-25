import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/comic_theme.dart';
import 'sticker_model.dart';

/// Widget hiển thị 1 sticker theo [spec]. Kích thước tự co theo nội dung
/// (burst/bubble) hoặc cố định 96 logical px (shape) — scale của sticker do
/// layer bên ngoài điều khiển bằng Transform.
class StickerArt extends StatelessWidget {
  const StickerArt({super.key, required this.spec});

  final StickerSpec spec;

  @override
  Widget build(BuildContext context) {
    switch (spec.kind) {
      case StickerKind.burst:
        return CustomPaint(
          painter: _BurstPainter(color: Color(spec.color)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
            child: Transform.rotate(
              angle: -0.18,
              child: Text(
                spec.text,
                style: ComicTheme.actionWord(size: 34, color: Color(spec.accent)),
              ),
            ),
          ),
        );
      case StickerKind.bubbleRect:
      case StickerKind.bubbleOval:
      case StickerKind.cloud:
        return CustomPaint(
          painter: _BubblePainter(kind: spec.kind, color: Color(spec.color)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220, minWidth: 48),
              child: Text(
                spec.text.isEmpty ? '...' : spec.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: ComicTheme.bodyFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: Color(spec.accent),
                ),
              ),
            ),
          ),
        );
      case StickerKind.star:
        return _FixedShape(painterFactory: (s) => _StarPainter(Color(spec.color)), size: 88);
      case StickerKind.bolt:
        return _FixedShape(painterFactory: (s) => _BoltPainter(Color(spec.color)), size: 88);
      case StickerKind.heart:
        return _FixedShape(painterFactory: (s) => _HeartPainter(Color(spec.color)), size: 88);
      case StickerKind.smiley:
        return _FixedShape(painterFactory: (s) => _SmileyPainter(Color(spec.color), Color(spec.accent)), size: 88);
    }
  }
}

class _FixedShape extends StatelessWidget {
  const _FixedShape({required this.painterFactory, required this.size});

  final CustomPainter Function(double) painterFactory;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: painterFactory(size),
    );
  }
}

double _strokeFor(Size size) => (size.shortestSide / 28).clamp(2.0, 4.5);

/// Ngôi sao nhiều cánh (starburst) — background của action word.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.color});

  final Color color;
  static const int spikes = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.62;
    final path = Path();
    for (var i = 0; i < spikes * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / spikes;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = ComicColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeFor(size)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.color != color;
}

/// Bong bóng chat (rect/oval) hoặc đám mây suy nghĩ, có đuôi.
class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.kind, required this.color});

  final StickerKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tailH = 16.0;
    final body = Rect.fromLTWH(0, 0, size.width, size.height - tailH);
    final ink = Paint()
      ..color = ComicColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fill = Paint()..color = color;

    if (kind == StickerKind.bubbleRect) {
      final rrect = RRect.fromRectAndRadius(body, const Radius.circular(14));
      canvas.drawRRect(rrect, fill);
      _tailTriangle(canvas, body, fill, ink);
      canvas.drawRRect(rrect, ink);
    } else if (kind == StickerKind.bubbleOval) {
      canvas.drawOval(body, fill);
      _tailTriangle(canvas, body, fill, ink);
      canvas.drawOval(body, ink);
    } else {
      // Đám mây: ellipse dẹt + đuôi là 3 vòng tròn nhỏ dần.
      final flat = Rect.fromLTWH(0, 0, size.width, (size.height - tailH) * 0.94);
      canvas.drawOval(flat, fill);
      final cx = size.width * 0.28;
      final baseY = size.height - tailH;
      final circles = [
        (Offset(cx, baseY + 2), 7.0),
        (Offset(cx - 12, baseY + 10), 4.6),
        (Offset(cx - 21, baseY + 15), 2.8),
      ];
      for (final (c, r) in circles) {
        canvas.drawCircle(c, r, fill);
        canvas.drawCircle(c, r, ink);
      }
      canvas.drawOval(flat, ink);
    }
  }

  void _tailTriangle(Canvas canvas, Rect body, Paint fill, Paint ink) {
    final tail = Path()
      ..moveTo(body.left + body.width * 0.30, body.bottom - 2)
      ..lineTo(body.left + body.width * 0.16, body.bottom + 15)
      ..lineTo(body.left + body.width * 0.45, body.bottom - 2)
      ..close();
    canvas.drawPath(tail, fill);
    canvas.drawPath(tail, ink);
    // Che phần viền thừa ở đỉnh đuôi.
    canvas.drawRect(
      Rect.fromLTWH(body.left + body.width * 0.28, body.bottom - 4, body.width * 0.2, 4),
      fill,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.kind != kind || old.color != color;
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.45;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = ComicColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeFor(size)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

class _BoltPainter extends CustomPainter {
  _BoltPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.62, 0)
      ..lineTo(w * 0.18, h * 0.58)
      ..lineTo(w * 0.45, h * 0.58)
      ..lineTo(w * 0.34, h)
      ..lineTo(w * 0.82, h * 0.38)
      ..lineTo(w * 0.52, h * 0.38)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = ComicColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeFor(size)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BoltPainter old) => old.color != color;
}

class _HeartPainter extends CustomPainter {
  _HeartPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.92)
      ..cubicTo(w * -0.1, h * 0.55, w * 0.12, h * 0.02, w * 0.5, h * 0.28)
      ..cubicTo(w * 0.88, h * 0.02, w * 1.1, h * 0.55, w * 0.5, h * 0.92)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = ComicColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeFor(size)
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.color != color;
}

class _SmileyPainter extends CustomPainter {
  _SmileyPainter(this.color, this.accent);

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    canvas.drawCircle(center, r, Paint()..color = color);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = ComicColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeFor(size),
    );
    final eyePaint = Paint()..color = accent;
    final eyeR = r * 0.13;
    canvas.drawCircle(center + Offset(-r * 0.35, -r * 0.22), eyeR, eyePaint);
    canvas.drawCircle(center + Offset(r * 0.35, -r * 0.22), eyeR, eyePaint);
    final smile = Path()
      ..moveTo(center.dx - r * 0.45, center.dy + r * 0.12)
      ..quadraticBezierTo(center.dx, center.dy + r * 0.62, center.dx + r * 0.45, center.dy + r * 0.12);
    canvas.drawPath(
      smile,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeFor(size)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SmileyPainter old) => old.color != color || old.accent != accent;
}
