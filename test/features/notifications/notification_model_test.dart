import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/notifications/data/models/notification_item_model.dart';

void main() {
  group('NotificationItemModel Tests', () {
    final now = DateTime.parse('2026-10-09T23:00:00.000Z');

    test('NotificationItemModel parse le JSON et gère copyWith', () {
      final json = {
        'id': 1,
        'utilisateur_id': 42,
        'title': 'Alerte Crue Canal du Mogho Naaba',
        'body': 'Niveau d\'eau critique, déviation recommandée via Avenue Ouezzin Coulibaly.',
        'is_read': false,
        'incident_id': 10,
        'created_at': now.toIso8601String(),
      };

      final model = NotificationItemModel.fromJson(json);
      expect(model.id, 1);
      expect(model.utilisateurId, 42);
      expect(model.title, 'Alerte Crue Canal du Mogho Naaba');
      expect(model.isRead, isFalse);
      expect(model.incidentId, 10);

      final readModel = model.copyWith(isRead: true);
      expect(readModel.isRead, isTrue);
      expect(readModel.id, 1);

      expect(readModel.toJson()['is_read'], isTrue);
    });
  });
}
