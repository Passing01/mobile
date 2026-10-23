import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/features/account/presentation/screens/account_screen.dart';
import 'package:qvgestion_mobile/features/admin/presentation/screens/admin_screen.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:qvgestion_mobile/features/map/presentation/screens/home_map_screen.dart';
import 'package:qvgestion_mobile/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:qvgestion_mobile/features/navigation/presentation/widgets/faso_nav_bottom_bar.dart';
import 'package:qvgestion_mobile/features/offline/presentation/screens/saved_places_screen.dart';
import 'package:qvgestion_mobile/features/routes/presentation/screens/routes_screen.dart';

/// Écran conteneur principal gérant la barre de navigation officielle Faso Nav
/// L'onglet Administration est réservé aux comptes avec le rôle Administrateur/Modérateur.
class MainTabScaffold extends ConsumerWidget {
  const MainTabScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isAdmin = authState.user?.isAdmin ?? false;
    final currentTab = ref.watch(currentTabProvider);

    // Si un non-admin se retrouve sur l'onglet admin, le rediriger vers la carte Explorer
    final effectiveTab = (!isAdmin && currentTab == FasoNavTab.admin)
        ? FasoNavTab.explorer
        : currentTab;

    return Scaffold(
      body: IndexedStack(
        index: effectiveTab.index,
        children: [
          const HomeMapScreen(),
          const RoutesScreen(),
          const SavedPlacesScreen(),
          const AccountScreen(),
          if (isAdmin) const AdminScreen() else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: FasoNavBottomBar(
        currentTab: effectiveTab,
        showAdminTab: isAdmin,
        onTabSelected: (tab) {
          ref.read(currentTabProvider.notifier).selectTab(tab);
        },
      ),
    );
  }
}
