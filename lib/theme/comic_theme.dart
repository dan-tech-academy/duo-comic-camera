import 'package:flutter/material.dart';

/// Bảng màu comic: mực đen, giấy kem, màu spotlight rực rỡ.
class ComicColors {
  ComicColors._();

  static const ink = Color(0xFF16161A);
  static const paper = Color(0xFFFFF6E3);
  static const white = Color(0xFFFFFFFF);
  static const red = Color(0xFFFF4757);
  static const yellow = Color(0xFFFFC312);
  static const blue = Color(0xFF2E86DE);
  static const cyan = Color(0xFF0ABDE3);
  static const pink = Color(0xFFFF6B9D);
  static const green = Color(0xFF10AC84);
  static const orange = Color(0xFFF79F1F);
  static const purple = Color(0xFF8C7AE6);
}

class ComicTheme {
  ComicTheme._();

  static const displayFont = 'Bangers';
  static const bodyFont = 'ComicNeue';

  static ThemeData build() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: ComicColors.paper,
      colorScheme: const ColorScheme.light(
        primary: ComicColors.red,
        secondary: ComicColors.yellow,
        surface: ComicColors.paper,
        onSurface: ComicColors.ink,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: bodyFont,
        bodyColor: ComicColors.ink,
        displayColor: ComicColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ComicColors.paper,
        foregroundColor: ComicColors.ink,
        elevation: 0,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ComicColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w700,
          color: ComicColors.white,
        ),
      ),
    );
  }

  /// Viền đen dày + bóng cứng kiểu panel truyện tranh.
  static BoxDecoration panel({
    Color color = ComicColors.white,
    double borderWidth = 3,
    double radius = 10,
    Offset shadowOffset = const Offset(4, 4),
  }) {
    return BoxDecoration(
      color: color,
      border: Border.all(color: ComicColors.ink, width: borderWidth),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: ComicColors.ink,
          offset: shadowOffset,
          blurRadius: 0,
        ),
      ],
    );
  }

  static TextStyle actionWord({
    double size = 28,
    Color color = ComicColors.ink,
    double letterSpacing = 1.5,
  }) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

/// Nút bấm phong cách comic: chữ Bangers in hoa, viền đen, bóng cứng,
/// nhấn xuống thì lõm vào.
class ComicButton extends StatefulWidget {
  const ComicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = ComicColors.yellow,
    this.textColor = ComicColors.ink,
    this.fontSize = 22,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final double fontSize;
  final EdgeInsets padding;
  final bool enabled;

  @override
  State<ComicButton> createState() => _ComicButtonState();
}

class _ComicButtonState extends State<ComicButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveOn = widget.enabled && widget.onPressed != null;
    return GestureDetector(
      onTapDown: effectiveOn ? (_) => setState(() => _pressed = true) : null,
      onTapUp: effectiveOn
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed!();
            }
          : null,
      onTapCancel: effectiveOn ? () => setState(() => _pressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(_pressed ? 3.0 : 0.0, _pressed ? 3.0 : 0.0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: effectiveOn ? widget.color : widget.color.withValues(alpha: 0.4),
          border: Border.all(color: ComicColors.ink, width: 3),
          borderRadius: BorderRadius.circular(10),
          boxShadow: _pressed
              ? const []
              : const [
                  BoxShadow(
                    color: ComicColors.ink,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        child: Text(
          widget.label.toUpperCase(),
          style: ComicTheme.actionWord(size: widget.fontSize, color: widget.textColor),
        ),
      ),
    );
  }
}

/// Panel truyện tranh: container viền đen + bóng cứng.
class ComicPanel extends StatelessWidget {
  const ComicPanel({
    super.key,
    required this.child,
    this.color = ComicColors.white,
    this.padding = const EdgeInsets.all(12),
    this.radius = 10,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: ComicTheme.panel(color: color, radius: radius),
      child: child,
    );
  }
}

/// Nền chấm halftone trang trí (dot pattern của truyện in).
class HalftoneBackground extends StatelessWidget {
  const HalftoneBackground({super.key, required this.child, this.dotColor});

  final Widget child;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HalftonePainter(dotColor ?? ComicColors.ink.withValues(alpha: 0.06)),
      child: child,
    );
  }
}

class _HalftonePainter extends CustomPainter {
  _HalftonePainter(this.dotColor);

  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    const step = 26.0;
    for (var y = step / 2; y < size.height; y += step) {
      final row = (y / step).floor();
      final xOffset = row.isEven ? 0.0 : step / 2;
      for (var x = xOffset + step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_HalftonePainter old) => old.dotColor != dotColor;
}
