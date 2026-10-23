import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Composant de base pour les animations de chargement squelette (Skeleton Loader)
class AppShimmer extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!),
      highlightColor: highlightColor ?? (isDark ? Colors.grey[700]! : Colors.grey[100]!),
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }
}

/// Boîte squelette rectangulaire ou circulaire avec coins arrondis
class AppShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const AppShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  const AppShimmerBox.circular({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(borderRadius)
            : null,
      ),
    );
  }
}

/// Squelette de chargement pour la carte POI / Lieu
class PoiCardShimmer extends StatelessWidget {
  const PoiCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const AppShimmerBox(width: 44, height: 44, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmerBox(width: 140, height: 16),
                      SizedBox(height: 6),
                      AppShimmerBox(width: 90, height: 12),
                    ],
                  ),
                ),
                const AppShimmerBox(width: 50, height: 20),
              ],
            ),
            const SizedBox(height: 16),
            const AppShimmerBox(width: double.infinity, height: 110, borderRadius: 16),
            const SizedBox(height: 14),
            Row(
              children: const [
                AppShimmerBox(width: 70, height: 28, borderRadius: 20),
                SizedBox(width: 8),
                AppShimmerBox(width: 60, height: 28, borderRadius: 20),
                SizedBox(width: 8),
                AppShimmerBox(width: 60, height: 28, borderRadius: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Squelette de chargement pour la liste des modes de déplacement (Moto, Voiture, etc.)
class RouteModeShimmer extends StatelessWidget {
  const RouteModeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const AppShimmerBox(width: 48, height: 48, borderRadius: 12),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmerBox(width: 100, height: 16),
                      SizedBox(height: 6),
                      AppShimmerBox(width: 80, height: 12),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    AppShimmerBox(width: 50, height: 16),
                    SizedBox(height: 6),
                    AppShimmerBox(width: 40, height: 12),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
