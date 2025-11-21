import 'package:flutter/material.dart';

/// Animated checkmark widget for save button success state
class SaveButtonSuccessCheckmark extends StatefulWidget {
  final Duration duration;
  final Color color;

  const SaveButtonSuccessCheckmark({
    super.key,
    this.duration = const Duration(milliseconds: 600),
    this.color = Colors.white,
  });

  @override
  State<SaveButtonSuccessCheckmark> createState() =>
      _SaveButtonSuccessCheckmarkState();
}

class _SaveButtonSuccessCheckmarkState
    extends State<SaveButtonSuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: CustomPaint(
            size: const Size(20, 20),
            painter: _CheckmarkPainter(
              progress: _checkAnimation.value,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (progress > 0) {
      final path = Path();
      // Draw checkmark: bottom-left to center, then center to top-right
      path.moveTo(size.width * 0.2, size.height * 0.5);
      path.lineTo(size.width * 0.45, size.height * 0.75);
      path.lineTo(size.width * 0.8, size.height * 0.25);

      final metrics = path.computeMetrics().first;
      final pathLength = metrics.length;

      final pathToDraw = Path();
      pathToDraw.addPath(
        path,
        Offset.zero,
      );

      canvas.drawPath(
        pathToDraw,
        paint..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

