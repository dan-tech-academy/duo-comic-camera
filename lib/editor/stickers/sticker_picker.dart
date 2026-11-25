import 'package:flutter/material.dart';

import '../../theme/comic_theme.dart';
import '../editor_controller.dart';
import 'sticker_art.dart';
import 'sticker_model.dart';

/// Bottom sheet "hộp sticker": grid catalogue, chạm để thả vào canvas.
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
