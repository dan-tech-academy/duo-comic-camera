import 'package:flutter/material.dart';

import '../../theme/comic_theme.dart';
import '../editor_controller.dart';
import 'sticker_art.dart';
import 'sticker_model.dart';

/// Hỏi user muốn viết chữ gì cho burst custom; trả null nếu huỷ/rỗng.
Future<String?> _askCustomWord(BuildContext context) {
  final textCtrl = TextEditingController();
  return showDialog<String>(
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
        maxLines: 1,
        maxLength: 16,
        decoration: const InputDecoration(
          hintText: 'VD: ĐỈNH!, XỊN!...',
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
}

/// Bottom sheet "hộp sticker": grid catalogue, chạm để thả vào canvas.
/// Ô đầu tiên "TỰ VIẾT!" cho user gõ action word riêng cho burst.
Future<void> openStickerPicker(BuildContext context, EditorController controller) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ComicColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: ComicColors.ink, width: 3),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Text('HỘP STICKER!', style: ComicTheme.actionWord(size: 26)),
                const Spacer(),
                const Text(
                  'Kéo • pinch • xoay',
                  style: TextStyle(
                    fontFamily: ComicTheme.bodyFont,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                InkWell(
                  onTap: () async {
                    final word = await _askCustomWord(context);
                    if (word == null || word.isEmpty) return;
                    controller.addSticker(
                      const StickerSpec(
                        kind: StickerKind.burst,
                        text: '',
                        color: 0xFF0ABDE3,
                        accent: 0xFFFFFFFF,
                      ).copyWith(text: word.toUpperCase()),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    decoration: ComicTheme.panel(
                      color: ComicColors.yellow,
                      borderWidth: 2,
                      radius: 8,
                      shadowOffset: const Offset(2, 2),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 26, color: ComicColors.ink),
                          SizedBox(height: 4),
                          Text(
                            'TỰ VIẾT!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
                for (final spec in kStickerCatalog)
                  InkWell(
                    onTap: () {
                      controller.addSticker(spec);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: ComicTheme.panel(
                        color: ComicColors.white,
                        borderWidth: 2,
                        radius: 8,
                        shadowOffset: const Offset(2, 2),
                      ),
                      child: Center(
                        child: FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: StickerArt(spec: spec),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
