import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/features/notifications/data/models/notification_item_model.dart';
import 'package:qvgestion_mobile/features/notifications/data/repositories/notifications_repository.dart';
import 'package:qvgestion_mobile/features/notifications/presentation/providers/notifications_providers.dart';

class MockNotificationsRepository extends Mock implements INotificationsRepository {}

void main() {
  late MockNotificationsRepository mockRepository;
  late ProviderContainer container;

  final now = DateTime.parse('2026-10-09T23:00:00.000Z');

  final item1 = NotificationItemModel(
    id: 1,
    utilisateurId: 42,
    title: 'Alerte Inondation',
    body: 'Canal débordé',
    isRead: false,
    createdAt: now,
  );

  final item2 = NotificationItemModel(
    id: 2,
    utilisateurId: 42,
    title: 'Travaux de voirie',
    body: 'Avenue de la Nation en travaux',
    isRead: true,
    createdAt: now,
  );

  setUp(() {
    mockRepository = MockNotificationsRepository();
    container = ProviderContainer(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('MyNotificationsNotifier Tests', () {
    test('build charge les notifications et calcule les non lues', () async {
      when(() => mockRepository.getMyNotifications())
          .thenAnswer((_) async => [item1, item2]);

      final result = await container.read(myNotificationsProvider.future);
      expect(result.length, 2);

      final unreadCount = container.read(unreadNotificationsCountProvider);
      expect(unreadCount, 1);
    });

    test('markAsRead met à jour l\'état local et décrémente les non lues', () async {
      when(() => mockRepository.getMyNotifications())
          .thenAnswer((_) async => [item1, item2]);
      when(() => mockRepository.markAsRead(1)).thenAnswer((_) async {});

      await container.read(myNotificationsProvider.future);
      expect(container.read(unreadNotificationsCountProvider), 1);

      await container.read(myNotificationsProvider.notifier).markAsRead(1);

      final updatedList = container.read(myNotificationsProvider).value ?? [];
      expect(updatedList.first.isRead, isTrue);
      expect(container.read(unreadNotificationsCountProvider), 0);
    });

    test('markAllAsRead marque tous les éléments non lus comme lus', () async {
      when(() => mockRepository.getMyNotifications())
          .thenAnswer((_) async => [item1, item2]);
      when(() => mockRepository.markAsRead(any())).thenAnswer((_) async {});

      await container.read(myNotificationsProvider.future);
      await container.read(myNotificationsProvider.notifier).markAllAsRead();

      final list = container.read(myNotificationsProvider).value ?? [];
      expect(list.every((item) => item.isRead), isTrue);
      expect(container.read(unreadNotificationsCountProvider), 0);
    });
  });
}
