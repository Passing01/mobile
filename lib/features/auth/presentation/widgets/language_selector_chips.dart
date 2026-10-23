import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/theme/app_spacing.dart';

class LanguageSelectorChips extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<String> onSelected;

  const LanguageSelectorChips({
    super.key,
    required this.selectedCode,
    required this.onSelected,
  });

  static const List<Map<String, String>> languages = [
    {'code': 'mos', 'label': 'Mooré', 'desc': 'Gom-biis'},
    {'code': 'diu', 'label': 'Dioula', 'desc': 'Kuma'},
    {'code': 'fr', 'label': 'Français', 'desc': 'Officiel'},
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: languages.map((lang) {
        final code = lang['code']!;
        final label = lang['label']!;
        final isSelected = code.toLowerCase() == selectedCode.toLowerCase();

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () => onSelected(code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : const Color(0xFFF3F4F6),
                  borderRadius: AppSpacing.roundedMd,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang['desc']!,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? Colors.white70 : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
