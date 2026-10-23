import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/network/api_exceptions.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:qvgestion_mobile/features/auth/presentation/widgets/auth_modal_sheet.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_model.dart';
import 'package:qvgestion_mobile/features/reports/presentation/providers/reports_providers.dart';

/// Feuille modale affichant les détails d'un obstacle routier et le vote collaboratif
class ReportDetailsSheet extends ConsumerStatefulWidget {
  final ReportModel report;
  final VoidCallback? onClose;

  const ReportDetailsSheet({
    super.key,
    required this.report,
    this.onClose,
  });

  static Future<void> show(BuildContext context, ReportModel report) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportDetailsSheet(report: report),
    );
  }

  @override
  ConsumerState<ReportDetailsSheet> createState() => _ReportDetailsSheetState();
}

class _ReportDetailsSheetState extends ConsumerState<ReportDetailsSheet> {
  bool _isVoting = false;
  late ReportModel _currentReport;

  @override
  void initState() {
    super.initState();
    _currentReport = widget.report;
  }

  Future<void> _handleVote(int vote) async {
    final authState = ref.read(authNotifierProvider);
    if (!authState.isAuthenticated) {
      AppSnackbar.showWarning(
        context,
        title: 'Authentification requise',
        message: 'Connectez-vous pour participer aux votes communautaires.',
      );
      AuthModalSheet.show(context);
      return;
    }

    setState(() => _isVoting = true);

    try {
      final updated = await ref
          .read(activeReportsProvider.notifier)
          .voteOnReport(_currentReport.id, vote);

      if (mounted) {
        if (updated != null) {
          setState(() => _currentReport = updated);
          AppSnackbar.showSuccess(
            context,
            title: vote == 1 ? 'Confirmation enregistrée' : 'Signalement infirmé',
            message: vote == 1
                ? 'Merci ! La durée de visibilité a été prolongée de 30 min.'
                : 'Merci pour votre retour sur l\'état de la chaussée.',
          );
        } else {
          // L'obstacle a été auto-résolu par la communauté
          Navigator.of(context).pop();
          AppSnackbar.showInfo(
            context,
            title: 'Obstacle résolu',
            message: 'Ce signalement a été retiré de la carte suite aux avis de la communauté.',
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        if (e.statusCode == 409) {
          AppSnackbar.showInfo(
            context,
            title: 'Vote déjà enregistré',
            message: 'Vous avez déjà exprimé votre avis sur ce signalement.',
          );
        } else {
          AppSnackbar.showError(
            context,
            title: 'Erreur',
            message: e.message,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          title: 'Erreur réseau',
          message: 'Impossible d\'enregistrer votre vote pour le moment.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _currentReport;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre de préhension
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // En-tête avec type d'incident et statut
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: report.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(report.iconData, color: report.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            report.timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (report.quartier != null) ...[
                            Text(' • ',
                                style: TextStyle(color: Colors.grey.shade400)),
                            Text(
                              report.quartier!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    widget.onClose?.call();
                    Navigator.of(context).maybePop();
                  },
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Description du signalement
            if (report.description != null && report.description!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 18, color: Color(0xFF6B7280)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (report.adresse != null && report.adresse!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${report.adresse}, ${report.ville}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Section Consensus & Vote Communautaire
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cet obstacle est-il toujours là ?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          'Score : +${report.scoreConfiance}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Bouton Confirmer (+1)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isVoting ? null : () => _handleVote(1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: report.hasUserUpvoted
                                ? const Color(0xFF15803D)
                                : Colors.white,
                            foregroundColor: report.hasUserUpvoted
                                ? Colors.white
                                : const Color(0xFF15803D),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFF22C55E)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          icon: Icon(
                            report.hasUserUpvoted
                                ? Icons.thumb_up_alt_rounded
                                : Icons.thumb_up_alt_outlined,
                            size: 16,
                          ),
                          label: Text(
                            'Oui (${report.upvotes})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Bouton Infirmer (-1)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isVoting ? null : () => _handleVote(-1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: report.hasUserDownvoted
                                ? const Color(0xFFB91C1C)
                                : Colors.white,
                            foregroundColor: report.hasUserDownvoted
                                ? Colors.white
                                : const Color(0xFFB91C1C),
                            elevation: 0,
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          icon: Icon(
                            report.hasUserDownvoted
                                ? Icons.thumb_down_alt_rounded
                                : Icons.thumb_down_alt_outlined,
                            size: 16,
                          ),
                          label: Text(
                            'Dégagé (${report.downvotes})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
