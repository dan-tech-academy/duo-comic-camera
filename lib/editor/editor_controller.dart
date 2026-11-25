import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'filters/comic_filters.dart';
import 'layouts.dart';
import 'stickers/sticker_model.dart';

typedef FilterRunner = Future<FilterResult> Function(FilterJob job);

Future<FilterResult> defaultFilterRunner(FilterJob job) => compute(processPhoto, job);

/// Snapshot toàn bộ state editor — cho undo/redo.
class _EditorSnapshot {
  _EditorSnapshot({
    required this.layout,
    required this.splitRatio,
    required this.aspect,
    required this.swapped,
    required this.filter,
    required this.intensity,
    required this.stickers,
    required this.selectedId,
  });

  final DuoLayout layout;
  final double splitRatio;
  final CanvasAspect aspect;
  final bool swapped;
  final ComicFilterType filter;
  final double intensity;
  final List<StickerPlacement> stickers;
  final String? selectedId;
}

/// State của màn editor: layout duo, filter, sticker. Preview chạy filter
/// pixel-level trong isolate và cache theo (ảnh, filter, intensity) nên
/// chuyển filter đã xem là instant. Undo/redo theo snapshot (tối đa 60 bước).
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

  /// Độ mạnh filter hiện tại (0..1). Chỉ áp khi filter != none.
  double filterIntensity = 1.0;
  bool processing = false;

  final List<_EditorSnapshot> _undo = [];
  final List<_EditorSnapshot> _redo = [];
  DateTime _lastHistoryPush = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastThrottledOp;
  String? _inFlightKey;
  int _processingCount = 0;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

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

  /// Bucket intensity 0..10 cho cache key + render. Filter Gốc bỏ qua
  /// intensity trong processPhoto nên bucket cố định 0 để cache hit xuyên suốt.
  int _bucket(ComicFilterType f) =>
      f == ComicFilterType.none ? 0 : (filterIntensity * 10).round();

  String _key(bool rear, ComicFilterType f) =>
      '${rear ? 'rear' : 'front'}_${f.name}_${_bucket(f)}';

  // ---- Undo/redo ----

  _EditorSnapshot _capture() => _EditorSnapshot(
        layout: layout,
        splitRatio: splitRatio,
        aspect: aspect,
        swapped: swapped,
        filter: filter,
        intensity: filterIntensity,
        stickers: stickers.map((s) => s.copy()).toList(),
        selectedId: selectedStickerId,
      );

  /// Push snapshot TRƯỚC mutation. [throttle] dành cho thao tác liên tục
  /// (kéo slider/drag sticker): chỉ push nếu cùng loại thao tác [op] và cách
  /// lần trước >= 400ms để history không bị flood bởi từng pixel của gesture.
  /// Redo luôn bị clear kể cả khi skip — mọi edit mới đều vô hiệu redo.
  void _pushHistory({bool throttle = false, String? op}) {
    _redo.clear();
    if (throttle &&
        op == _lastThrottledOp &&
        DateTime.now().difference(_lastHistoryPush) <
            const Duration(milliseconds: 400)) {
      return;
    }
    _lastThrottledOp = throttle ? op : null;
    _lastHistoryPush = DateTime.now();
    _undo.add(_capture());
    if (_undo.length > 60) _undo.removeAt(0);
  }

  Future<void> _restoreSnapshot(_EditorSnapshot s) async {
    layout = s.layout;
    splitRatio = s.splitRatio;
    aspect = s.aspect;
    swapped = s.swapped;
    filterIntensity = s.intensity;
    stickers
      ..clear()
      ..addAll(s.stickers.map((e) => e.copy()));
    selectedStickerId = s.selectedId;
    await _applyFilter(s.filter);
    notifyListeners();
  }

  Future<void> undo() async {
    if (_undo.isEmpty) return;
    _redo.add(_capture());
    await _restoreSnapshot(_undo.removeLast());
  }

  Future<void> redo() async {
    if (_redo.isEmpty) return;
    _undo.add(_capture());
    await _restoreSnapshot(_redo.removeLast());
  }

  // ---- Filter ----

  Future<void> setFilter(ComicFilterType type) {
    if (type != filter) _pushHistory();
    return _applyFilter(type);
  }

  void setFilterIntensity(double value) {
    final v = value.clamp(0.05, 1.0);
    if ((v - filterIntensity).abs() < 0.001) return;
    _pushHistory(throttle: true, op: 'intensity');
    filterIntensity = v;
    if (filter != ComicFilterType.none) {
      _applyFilter(filter);
    } else {
      notifyListeners();
    }
  }

  Future<void> _applyFilter(ComicFilterType type) async {
    filter = type;
    final bucket = _bucket(type);
    final rearCached = _cache[_key(true, type)];
    final frontCached = _cache[_key(false, type)];
    if (rearCached != null && frontCached != null) {
      _rearResult = rearCached;
      _frontResult = frontCached;
      notifyListeners();
      return;
    }
    // Job y hệt đang chạy rồi — không spawn thêm isolate trong cùng bucket.
    final requestKey = '${type.name}_$bucket';
    if (_inFlightKey == requestKey) return;
    _inFlightKey = requestKey;
    _processingCount++;
    processing = true;
    notifyListeners();
    try {
      // Render đúng ở mức bucket để pixel trong cache luôn khớp key.
      final intensity = type == ComicFilterType.none ? 1.0 : bucket / 10;
      final jobs = [
        FilterJob(
          bytes: rearBytes,
          maxDim: maxPreviewDim,
          filter: type,
          intensity: intensity,
        ),
        FilterJob(
          bytes: frontBytes,
          maxDim: maxPreviewDim,
          filter: type,
          intensity: intensity,
        ),
      ];
      final results = await Future.wait(jobs.map(filterRunner));
      _cache[_key(true, type)] = results[0];
      _cache[_key(false, type)] = results[1];
      // User có thể đã chuyển filter/intensity khác trong lúc chờ.
      if (filter == type && _bucket(type) == bucket) {
        _rearResult = results[0];
        _frontResult = results[1];
      }
    } finally {
      if (_inFlightKey == requestKey) _inFlightKey = null;
      _processingCount--;
      processing = _processingCount > 0;
      notifyListeners();
    }
  }

  void setLayout(DuoLayout value) {
    if (value != layout) _pushHistory();
    layout = value;
    notifyListeners();
  }

  void setSplitRatio(double value) {
    _pushHistory(throttle: true, op: 'split');
    splitRatio = value.clamp(0.25, 0.75);
    notifyListeners();
  }

  void setAspect(CanvasAspect value) {
    if (value != aspect) _pushHistory();
    aspect = value;
    notifyListeners();
  }

  void swap() {
    _pushHistory();
    swapped = !swapped;
    notifyListeners();
  }

  void addSticker(StickerSpec spec) {
    _pushHistory();
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
    if (stickers.any((s) => s.id == id)) _pushHistory();
    stickers.removeWhere((s) => s.id == id);
    if (selectedStickerId == id) selectedStickerId = null;
    notifyListeners();
  }

  void clearStickers() {
    if (stickers.isEmpty) return;
    _pushHistory();
    stickers.clear();
    selectedStickerId = null;
    notifyListeners();
  }

  void selectSticker(String? id) {
    selectedStickerId = id;
    notifyListeners();
  }

  void moveSticker(String id, Offset center) {
    _pushHistory(throttle: true, op: 'move');
    final s = stickers.firstWhere((e) => e.id == id);
    s.center = Offset(
      center.dx.clamp(-0.1, 1.1),
      center.dy.clamp(-0.1, 1.1),
    );
    notifyListeners();
  }

  void transformSticker(String id, {required double scale, required double rotation}) {
    _pushHistory(throttle: true, op: 'transform');
    final s = stickers.firstWhere((e) => e.id == id);
    s.scale = scale.clamp(StickerPlacement.minScale, StickerPlacement.maxScale);
    s.rotation = rotation;
    notifyListeners();
  }

  void setStickerText(String id, String text) {
    _pushHistory();
    final s = stickers.firstWhere((e) => e.id == id);
    s.spec = s.spec.copyWith(text: text);
    notifyListeners();
  }
}
