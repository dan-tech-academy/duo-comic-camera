import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/comic_theme.dart';
import 'editor_controller.dart';
import 'layouts.dart';
import 'stickers/sticker_layer.dart';

/// Canvas duo: 2 ảnh xếp theo layout + gutter comic + sticker layer.
/// Toàn bộ nằm trong RepaintBoundary để export pixel-perfect.
class DuoCanvas extends StatelessWidget {
  const DuoCanvas({super.key, required this.controller, required this.boundaryKey});

  final EditorController controller;
  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: AspectRatio(
        aspectRatio: controller.aspect.value,
        child: Container(
          decoration: BoxDecoration(
            color: ComicColors.white,
            border: Border.all(color: ComicColors.ink, width: 4),
          ),
          child: ClipRect(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final first = controller.firstResult;
                final second = controller.secondResult;
                if (first == null || second == null) {
                  return const Center(
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(color: ComicColors.red),
                    ),
                  );
                }
                final regions = computeRegions(size, controller.layout, controller.splitRatio);
                final info = layoutInfoOf(controller.layout);
                return Stack(
                  children: [
                    _PhotoRegion(
                      rect: regions.firstRect,
                      clip: regions.firstClip,
                      bytes: first.pngBytes,
                    ),
                    if (info.isPip)
                      _PipInset(rect: regions.secondRect, bytes: second.pngBytes)
                    else
                      _PhotoRegion(
                        rect: regions.secondRect,
                        clip: regions.secondClip,
                        bytes: second.pngBytes,
                      ),
                    if (regions.divider != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _DividerPainter(regions.divider!),
                        ),
                      ),
                    if (!info.isPip && !info.isDiagonal)
                      Positioned.fill(
                        child: CustomPaint(painter: _PanelFramePainter(regions)),
                      ),
                    StickerLayer(controller: controller, size: size),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Ảnh crop-fill trong 1 vùng (rect hoặc polygon clip cho layout chéo).
class _PhotoRegion extends StatelessWidget {
  const _PhotoRegion({required this.rect, required this.bytes, this.clip});

  final Rect rect;
  final Uint8List bytes;
  final Path? clip;

  @override
  Widget build(BuildContext context) {
    final image = SizedBox.expand(
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      ),
    );
    return Positioned.fromRect(
      rect: rect,
      child: clip == null ? ClipRect(child: image) : ClipPath(clipper: _StaticClipper(clip!), child: image),
    );
  }
}

class _StaticClipper extends CustomClipper<Path> {
  const _StaticClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_StaticClipper old) => old.path != path;
}

/// Ảnh nhỏ kiểu Picture-in-Picture với viền panel comic + bóng cứng.
class _PipInset extends StatelessWidget {
  const _PipInset({required this.rect, required this.bytes});

  final Rect rect;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: Container(
        decoration: ComicTheme.panel(
          color: ComicColors.white,
          borderWidth: 3,
          radius: 8,
          shadowOffset: const Offset(3, 3),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

/// Gutter comic: line trắng dày với lõi đen giữa 2 panel.
class _DividerPainter extends CustomPainter {
  const _DividerPainter(this.line);

  final List<Offset> line;

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()
      ..color = ComicColors.white
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.butt;
    final ink = Paint()
      ..color = ComicColors.ink
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(line[0], line[1], white);
    canvas.drawLine(line[0], line[1], ink);
  }

  @override
  bool shouldRepaint(_DividerPainter old) => old.line != line;
}

/// Viền đen quanh từng panel cho layout split — look khung truyện tranh.
class _PanelFramePainter extends CustomPainter {
  const _PanelFramePainter(this.regions);

  final DuoRegions regions;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ComicColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final rect in [regions.firstRect, regions.secondRect]) {
      canvas.drawRect(rect.deflate(1.5), paint);
    }
  }

  @override
  bool shouldRepaint(_PanelFramePainter old) => old.regions != regions;
}
