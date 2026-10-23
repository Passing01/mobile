import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/features/notifications/data/models/notification_item_model.dart';
import 'package:qvgestion_mobile/features/notifications/data/repositories/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<INotificationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationsRepository(apiClient: apiClient);
});

class MyNotificationsNotifier extends AsyncNotifier<List<NotificationItemModel>> {
  @override
  Future<List<NotificationItemModel>> build() async {
    final repo = ref.watch(notificationsRepositoryProvider);
    return repo.getMyNotifications();
  }

  Future<void> refreshNotifications() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(notificationsRepositoryProvider);
      return repo.getMyNotifications();
    });
  }

  Future<void> markAsRead(int notificationId) async {
    final currentList = state.value ?? [];
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markAsRead(notificationId);

      state = AsyncValue.data(
        currentList.map((item) {
          if (item.id == notificationId) {
            return item.copyWith(isRead: true);
          }
          return item;
        }).toList(),
      );
    } catch (_) {
      // Échec silencieux
    }
  }

  Future<void> markAllAsRead() async {
    final currentList = state.value ?? [];
    final unread = currentList.where((item) => !item.isRead).toList();
    final repo = ref.read(notificationsRepositoryProvider);

    for (final item in unread) {
      try {
        await repo.markAsRead(item.id);
      } catch (_) {}
    }

    state = AsyncValue.data(
      currentList.map((item) => item.copyWith(isRead: true)).toList(),
    );
  }
}

final myNotificationsProvider =
    AsyncNotifierProvider<MyNotificationsNotifier, List<NotificationItemModel>>(
  MyNotificationsNotifier.new,
);

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(myNotificationsProvider);
  return notificationsAsync.maybeWhen(
    data: (list) => list.where((item) => !item.isRead).length,
    orElse: () => 0,
  );
});
