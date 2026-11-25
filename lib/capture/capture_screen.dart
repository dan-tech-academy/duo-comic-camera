import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../editor/editor_screen.dart';
import '../editor/stickers/sticker_art.dart';
import '../editor/stickers/sticker_model.dart';
import '../theme/comic_theme.dart';

/// Màn chụp Duo: chụp shot 1 (camera sau), app tự lật sang camera trước,
/// chụp shot 2 -> mở editor. Cho phép lật camera thủ công và chụp lại
/// từng shot.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  CameraLensDirection? _currentLens;
  FlashMode _flashMode = FlashMode.auto;

  bool _initializing = true;
  bool _permissionDenied = false;
  bool _capturing = false;
  bool _showBurst = false;
  String? _error;

  XFile? _rearShot;
  XFile? _frontShot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed && _currentLens != null) {
      final desc = _cameras.firstWhere((c) => c.lensDirection == _currentLens);
      _initCamera(desc);
    }
  }

  Future<void> _setup() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _permissionDenied = true;
        _initializing = false;
      });
      return;
    }
    try {
      _cameras = await availableCameras();
    } catch (e) {
      setState(() {
        _error = '$e';
        _initializing = false;
      });
      return;
    }
    if (_cameras.isEmpty) {
      setState(() {
        _error = 'Không tìm thấy camera nào!';
        _initializing = false;
      });
      return;
    }
    final initial = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    await _initCamera(initial);
  }

  Future<void> _initCamera(CameraDescription desc) async {
    final old = _controller;
    setState(() {
      _controller = null;
      _initializing = true;
    });
    await old?.dispose();
    final controller = CameraController(
      desc,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
    } catch (e) {
      setState(() {
        _error = '$e';
        _initializing = false;
      });
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _currentLens = desc.lensDirection;
      _initializing = false;
    });
  }

  CameraDescription _cameraFor(CameraLensDirection lens) => _cameras.firstWhere(
        (c) => c.lensDirection == lens,
        orElse: () => _cameras.first,
      );

  Future<void> _flip() async {
    if (_currentLens == null || _cameras.length < 2) return;
    final target = _currentLens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await _initCamera(_cameraFor(target));
  }

  Future<void> _snap() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final shot = await controller.takePicture();
      if (_currentLens == CameraLensDirection.front) {
        _frontShot = shot;
      } else {
        _rearShot = shot;
      }
      if (_rearShot != null && _frontShot != null) {
        await _openEditor();
      } else {
        // Tự lật sang camera còn thiếu cho shot tiếp theo.
        final missing = _rearShot == null
            ? CameraLensDirection.back
            : CameraLensDirection.front;
        setState(() => _showBurst = true);
        unawaited(
          Future.delayed(const Duration(milliseconds: 1100), () {
            if (mounted) setState(() => _showBurst = false);
          }),
        );
        await _initCamera(_cameraFor(missing));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chụp lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _openEditor() async {
    final rearBytes = await _rearShot!.readAsBytes();
    final frontBytes = await _frontShot!.readAsBytes();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(rearBytes: rearBytes, frontBytes: frontBytes),
      ),
    );
    // Quay lại từ editor -> bắt đầu phiên chụp mới.
    setState(() {
      _rearShot = null;
      _frontShot = null;
    });
  }

  Future<void> _retake(bool rear) async {
    setState(() {
      if (rear) {
        _rearShot = null;
      } else {
        _frontShot = null;
      }
    });
    final needed = rear ? CameraLensDirection.back : CameraLensDirection.front;
    if (_currentLens != needed) {
      await _initCamera(_cameraFor(needed));
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = switch (_flashMode) {
      FlashMode.auto => FlashMode.always,
      FlashMode.always => FlashMode.off,
      _ => FlashMode.auto,
    };
    await controller.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ComicColors.paper,
      body: HalftoneBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                flashMode: _flashMode,
                onToggleFlash: _controller == null ? null : _toggleFlash,
                onFlip: _cameras.length < 2 ? null : _flip,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    width: double.infinity,
                    decoration: ComicTheme.panel(
                      color: ComicColors.ink,
                      borderWidth: 4,
                      radius: 14,
                      shadowOffset: const Offset(5, 5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: _buildPreviewBody(),
                    ),
                  ),
                ),
              ),
              _DuoProgress(
                rearShot: _rearShot,
                frontShot: _frontShot,
                onRetake: _retake,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Column(
                  children: [
                    const Text(
                      'Chụp 2 shot: camera sau + camera trước!',
                      style: TextStyle(
                        fontFamily: ComicTheme.bodyFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SnapButton(
                      busy: _capturing,
                      enabled: _controller != null && !_initializing,
                      onTap: _snap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBody() {
    if (_permissionDenied) {
      return _PermissionPanel(
        onRetry: () {
          setState(() {
            _permissionDenied = false;
            _initializing = true;
          });
          _setup();
        },
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Oops! $_error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: ComicTheme.bodyFont,
              fontWeight: FontWeight.w700,
              color: ComicColors.white,
            ),
          ),
        ),
      );
    }
    final controller = _controller;
    if (_initializing || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: ComicColors.yellow),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cover-crop preview vào khung comic: CameraPreview tự xử lý rotation,
        // ta chỉ cần size child đủ lớn để phủ khung rồi crop phần thừa.
        final boxAspect = constraints.maxWidth / constraints.maxHeight;
        final previewAspect = 1 / controller.value.aspectRatio; // portrait w/h
        late final double w, h;
        if (previewAspect <= boxAspect) {
          w = constraints.maxWidth;
          h = w / previewAspect;
        } else {
          h = constraints.maxHeight;
          w = h * previewAspect;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: CameraPreview(controller),
                ),
              ),
            ),
            if (_showBurst)
              Center(
                child: Transform.scale(
                  scale: 1.4,
                  child: const StickerArt(
                    spec: StickerSpec(
                      kind: StickerKind.burst,
                      text: 'TIẾP!',
                      color: 0xFFFFC312,
                      accent: 0xFFFF4757,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.flashMode,
    required this.onToggleFlash,
    required this.onFlip,
  });

  final FlashMode flashMode;
  final VoidCallback? onToggleFlash;
  final VoidCallback? onFlip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Text('DUO CAM!', style: ComicTheme.actionWord(size: 32)),
          const Spacer(),
          _RoundIconButton(
            icon: switch (flashMode) {
              FlashMode.always => Icons.flash_on,
              FlashMode.auto => Icons.flash_auto,
              _ => Icons.flash_off,
            },
            onTap: onToggleFlash,
          ),
          const SizedBox(width: 10),
          _RoundIconButton(icon: Icons.flip_camera_android, onTap: onFlip),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: onTap == null ? ComicColors.white.withValues(alpha: 0.4) : ComicColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: ComicColors.ink, width: 2.5),
          boxShadow: const [
            BoxShadow(color: ComicColors.ink, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Icon(icon, size: 20, color: ComicColors.ink),
      ),
    );
  }
}

/// Hai slot thumbnail cho shot sau/trước; chạm slot đã chụp để chụp lại.
class _DuoProgress extends StatelessWidget {
  const _DuoProgress({
    required this.rearShot,
    required this.frontShot,
    required this.onRetake,
  });

  final XFile? rearShot;
  final XFile? frontShot;
  final Future<void> Function(bool rear) onRetake;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Slot(
            label: 'CAM SAU',
            number: '1',
            shot: rearShot,
            onRetake: () => onRetake(true),
          ),
          const SizedBox(width: 16),
          Text('+', style: ComicTheme.actionWord(size: 34, color: ComicColors.red)),
          const SizedBox(width: 16),
          _Slot(
            label: 'CAM TRƯỚC',
            number: '2',
            shot: frontShot,
            onRetake: () => onRetake(false),
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.label,
    required this.number,
    required this.shot,
    required this.onRetake,
  });

  final String label;
  final String number;
  final XFile? shot;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final filled = shot != null;
    return GestureDetector(
      onTap: filled ? onRetake : null,
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(5),
        decoration: ComicTheme.panel(
          color: filled ? ComicColors.white : ComicColors.paper,
          borderWidth: 2.5,
          radius: 10,
          shadowOffset: const Offset(3, 3),
        ),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: filled
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(shot!.path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                          ),
                          const Positioned(
                            right: 2,
                            bottom: 2,
                            child: Icon(Icons.refresh, size: 16, color: ComicColors.white),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Text(
                        number,
                        style: ComicTheme.actionWord(
                          size: 30,
                          color: ComicColors.ink.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 3),
            Text(
              filled ? '$label • chụp lại' : label,
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

class _SnapButton extends StatefulWidget {
  const _SnapButton({required this.busy, required this.enabled, required this.onTap});

  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_SnapButton> createState() => _SnapButtonState();
}

class _SnapButtonState extends State<_SnapButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !widget.busy;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? ComicColors.red : ComicColors.red.withValues(alpha: 0.35),
            border: Border.all(color: ComicColors.ink, width: 5),
            boxShadow: const [
              BoxShadow(color: ComicColors.ink, offset: Offset(0, 5), blurRadius: 0),
            ],
          ),
          child: Center(
            child: widget.busy
                ? const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: ComicColors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    'SNAP!',
                    style: ComicTheme.actionWord(size: 22, color: ComicColors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PermissionPanel extends StatelessWidget {
  const _PermissionPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CẦN CAMERA!',
              style: ComicTheme.actionWord(size: 30, color: ComicColors.yellow),
            ),
            const SizedBox(height: 8),
            const Text(
              'App cần quyền camera để chụp duo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: ComicTheme.bodyFont,
                fontWeight: FontWeight.w700,
                color: ComicColors.white,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ComicButton(
                  label: 'Thử lại',
                  fontSize: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  onPressed: onRetry,
                ),
                const SizedBox(width: 10),
                ComicButton(
                  label: 'Mở Settings',
                  fontSize: 15,
                  color: ComicColors.cyan,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  onPressed: openAppSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
