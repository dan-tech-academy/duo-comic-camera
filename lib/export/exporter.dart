import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Export canvas editor ra PNG: capture RepaintBoundary ở pixelRatio cao
/// (~2000px chiều rộng) rồi lưu gallery / share.
class Exporter {
  Exporter._();

  static Future<Uint8List> capturePng(
    GlobalKey boundaryKey, {
    double targetWidth = 2000,
  }) async {
    final context = boundaryKey.currentContext;
    if (context == null) {
      throw StateError('Canvas chưa sẵn sàng');
    }
    final boundary = context.findRenderObject() as RenderRepaintBoundary;
    final logicalWidth = boundary.size.width;
    final pixelRatio = (targetWidth / logicalWidth).clamp(1.0, 6.0);
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Không capture được canvas');
    }
    return byteData.buffer.asUint8List();
  }

  static Future<File> _writeTemp(Uint8List bytes, {String ext = '.png'}) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/duo_comic_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    return file.writeAsBytes(bytes, flush: true);
  }

  /// Lưu vào gallery. Throw [GalException] nếu user từ chối permission.
  static Future<void> saveToGallery(Uint8List bytes, {String ext = '.png'}) async {
    if (!await Gal.hasPermission()) {
      final granted = await Gal.requestPermission();
      if (!granted) {
        throw StateError('Không có quyền lưu ảnh vào thư viện');
      }
    }
    final file = await _writeTemp(bytes, ext: ext);
    await Gal.putImage(file.path, album: 'DuoComic');
  }

  static Future<void> share(Uint8List bytes, {String ext = '.png'}) async {
    final file = await _writeTemp(bytes, ext: ext);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Duo Comic Camera!',
      ),
    );
  }
}
