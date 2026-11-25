import 'package:flutter/material.dart';

import '../../theme/comic_theme.dart';
import '../editor_controller.dart';
import '../layouts.dart';
import 'sticker_art.dart';
import 'sticker_model.dart';

/// Layer sticker nằm trong canvas export: kéo để di chuyển, pinch để scale,
/// xoay bằng 2 ngón. Vị trí lưu theo fraction của canvas nên export ở mọi
/// độ phân giải đều giống preview.
class StickerLayer extends StatelessWidget {
  const StickerLayer({super.key, required this.controller, required this.size});

  final EditorController controller;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => controller.selectSticker(null),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final placement in controller.stickers)
              _StickerView(
                key: ValueKey(placement.id),
                placement: placement,
                controller: controller,
                canvasSize: size,
              ),
          ],
        ),
      ),
    );
  }
}

class _StickerView extends StatefulWidget {
  const _StickerView({
    super.key,
    required this.placement,
    required this.controller,
    required this.canvasSize,
  });

  final StickerPlacement placement;
  final EditorController controller;
  final Size canvasSize;

  @override
  State<_StickerView> createState() => _StickerViewState();
}

class _StickerViewState extends State<_StickerView> {
  double _baseScale = 1;
  double _baseRotation = 0;

  StickerPlacement get placement => widget.placement;

  void _onScaleStart(ScaleStartDetails details) {
    widget.controller.selectSticker(placement.id);
    _baseScale = placement.scale;
    _baseRotation = placement.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final controller = widget.controller;
    final newRotation = _baseRotation + details.rotation;
    final newScale = _baseScale * details.scale;
    controller.transformSticker(placement.id, scale: newScale, rotation: newRotation);

    // focalPointDelta ở hệ toạ độ local của sticker (đã xoay/scale) — quy đổi
    // về hệ canvas: nhân scale hiện tại rồi xoay theo rotation hiện tại.
    final local = details.focalPointDelta;
    if (local != Offset.zero) {
      final canvasDelta = rotateOffset(local, placement.rotation) * placement.scale;
      final dx = canvasDelta.dx / widget.canvasSize.width;
      final dy = canvasDelta.dy / widget.canvasSize.height;
      controller.moveSticker(
        placement.id,
        placement.center + Offset(dx, dy),
      );
    }
  }

  bool get _hasEditableText => const {
        StickerKind.bubbleRect,
        StickerKind.bubbleOval,
        StickerKind.cloud,
        StickerKind.burst,
      }.contains(placement.spec.kind);

  Future<void> _editText() async {
    final controller = widget.controller;
    final initial = placement.spec.text;
    final textCtrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ComicColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: ComicColors.ink, width: 3),
        ),
        title: Text('Viết gì đi!', style: ComicTheme.actionWord(size: 24)),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Text trong bong bóng...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          ComicButton(
            label: 'OK!',
            fontSize: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            onPressed: () => Navigator.pop(ctx, textCtrl.text.trim()),
          ),
        ],
      ),
    );
    if (result != null) {
      // Burst là action word kiểu comic → auto uppercase cho đúng chất.
      final text = placement.spec.kind == StickerKind.burst
          ? result.toUpperCase()
          : result;
      controller.setStickerText(placement.id, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.selectedStickerId == placement.id &&
        !widget.controller.exportMode;
    final art = selected
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: ComicColors.blue, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: StickerArt(spec: placement.spec),
              ),
              // Badge đặt lùi vào trong (-4) thay vì nhô ra ngoài (-16):
              // tâm badge nằm trong bounds của sticker nên hit-test chạm được
              // đúng vị trí hiển thị.
              Positioned(
                top: -4,
                right: -4,
                child: _Badge(
                  icon: Icons.close,
                  color: ComicColors.red,
                  onTap: () => widget.controller.removeSticker(placement.id),
                ),
              ),
              if (_hasEditableText)
                Positioned(
                  top: -4,
                  left: -4,
                  child: _Badge(
                    icon: Icons.edit,
                    color: ComicColors.blue,
                    onTap: _editText,
                  ),
                ),
            ],
          )
        : StickerArt(spec: placement.spec);

    return Align(
      alignment: Alignment(
        (placement.center.dx * 2 - 1).clamp(-1.0, 1.0),
        (placement.center.dy * 2 - 1).clamp(-1.0, 1.0),
      ),
      child: Transform.rotate(
        angle: placement.rotation,
        child: Transform.scale(
          scale: placement.scale,
          child: GestureDetector(
            onTap: () => widget.controller.selectSticker(placement.id),
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: art,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: ComicColors.ink, width: 2),
        ),
        child: Icon(icon, size: 16, color: ComicColors.white),
      ),
    );
  }
}
