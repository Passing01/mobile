import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/admin/data/models/admin_dashboard_stats_model.dart';
import 'package:qvgestion_mobile/features/admin/data/models/api_key_model.dart';
import 'package:qvgestion_mobile/features/admin/presentation/providers/admin_providers.dart';
import 'package:qvgestion_mobile/features/admin/presentation/screens/admin_screen.dart';
import 'package:qvgestion_mobile/features/auth/data/models/user_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_model.dart';
import 'package:qvgestion_mobile/features/reports/presentation/providers/reports_providers.dart';

const samplePendingPlace = PlaceModel(
  id: 10,
  nom: 'Nouveau Maquis Le Baobab',
  categorieId: 1,
  latitude: 12.3688,
  longitude: -1.4988,
  quartier: 'Dassasgho',
  adresse: 'Rue 14.22',
);

final sampleApiKey = ApiKeyModel(
  id: 1,
  key: 'faso_live_samu_urgence_bf_01',
  name: 'SAMU 15 - Urgences Médicales',
  clientType: ApiClientType.emergency,
  tier: ApiTier.emergencyPriority,
  monthlyQuota: -1,
  currentUsage: 120,
  isActive: true,
  createdAt: DateTime(2026, 1, 1),
);

const sampleAdminUser = UserModel(
  id: 1,
  nom: 'Directeur Ouedraogo',
  email: 'admin@fasonav.bf',
  telephone: '+22670112233',
  role: 'admin',
  isActive: true,
);

void main() {
  const sampleStats = AdminDashboardStatsModel(
    totalUsers: 142,
    totalPlaces: 580,
    pendingPlacesCount: 3,
    totalReports: 25,
    activeReportsCount: 4,
    totalRoutesCalculated: 1250,
    activeDevicesCount: 89,
  );

  const sampleCategories = [
    CategoryModel(
      id: 1,
      nom: 'Pharmacie',
      slug: 'pharmacie',
      icone: 'local_pharmacy',
      color: '#EF4444',
      markerSize: 4,
      labels: {'fr': 'Pharmacies de garde'},
    ),
    CategoryModel(
      id: 2,
      nom: 'Station-service',
      slug: 'station-service',
      icone: 'local_gas_station',
      color: '#F59E0B',
      markerSize: 4,
      labels: {'fr': 'Stations d\'essence'},
    ),
  ];

  Widget createAdminTestWidget() {
    return ProviderScope(
      overrides: [
        adminDashboardStatsProvider.overrideWith((ref) async => sampleStats),
        pendingPlacesProvider.overrideWith(FakePendingPlacesNotifier.new),
        activeReportsProvider.overrideWith(FakeActiveReportsNotifier.new),
        categoriesProvider.overrideWith((ref) async => sampleCategories),
        adminRoadFeaturesProvider.overrideWith((ref) async => []),
        adminApiKeysProvider.overrideWith(FakeApiKeysNotifier.new),
        adminUsersProvider.overrideWith(FakeAdminUsersNotifier.new),
      ],
      child: const MaterialApp(
        home: AdminScreen(),
      ),
    );
  }

  testWidgets('AdminScreen affiche les 7 onglets, KPIs, Éditeur Carto, API B2B et Gestion Admins',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createAdminTestWidget());
    await tester.pumpAndSettle();

    // En-tête
    expect(find.text('Console d\'Administration'), findsOneWidget);
    expect(find.text('FASO NAV • Back-Office & Modération'), findsOneWidget);

    // Les onglets
    expect(find.text('Vue Globale'), findsOneWidget);
    expect(find.text('Modération'), findsOneWidget);
    expect(find.text('Éditeur Carto'), findsOneWidget);
    expect(find.text('API B2B'), findsOneWidget);
    expect(find.text('Équipe & Admins'), findsOneWidget);
    expect(find.text('Catégories'), findsOneWidget);
    expect(find.text('Ancres Routières'), findsOneWidget);

    // KPIs du tableau de bord
    expect(find.text('580'), findsOneWidget); // Lieux
    expect(find.text('4'), findsOneWidget); // Signalements actifs
    expect(find.text('142'), findsOneWidget); // Utilisateurs
    expect(find.text('1250'), findsOneWidget); // Trajets

    // Basculer vers l'onglet Modération
    await tester.tap(find.text('Modération'));
    await tester.pumpAndSettle();

    expect(find.text('Lieux Soumis en Attente'), findsOneWidget);
    expect(find.text('Nouveau Maquis Le Baobab'), findsOneWidget);
    expect(find.text('Approuver'), findsOneWidget);
    expect(find.text('Rejeter'), findsOneWidget);

    // Basculer vers l'onglet Éditeur Carto
    await tester.tap(find.text('Éditeur Carto'));
    await tester.pumpAndSettle();

    expect(find.text('Éditeur Carto Pro • Type GrabMaps'), findsOneWidget);
    expect(find.text('Déposer un Feu Tricolore'), findsOneWidget);
    expect(find.text('Déclarer Travaux / Voie Coupée'), findsOneWidget);
    expect(find.text('Tracer une Nouvelle Voie (6-Mètres / Piste)'), findsOneWidget);

    // Basculer vers l'onglet API B2B
    await tester.tap(find.text('API B2B'));
    await tester.pumpAndSettle();

    expect(find.text('FASO NAV Maps API • Hub B2B & B2G'), findsOneWidget);
    expect(find.text('POST /api/v1/matrix'), findsOneWidget);
    expect(find.text('SAMU 15 - Urgences Médicales'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);

    // Basculer vers l'onglet Équipe & Admins
    await tester.tap(find.text('Équipe & Admins'));
    await tester.pumpAndSettle();

    expect(find.text('Directeur Ouedraogo'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('Actif'), findsOneWidget);
    expect(find.text('MDP'), findsOneWidget);
    expect(find.text('Détails'), findsOneWidget);

    // Basculer vers l'onglet Catégories
    await tester.tap(find.text('Catégories'));
    await tester.pumpAndSettle();

    expect(find.text('Pharmacies de garde'), findsOneWidget);
    expect(find.text('Stations d\'essence'), findsOneWidget);
  });
}

class FakePendingPlacesNotifier extends PendingPlacesNotifier {
  @override
  Future<List<PlaceModel>> build() async {
    return const [samplePendingPlace];
  }

  @override
  Future<void> moderate({required int placeId, required bool approve, String? reason}) async {
    // No-op pour le test
  }
}

class FakeActiveReportsNotifier extends ActiveReportsNotifier {
  @override
  AsyncValue<List<ReportModel>> build() => const AsyncValue.data([]);
}

class FakeApiKeysNotifier extends ApiKeysNotifier {
  @override
  Future<List<ApiKeyModel>> build() async {
    return [sampleApiKey];
  }

  @override
  Future<void> toggleKey(int id) async {}

  @override
  Future<void> deleteKey(int id) async {}
}

class FakeAdminUsersNotifier extends AdminUsersNotifier {
  @override
  Future<List<UserModel>> build() async {
    return [sampleAdminUser];
  }

  @override
  Future<void> toggleStatus(int id, bool isActive) async {}

  @override
  Future<void> changeRole(int id, String newRole) async {}

  @override
  Future<void> resetPassword(int id, String newPassword) async {}
}

