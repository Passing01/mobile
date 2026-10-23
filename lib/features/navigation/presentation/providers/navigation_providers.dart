import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/features/navigation/presentation/widgets/faso_nav_bottom_bar.dart';

class CurrentTabNotifier extends Notifier<FasoNavTab> {
  @override
  FasoNavTab build() => FasoNavTab.explorer;

  void selectTab(FasoNavTab tab) => state = tab;
}

final currentTabProvider =
    NotifierProvider<CurrentTabNotifier, FasoNavTab>(CurrentTabNotifier.new);
