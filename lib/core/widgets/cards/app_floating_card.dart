import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/core/theme/app_shadows.dart';
import 'package:qvgestion_mobile/core/theme/app_spacing.dart';

/// Conteneur flottant réutilisable avec coins arrondis et ombre douce
class AppFloatingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final List<BoxShadow>? shadows;
  final Border? border;
  final VoidCallback? onTap;

  const AppFloatingCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
    this.backgroundColor,
    this.borderRadius,
    this.shadows,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(borderRadius ?? AppSpacing.radiusXl),
        boxShadow: shadows ?? AppShadows.medium,
        border: border,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
