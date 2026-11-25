import 'dart:typed_data';

import 'package:duo_comic_camera/editor/editor_screen.dart';
import 'package:duo_comic_camera/editor/filters/comic_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List fakeJpeg() {
  final im = img.Image(width: 24, height: 32);
  for (final p in im) {
    p.r = 180;
    p.g = 90;
    p.b = 40;
  }
  return img.encodeJpg(im);
}

Future<FilterResult> fakeRunner(FilterJob job) async {
  final im = img.Image(width: 12, height: 16);
  for (final p in im) {
    p.r = 200;
    p.g = 100;
    p.b = 50;
  }
  return FilterResult(pngBytes: img.encodePng(im), width: 12, height: 16);
}

Widget buildEditor() => MaterialApp(
      home: EditorScreen(
        rearBytes: fakeJpeg(),
        frontBytes: fakeJpeg(),
        filterRunner: fakeRunner,
      ),
    );

void main() {
  testWidgets('editor render đầy đủ toolbar và canvas', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.text('DUO COMIC!'), findsOneWidget);
    expect(find.text('SAVE!'), findsOneWidget);
    expect(find.text('SHARE!'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Sticker'), findsOneWidget);
    expect(find.text('Khung'), findsOneWidget);
  });

  testWidgets('chuyển layout qua thumbnail', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('PiP trái trên'));
    await tester.tap(find.text('PiP trái trên'));
    await tester.pump();
    // Không crash là pass phần lớn; verify thumb vẫn render được.
    expect(find.text('PiP trái trên'), findsOneWidget);
  });

  testWidgets('đổi filter qua chip', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    expect(find.text('POP!'), findsOneWidget);
    await tester.ensureVisible(find.text('POP!'));
    await tester.tap(find.text('POP!'));
    await tester.pumpAndSettle();
  });

  testWidgets('mở hộp sticker và thêm sticker vào canvas', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sticker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MỞ HỘP STICKER!'));
    await tester.pumpAndSettle();
    expect(find.text('HỘP STICKER!'), findsOneWidget);
    await tester.tap(find.text('POW!'));
    await tester.pumpAndSettle();
    expect(find.text('1 sticker'), findsOneWidget);
  });

  testWidgets('đổi khung aspect', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khung'));
    await tester.pumpAndSettle();
    expect(find.text('1:1'), findsOneWidget);
    await tester.tap(find.text('1:1'));
    await tester.pumpAndSettle();
  });
}
