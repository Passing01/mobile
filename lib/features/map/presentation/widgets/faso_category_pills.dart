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

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: filterableCats.length + (selectedCategories.isNotEmpty ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              // Premier élément spécial si des filtres sont actifs : bouton reset / compteur
              if (selectedCategories.isNotEmpty && index == 0) {
                return GestureDetector(
                  onTap: () {
                    ref.read(selectedCategoriesProvider.notifier).clear();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(22),
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
                        const Icon(Icons.clear_all_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          '$count lieu${count > 1 ? 'x' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.close_rounded, size: 14, color: Colors.white70),
                      ],
                    ),
                  ),
                );
              }

              final catIndex = selectedCategories.isNotEmpty ? index - 1 : index;
              final cat = filterableCats[catIndex];
              final isSelected = selectedCategories.contains(cat.slug);
              final isPharmacy = cat.slug == 'pharmacie';

              // Couleurs dynamiques pilotées par la table categories
              final catColor = cat.displayColor;
              Color backgroundColor;
              Color foregroundColor;
              Border? border;

              if (isSelected) {
                backgroundColor = catColor;
                foregroundColor = Colors.white;
                border = Border.all(color: Colors.white, width: 2);
              } else if (isPharmacy) {
                backgroundColor = const Color(0xFFDCFCE7);
                foregroundColor = const Color(0xFF166534);
                border = Border.all(color: const Color(0xFF86EFAC));
              } else {
                backgroundColor = Colors.white.withValues(alpha: 0.95);
                foregroundColor = const Color(0xFF1F2937);
                border = Border.all(color: const Color(0xFFE5E7EB));
              }

              IconData icon = isSelected ? Icons.check_circle_rounded : cat.iconData;
              Color iconColor = isSelected ? Colors.white : (isPharmacy ? const Color(0xFF166534) : catColor);

              final label = cat.labelIn('fr');

              return GestureDetector(
                onTap: () {
                  ref.read(selectedCategoriesProvider.notifier).toggleCategory(cat.slug);
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
                          fontWeight: isSelected || isPharmacy ? FontWeight.w700 : FontWeight.w600,
                          color: foregroundColor,
                        ),
                      ),
                      if (isPharmacy && !isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF15803D),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
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
