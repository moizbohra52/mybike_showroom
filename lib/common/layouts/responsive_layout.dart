import 'package:flutter/material.dart';
import 'package:mybike_showroom/common/layouts/breakpoint.dart';

/// Builds a subtree that adapts to the current [Breakpoint].
///
/// Prefer this over scattering `MediaQuery` checks inside screens: the builder
/// receives the resolved breakpoint, so UI code states its intent once per
/// layout instead of repeating width comparisons.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.builder,
    this.compactBuilder,
    this.mediumBuilder,
    this.expandedBuilder,
    super.key,
  });

  /// Receives the resolved breakpoint (used when one builder handles all sizes).
  final Widget Function(BuildContext context, Breakpoint breakpoint) builder;

  /// Optional per-breakpoint overrides; fall back to [builder].
  final Widget Function(BuildContext context, Breakpoint breakpoint)?
  compactBuilder;
  final Widget Function(BuildContext context, Breakpoint breakpoint)?
  mediumBuilder;
  final Widget Function(BuildContext context, Breakpoint breakpoint)?
  expandedBuilder;

  @override
  Widget build(BuildContext context) {
    final Breakpoint breakpoint = context.breakpoint;
    return switch (breakpoint) {
      Breakpoint.compact => (compactBuilder ?? builder)(context, breakpoint),
      Breakpoint.medium => (mediumBuilder ?? builder)(context, breakpoint),
      Breakpoint.expanded ||
      Breakpoint.large => (expandedBuilder ?? builder)(context, breakpoint),
    };
  }
}

/// Constrains content width on very wide windows so forms and tables never
/// stretch uncomfortably (see AppDimensions.contentMaxWidth).
class ContentWidthLimiter extends StatelessWidget {
  const ContentWidthLimiter({
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double? maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? MediaQuery.sizeOf(context).width,
        ),
        child: child,
      ),
    );
  }
}
