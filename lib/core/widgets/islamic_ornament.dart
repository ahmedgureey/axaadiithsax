import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme_colors.dart';

/// A small eight-pointed star (Rub el Hizb style) drawn with two rotated
/// squares. Purely decorative — excluded from semantics.
class IslamicStar extends StatelessWidget {
  const IslamicStar({super.key, this.size = 14, this.color, this.filled = false});

  final double size;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _StarPainter(color ?? context.appColors.gold, filled),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color, this.filled);
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..isAntiAlias = true;
    final c = size.center(Offset.zero);
    final half = size.width * 0.34;
    for (final angle in [0.0, math.pi / 4]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color || old.filled != filled;
}

/// Thin gold divider with a star in the middle — used to separate the Arabic
/// text from its translation or to head a section.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key, this.verticalPadding = AppSpacing.sm});

  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 1, color: context.appColors.gold.withValues(alpha: 0.45)));
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Row(
        children: [
          line,
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: IslamicStar(size: 12),
          ),
          line,
        ],
      ),
    );
  }
}

/// Very faint repeating star lattice for hero headers (e.g. daily hadith).
/// Keep it behind content; it is decorative only.
class IslamicPatternBackground extends StatelessWidget {
  const IslamicPatternBackground({super.key, required this.child, this.color, this.tile = 36});

  final Widget child;
  final Color? color;
  final double tile;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LatticePainter(color ?? context.appColors.patternStroke, tile),
      child: child,
    );
  }
}

class _LatticePainter extends CustomPainter {
  _LatticePainter(this.color, this.tile);
  final Color color;
  final double tile;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final half = tile * 0.22;
    for (double y = tile / 2; y < size.height + tile; y += tile) {
      for (double x = tile / 2; x < size.width + tile; x += tile) {
        for (final angle in [0.0, math.pi / 4]) {
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(angle);
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2), paint);
          canvas.restore();
        }
      }
    }
  }

  @override
  bool shouldRepaint(_LatticePainter old) => old.color != color || old.tile != tile;
}
