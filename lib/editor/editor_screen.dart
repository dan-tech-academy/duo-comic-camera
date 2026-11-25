import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../export/exporter.dart';
import '../export/gif_maker.dart';
import '../theme/comic_theme.dart';
import 'duo_canvas.dart';
import 'editor_controller.dart';
import 'filters/comic_filters.dart';
import 'layouts.dart';
import 'stickers/sticker_picker.dart';

enum _ToolTab { layout, filter, sticker, frame }

/// Màn editor: canvas duo ở giữa, toolbar comic bên dưới gồm
/// Layout / Filter / Sticker / Khung, nút SAVE! và SHARE!.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.rearBytes,
    required this.frontBytes,
    this.filterRunner,
  });

  final Uint8List rearBytes;
  final Uint8List frontBytes;

  /// Inject filter pipeline giả trong widget test (tránh spawn isolate).
  final FilterRunner? filterRunner;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _controller;
  final GlobalKey _boundaryKey = GlobalKey();
  _ToolTab _tab = _ToolTab.layout;
  bool _exporting = false;

  @visibleForTesting
  EditorController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _controller = EditorController(
      rearBytes: widget.rearBytes,
      frontBytes: widget.frontBytes,
      filterRunner: widget.filterRunner ?? defaultFilterRunner,
    );
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runExport(Future<void> Function(Uint8List bytes) action, String doneMessage) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    // Ẩn chrome chọn sticker (khung xanh + badge) trước khi capture để
    // UI edit không bị bake vào ảnh export; chờ 1 frame cho canvas render lại.
    _controller.setExportMode(true);
    // Nếu filter đang xử lý (ví dụ vừa kéo slider intensity), chờ xong để
    // capture đúng pixels mới nhất — không export ảnh của strength cũ.
    var waited = 0;
    while (_controller.processing && waited < 300) {
      await WidgetsBinding.instance.endOfFrame;
      waited++;
    }
    // Image.memory decode async: chờ thêm vài frame để ảnh mới decode xong
    // vào canvas trước khi capture (gaplessPlayback giữ pixel cũ trong lúc decode).
    for (var i = 0; i < 3; i++) {
      await WidgetsBinding.instance.endOfFrame;
    }
    try {
      final bytes = await Exporter.capturePng(_boundaryKey);
      await action(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(doneMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Oops! $e')),
        );
      }
    } finally {
      _controller.setExportMode(false);
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _save() => _runExport(
        Exporter.saveToGallery,
        'ĐÃ LƯU VÀO THƯ VIỆN!',
      );

  Future<void> _share() => _runExport(
        Exporter.share,
        'ĐÃ MỞ SHARE SHEET!',
      );

  /// Capture canvas → encode GIF comic (zoom-punch luân phiên 2 panel) → lưu gallery.
  Future<void> _saveGif() => _runExport((pngBytes) async {
        (double, double) focusA;
        (double, double) focusB;
        if (layoutInfoOf(_controller.layout).isDiagonal) {
          // Layout chéo: 2 panel cùng phủ khung (khác nhau ở clip tam giác)
          // nên rect.center trùng nhau — zoom về centroid của từng tam giác.
          final slash = _controller.layout == DuoLayout.diagonalSlash;
          focusA = slash ? (1 / 3, 1 / 3) : (2 / 3, 1 / 3);
          focusB = slash ? (2 / 3, 2 / 3) : (1 / 3, 2 / 3);
        } else {
          final regions = computeRegions(
            const Size(1000, 1000),
            _controller.layout,
            _controller.splitRatio,
          );
          final fa = regions.firstRect.center;
          final fb = regions.secondRect.center;
          focusA = (fa.dx / 1000, fa.dy / 1000);
          focusB = (fb.dx / 1000, fb.dy / 1000);
        }
        final gif = await encodeComicGif(GifJob(
          pngBytes: pngBytes,
          focusA: focusA,
          focusB: focusB,
        ));
        await Exporter.saveToGallery(gif, ext: '.gif');
      }, 'GIF COMIC ĐÃ LƯU!');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ComicColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ComicColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('DUO COMIC!', style: ComicTheme.actionWord(size: 30)),
        centerTitle: true,
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.undo, color: ComicColors.ink),
                  tooltip: 'Hoàn tác',
                  onPressed: _controller.canUndo ? _controller.undo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.redo, color: ComicColors.ink),
                  tooltip: 'Làm lại',
                  onPressed: _controller.canRedo ? _controller.redo : null,
                ),
              ],
            ),
          ),
        ],
      ),
      body: HalftoneBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          DuoCanvas(controller: _controller, boundaryKey: _boundaryKey),
                          if (_controller.processing)
                            ComicPanel(
                              color: ComicColors.white,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: ComicColors.red,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'ĐANG XỬ LÝ...',
                                    style: ComicTheme.actionWord(size: 18),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                _TabBar(
                  current: _tab,
                  onSelect: (tab) => setState(() => _tab = tab),
                ),
                SizedBox(
                  height: 132,
                  child: _ToolPanel(
                    tab: _tab,
                    controller: _controller,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ComicButton(
                          label: 'Save!',
                          color: ComicColors.yellow,
                          fontSize: 17,
                          onPressed: _exporting ? null : _save,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ComicButton(
                          label: 'GIF!',
                          color: ComicColors.pink,
                          fontSize: 17,
                          onPressed: _exporting ? null : _saveGif,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ComicButton(
                          label: 'Share!',
                          color: ComicColors.cyan,
                          fontSize: 17,
                          onPressed: _exporting ? null : _share,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onSelect});

  final _ToolTab current;
  final ValueChanged<_ToolTab> onSelect;

  static const _labels = {
    _ToolTab.layout: 'Layout',
    _ToolTab.filter: 'Filter',
    _ToolTab.sticker: 'Sticker',
    _ToolTab.frame: 'Khung',
  };

  static const _icons = {
    _ToolTab.layout: Icons.grid_view,
    _ToolTab.filter: Icons.auto_fix_high,
    _ToolTab.sticker: Icons.auto_awesome,
    _ToolTab.frame: Icons.crop,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final tab in _ToolTab.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(tab),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: current == tab ? ComicColors.yellow : ComicColors.white,
                    border: Border.all(color: ComicColors.ink, width: 2.5),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: current == tab
                        ? const []
                        : const [
                            BoxShadow(
                              color: ComicColors.ink,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                  ),
                  child: Column(
                    children: [
                      Icon(_icons[tab], size: 18, color: ComicColors.ink),
                      Text(
                        _labels[tab]!,
                        style: const TextStyle(
                          fontFamily: ComicTheme.bodyFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolPanel extends StatelessWidget {
  const _ToolPanel({required this.tab, required this.controller});

  final _ToolTab tab;
  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case _ToolTab.layout:
        return _LayoutPanel(controller: controller);
      case _ToolTab.filter:
        return _FilterPanel(controller: controller);
      case _ToolTab.sticker:
        return _StickerPanel(controller: controller);
      case _ToolTab.frame:
        return _FramePanel(controller: controller);
    }
  }
}

class _LayoutPanel extends StatelessWidget {
  const _LayoutPanel({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final info = layoutInfoOf(controller.layout);
    return Column(
      children: [
        SizedBox(
          height: 74,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final entry in kDuoLayouts)
                _LayoutThumb(
                  info: entry,
                  selected: entry.layout == controller.layout,
                  onTap: () => controller.setLayout(entry.layout),
                ),
              const SizedBox(width: 8),
              Center(
                child: ComicButton(
                  label: 'Swap!',
                  fontSize: 15,
                  color: ComicColors.pink,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  onPressed: controller.swap,
                ),
              ),
            ],
          ),
        ),
        if (info.isSplit)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Tỉ lệ',
                  style: TextStyle(
                    fontFamily: ComicTheme.bodyFont,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: ComicColors.red,
                      thumbColor: ComicColors.red,
                      overlayColor: ComicColors.red.withValues(alpha: 0.15),
                    ),
                    child: Slider(
                      value: controller.splitRatio,
                      min: 0.25,
                      max: 0.75,
                      onChanged: controller.setSplitRatio,
                    ),
                  ),
                ),
                Text(
                  '${(controller.splitRatio * 100).round()}/${(100 - controller.splitRatio * 100).round()}',
                  style: const TextStyle(
                    fontFamily: ComicTheme.bodyFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Thumbnail preview của layout: vẽ mini bằng chính computeRegions.
class _LayoutThumb extends StatelessWidget {
  const _LayoutThumb({required this.info, required this.selected, required this.onTap});

  final DuoLayoutInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: ComicTheme.panel(
          color: selected ? ComicColors.yellow : ComicColors.white,
          borderWidth: 2.5,
          radius: 8,
          shadowOffset: selected ? Offset.zero : const Offset(2, 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 34,
              height: 40,
              child: CustomPaint(
                painter: _LayoutMiniPainter(info.layout),
              ),
            ),
            Text(
              info.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: ComicTheme.bodyFont,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutMiniPainter extends CustomPainter {
  const _LayoutMiniPainter(this.layout);

  final DuoLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final regions = computeRegions(size, layout, 0.5);
    final red = Paint()..color = ComicColors.red;
    final blue = Paint()..color = ComicColors.blue;
    final ink = Paint()
      ..color = ComicColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    void fillRegion(Rect rect, Path? clip, Paint paint) {
      if (clip != null) {
        canvas.save();
        canvas.clipPath(clip);
        canvas.drawRect(rect, paint);
        canvas.restore();
      } else {
        canvas.drawRect(rect, paint);
      }
    }

    fillRegion(regions.firstRect, regions.firstClip, red);
    fillRegion(regions.secondRect, regions.secondClip, blue);
    for (final (rect, useFirst) in regions.extraCells) {
      canvas.drawRect(rect, useFirst ? red : blue);
    }
    if (layoutInfoOf(layout).isPip) {
      canvas.drawRect(regions.secondRect.deflate(0.75), ink);
    }
    canvas.drawRect(Offset.zero & size, ink);
  }

  @override
  bool shouldRepaint(_LayoutMiniPainter old) => old.layout != layout;
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final showIntensity = controller.filter != ComicFilterType.none;
    return Column(
      children: [
        if (showIntensity)
          SizedBox(
            height: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'ĐỘ MẠNH ${(controller.filterIntensity * 100).round()}%',
                    style: const TextStyle(
                      fontFamily: ComicTheme.bodyFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: const SliderThemeData(
                        trackHeight: 5,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: controller.filterIntensity,
                        min: 0.1, // khớp granularity bucket 10% của cache
                        max: 1.0,
                        activeColor: ComicColors.red,
                        inactiveColor: ComicColors.paper,
                        onChanged: controller.setFilterIntensity,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
        for (final filter in kComicFilters)
          GestureDetector(
            onTap: () => controller.setFilter(filter.type),
            child: Container(
              width: 100,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(8),
              decoration: ComicTheme.panel(
                color: controller.filter == filter.type ? ComicColors.cyan : ComicColors.white,
                borderWidth: 2.5,
                radius: 8,
                shadowOffset: controller.filter == filter.type ? Offset.zero : const Offset(2, 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    filter.label,
                    textAlign: TextAlign.center,
                    style: ComicTheme.actionWord(size: 16),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      filter.tagline,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: ComicTheme.bodyFont,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StickerPanel extends StatelessWidget {
  const _StickerPanel({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final count = controller.stickers.length;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: ComicButton(
              label: 'Mở hộp sticker!',
              color: ComicColors.orange,
              fontSize: 18,
              onPressed: () => openStickerPicker(context, controller),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count sticker',
                style: const TextStyle(
                  fontFamily: ComicTheme.bodyFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (count > 0)
                TextButton(
                  onPressed: controller.clearStickers,
                  child: const Text(
                    'Xoá hết',
                    style: TextStyle(
                      fontFamily: ComicTheme.bodyFont,
                      fontWeight: FontWeight.w700,
                      color: ComicColors.red,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FramePanel extends StatelessWidget {
  const _FramePanel({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final aspect in CanvasAspect.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: ComicButton(
                label: aspect.label,
                fontSize: 18,
                color: controller.aspect == aspect ? ComicColors.green : ComicColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                onPressed: () => controller.setAspect(aspect),
              ),
            ),
        ],
      ),
    );
  }
}
