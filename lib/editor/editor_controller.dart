import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'filters/comic_filters.dart';
import 'layouts.dart';
import 'stickers/sticker_model.dart';

typedef FilterRunner = Future<FilterResult> Function(FilterJob job);

Future<FilterResult> defaultFilterRunner(FilterJob job) => compute(processPhoto, job);

/// State của màn editor: layout duo, filter, sticker. Preview chạy filter
/// pixel-level trong isolate và cache theo (ảnh, filter) nên chuyển filter
/// đã xem là instant.
class EditorController extends ChangeNotifier {
  EditorController({
    required this.rearBytes,
    required this.frontBytes,
    this.filterRunner = defaultFilterRunner,
    this.maxPreviewDim = 1280,
  });

  /// JPEG bytes thô chụp từ camera sau / camera trước.
  final Uint8List rearBytes;
  final Uint8List frontBytes;
  final FilterRunner filterRunner;
  final int maxPreviewDim;

  DuoLayout layout = DuoLayout.splitVertical;
  double splitRatio = 0.5;
  CanvasAspect aspect = CanvasAspect.portrait;
  bool swapped = false;
  ComicFilterType filter = ComicFilterType.none;
  bool processing = false;

  final List<StickerPlacement> stickers = [];
  String? selectedStickerId;
  int _stickerCounter = 0;

  /// Khi true, chrome chọn sticker (khung xanh + nút edit/xoá) bị ẩn —
  /// dùng trong lúc export để UI edit không lọt vào ảnh PNG.
  bool exportMode = false;

  void setExportMode(bool value) {
    exportMode = value;
    notifyListeners();
  }

  final Map<String, FilterResult> _cache = {};
  FilterResult? _rearResult;
  FilterResult? _frontResult;

  FilterResult? get rearResult => _rearResult;
  FilterResult? get frontResult => _frontResult;

  /// Kết quả của ảnh "thứ nhất" trong layout (sau swap nếu user đã swap).
  FilterResult? get firstResult => swapped ? _frontResult : _rearResult;
  FilterResult? get secondResult => swapped ? _rearResult : _frontResult;

  Future<void> init() => _applyFilter(ComicFilterType.none);

  String _key(bool rear, ComicFilterType f) => '${rear ? 'rear' : 'front'}_${f.name}';

  Future<void> setFilter(ComicFilterType type) => _applyFilter(type);

  Future<void> _applyFilter(ComicFilterType type) async {
    filter = type;
    final rearCached = _cache[_key(true, type)];
    final frontCached = _cache[_key(false, type)];
    if (rearCached != null && frontCached != null) {
      _rearResult = rearCached;
      _frontResult = frontCached;
      notifyListeners();
      return;
    }
    processing = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        filterRunner(FilterJob(bytes: rearBytes, maxDim: maxPreviewDim, filter: type)),
        filterRunner(FilterJob(bytes: frontBytes, maxDim: maxPreviewDim, filter: type)),
      ]);
      _cache[_key(true, type)] = results[0];
      _cache[_key(false, type)] = results[1];
      // User có thể đã chuyển filter khác trong lúc chờ.
      if (filter == type) {
        _rearResult = results[0];
        _frontResult = results[1];
      }
    } finally {
      processing = false;
      notifyListeners();
    }
  }

  void setLayout(DuoLayout value) {
    layout = value;
    notifyListeners();
  }

  void setSplitRatio(double value) {
    splitRatio = value.clamp(0.25, 0.75);
    notifyListeners();
  }

  void setAspect(CanvasAspect value) {
    aspect = value;
    notifyListeners();
  }

  void swap() {
    swapped = !swapped;
    notifyListeners();
  }

  void addSticker(StickerSpec spec) {
    final placement = StickerPlacement(
      id: 'st_${++_stickerCounter}',
      spec: spec,
      center: const Offset(0.5, 0.5),
    );
    stickers.add(placement);
    selectedStickerId = placement.id;
    notifyListeners();
  }

  void removeSticker(String id) {
    stickers.removeWhere((s) => s.id == id);
    if (selectedStickerId == id) selectedStickerId = null;
    notifyListeners();
  }

  void selectSticker(String? id) {
    selectedStickerId = id;
    notifyListeners();
  }

  void moveSticker(String id, Offset center) {
    final s = stickers.firstWhere((e) => e.id == id);
    s.center = Offset(
      center.dx.clamp(-0.1, 1.1),
      center.dy.clamp(-0.1, 1.1),
    );
    notifyListeners();
  }

  void transformSticker(String id, {required double scale, required double rotation}) {
    final s = stickers.firstWhere((e) => e.id == id);
    s.scale = scale.clamp(StickerPlacement.minScale, StickerPlacement.maxScale);
    s.rotation = rotation;
    notifyListeners();
  }

  void setStickerText(String id, String text) {
    final s = stickers.firstWhere((e) => e.id == id);
    s.spec = s.spec.copyWith(text: text);
    notifyListeners();
  }
}
