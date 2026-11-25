import 'package:duo_comic_camera/editor/editor_screen.dart';
import 'package:duo_comic_camera/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Integration test chạy trên thiết bị/emulator thật: capture duo thật bằng
/// camera rồi verify gesture pinch-zoom + rotate của sticker — thứ không
/// inject được bằng adb trên emulator.
///
/// Trước khi chạy: adb shell pm grant com.dantech0xff.duo_comic_camera \
///   android.permission.CAMERA
/// flutter test integration_test -d \<device\>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('duo capture thật → pinch/rotate sticker trong editor', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Chờ camera khởi tạo xong (nút SNAP! xuất hiện).
    await _waitFor(tester, find.text('SNAP!'));

    // Shot 1: camera sau → app auto-flip sang camera trước.
    await tester.tap(find.text('SNAP!'));
    await tester.pump(const Duration(milliseconds: 300));
    await _waitFor(tester, find.text('SNAP!'), timeout: const Duration(seconds: 20));

    // Shot 2: camera trước → editor mở.
    await tester.tap(find.text('SNAP!'));
    await tester.pump(const Duration(milliseconds: 300));
    await _waitFor(tester, find.text('DUO COMIC!'), timeout: const Duration(seconds: 20));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Thêm sticker POW! vào canvas.
    await tester.tap(find.text('Sticker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MỞ HỘP STICKER!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('POW!'));
    await tester.pumpAndSettle();
    expect(find.text('1 sticker'), findsOneWidget);

    final controller = (tester.state(find.byType(EditorScreen)) as dynamic)
        .controller as dynamic;
    expect(controller.stickers.length, 1);
    final before = controller.stickers.first;
    expect(before.scale, 1.0);
    expect(before.rotation, 0.0);

    final center = tester.getCenter(find.text('POW!'));

    // --- PINCH OUT: 2 ngón xa dần → scale tăng ---
    final pinchIn1 = await tester.startGesture(center + const Offset(-30, 0));
    final pinchIn2 = await tester.startGesture(center + const Offset(30, 0));
    for (var i = 1; i <= 6; i++) {
      final d = 30.0 + i * 15.0; // 45 → 120 mỗi bên
      await pinchIn1.moveTo(center + Offset(-d, 0));
      await pinchIn2.moveTo(center + Offset(d, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await pinchIn1.up();
    await pinchIn2.up();
    await tester.pumpAndSettle();

    final afterPinch = controller.stickers.first;
    expect(
      afterPinch.scale,
      greaterThan(1.5),
      reason: 'pinch-out phải scale sticker lên (scale=${afterPinch.scale})',
    );
    expect(afterPinch.scale, lessThanOrEqualTo(4.0));

    // --- ROTATE: 2 ngón xoay quanh tâm (đường nối quay ~90°) ---
    final rotBefore = controller.stickers.first.rotation;
    final rot1 = await tester.startGesture(center + const Offset(-80, 0));
    final rot2 = await tester.startGesture(center + const Offset(80, 0));
    for (var i = 1; i <= 8; i++) {
      final t = i / 8;
      // Ngón trái đi từ (-80,0) → (0,-80), ngón phải từ (80,0) → (0,80):
      // đường nối 2 ngón xoay từ ngang sang dọc = 90°.
      await rot1.moveTo(center + Offset(-80 * (1 - t), -80 * t));
      await rot2.moveTo(center + Offset(80 * (1 - t), 80 * t));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await rot1.up();
    await rot2.up();
    await tester.pumpAndSettle();

    final afterRotate = controller.stickers.first;
    expect(
      afterRotate.rotation.abs(),
      greaterThan(0.5),
      reason: 'xoay 2 ngón phải đổi rotation (rotation=${afterRotate.rotation})',
    );
    expect(afterRotate.rotation, isNot(rotBefore));
  });
}

/// Poll finder cho tới khi xuất hiện hoặc hết timeout (mỗi vòng pump 200ms).
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timeout chờ $finder sau $timeout');
}
