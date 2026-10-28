import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';

/// Pilules de filtres d'accès rapide multi-sélection conformes à la spécification FASO NAV
class FasoCategoryPills extends ConsumerWidget {
  const FasoCategoryPills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategories = ref.watch(selectedCategoriesProvider);
    final count = ref.watch(placesCountProvider);

    return SizedBox(
      height: 44,
      child: categoriesAsync.when(
        data: (categories) {
          // Filtrer selon isFilter
          final filterableCats = categories.where((c) => c.isFilter).toList();
          final hasFilters = selectedCategories.isNotEmpty;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: filterableCats.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                // Bouton "Tous les lieux" (actif quand aucun filtre spécifique n'est coché)
                final isAllSelected = !hasFilters;
                return GestureDetector(
                  onTap: () {
                    if (hasFilters) {
                      ref.read(selectedCategoriesProvider.notifier).clear();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isAllSelected ? const Color(0xFF0F766E) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isAllSelected ? Colors.white : const Color(0xFF334155),
                        width: isAllSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAllSelected ? Icons.place_rounded : Icons.clear_all_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAllSelected
                              ? (count > 0 ? 'Tous ($count)' : 'Tous les lieux')
                              : '$count lieu${count > 1 ? "x" : ""}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (hasFilters) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                        ],
                      ],
                    ),
                  ),
                );
              }

              final cat = filterableCats[index - 1];
              final isSelected = selectedCategories.contains(cat.slug);

              // Couleurs dynamiques pilotées par la table categories
              final catColor = cat.displayColor;
              final Color backgroundColor;
              final Color foregroundColor;
              final Border border;

              if (isSelected) {
                backgroundColor = catColor;
                foregroundColor = Colors.white;
                border = Border.all(color: Colors.white, width: 2);
              } else {
                backgroundColor = Colors.white.withValues(alpha: 0.95);
                foregroundColor = const Color(0xFF1F2937);
                border = Border.all(color: const Color(0xFFE5E7EB));
              }

              final IconData icon = isSelected ? Icons.check_circle_rounded : cat.iconData;
              final Color iconColor = isSelected ? Colors.white : catColor;
              final label = cat.labelIn('fr');

              return GestureDetector(
                onTap: () {
                  ref.read(selectedCategoriesProvider.notifier).toggle(cat.slug);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(22),
                    border: border,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: iconColor),
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: foregroundColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) => Container(
            width: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
        error: (error, stack) => const SizedBox.shrink(),
      ),
    );
  }
}
