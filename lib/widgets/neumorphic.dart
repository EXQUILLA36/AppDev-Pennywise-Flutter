import 'package:flutter/material.dart';
import '../utils/constants.dart';

class NeumorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  const NeumorphicCard({
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.radius = 15,
    this.color = AppColors.surface,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).scaffoldBackgroundColor;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(153),
            offset: const Offset(8, 8),
            blurRadius: 3,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white.withAlpha(8),
            offset: const Offset(-8, -8),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

class NeumorphicButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double radius;
  const NeumorphicButton({
    required this.child,
    required this.onTap,
    this.radius = 12,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(140),
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Colors.white.withAlpha(5),
              offset: const Offset(-6, -6),
              blurRadius: 12,
            )
          ],
        ),
        child: DefaultTextStyle(style: const TextStyle(color: AppColors.foreground), child: child),
      ),
    );
  }
}
