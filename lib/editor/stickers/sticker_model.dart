import 'package:flutter/painting.dart';

/// Loại sticker comic.
enum StickerKind {
  burst, // starburst + action word (POW!, BOOM!...)
  bubbleRect, // bong bóng chat bo góc có đuôi, text editable
  bubbleOval, // bong bóng oval
  cloud, // đám mây suy nghĩ
  star,
  bolt, // tia sét
  heart,
  smiley,
}

/// Mô tả nghệ thuật của sticker: hình dạng + màu + text mặc định.
class StickerSpec {
  const StickerSpec({
    required this.kind,
    this.text = '',
    required this.color,
    required this.accent,
  });

  final StickerKind kind;
  final String text;
  final int color; // màu nền chính
  final int accent; // màu chữ / chi tiết

  StickerSpec copyWith({String? text}) =>
      StickerSpec(kind: kind, text: text ?? this.text, color: color, accent: accent);
}

/// Sticker đã đặt lên canvas: vị trí (tâm, theo fraction 0..1 của canvas),
/// scale và rotation. Lưu theo fraction để export ở mọi độ phân giải giống
/// hệt preview.
class StickerPlacement {
  StickerPlacement({
    required this.id,
    required this.spec,
    required this.center,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  final String id;
  StickerSpec spec;
  Offset center;
  double scale;
  double rotation;

  static const double minScale = 0.3;
  static const double maxScale = 4.0;
}

/// Catalogue sticker có sẵn trong hộp sticker.
const List<StickerSpec> kStickerCatalog = [
  StickerSpec(kind: StickerKind.burst, text: 'POW!', color: 0xFFFFC312, accent: 0xFFFF4757),
  StickerSpec(kind: StickerKind.burst, text: 'BOOM!', color: 0xFFFF4757, accent: 0xFFFFFFFF),
  StickerSpec(kind: StickerKind.burst, text: 'ZAP!', color: 0xFF2E86DE, accent: 0xFFFFC312),
  StickerSpec(kind: StickerKind.burst, text: 'WOW!', color: 0xFFFF6B9D, accent: 0xFFFFFFFF),
  StickerSpec(kind: StickerKind.burst, text: 'OMG!', color: 0xFF8C7AE6, accent: 0xFFFFFFFF),
  StickerSpec(kind: StickerKind.burst, text: 'SNAP!', color: 0xFF10AC84, accent: 0xFFFFFFFF),
  StickerSpec(kind: StickerKind.bubbleRect, text: 'Hé lô!', color: 0xFFFFFFFF, accent: 0xFF16161A),
  StickerSpec(kind: StickerKind.bubbleOval, text: 'Haha!', color: 0xFFFFFFFF, accent: 0xFF16161A),
  StickerSpec(kind: StickerKind.cloud, text: 'Hmm...', color: 0xFFFFFFFF, accent: 0xFF16161A),
  StickerSpec(kind: StickerKind.star, color: 0xFFFFC312, accent: 0xFF16161A),
  StickerSpec(kind: StickerKind.bolt, color: 0xFFF79F1F, accent: 0xFF16161A),
  StickerSpec(kind: StickerKind.heart, color: 0xFFFF4757, accent: 0xFF16161A),
  StickerSpec(kind: StickerKind.smiley, color: 0xFFFFC312, accent: 0xFF16161A),
];
