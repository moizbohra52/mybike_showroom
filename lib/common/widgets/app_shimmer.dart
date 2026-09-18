import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_dimensions.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';

/// Skeleton placeholder widget with subtle pulsing animation.
class AppShimmer extends StatefulWidget {
  const AppShimmer({
    this.width,
    this.height,
    this.borderRadius,
    super.key,
  }) : isCircle = false;

  const AppShimmer.circle({
    required double size,
    super.key,
  })  : width = size,
        height = size,
        borderRadius = null,
        isCircle = true;

  const AppShimmer.line({
    this.width = double.infinity,
    this.height = 14.0,
    super.key,
  })  : borderRadius = null,
        isCircle = false;

  const AppShimmer.card({
    this.width = double.infinity,
    this.height = 100.0,
    super.key,
  })  : borderRadius = null,
        isCircle = false;

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isCircle;

  @override
  State<AppShimmer> createState() => AppShimmerState();
}

/// Public state for [AppShimmer] handling pulse animation.
class AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> opacityAnimation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    unawaited(controller.repeat(reverse: true));
    opacityAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);

    return AnimatedBuilder(
      animation: opacityAnimation,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: opacityAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: palette.hover,
              shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: widget.isCircle
                  ? null
                  : (widget.borderRadius ?? BorderRadius.circular(AppDimensions.radiusMd)),
            ),
          ),
        );
      },
    );
  }
}
