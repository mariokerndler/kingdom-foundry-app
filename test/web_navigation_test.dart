import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_foundry/models/kingdom_card.dart';
import 'package:kingdom_foundry/models/table_setup_choice.dart';
import 'package:kingdom_foundry/providers/card_data_providers.dart';
import 'package:kingdom_foundry/providers/config_provider.dart';
import 'package:kingdom_foundry/providers/generation_provider.dart';
import 'package:kingdom_foundry/screens/configuration_screen.dart';
import 'package:kingdom_foundry/screens/results_screen.dart';
import 'package:kingdom_foundry/screens/web_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('generated boards restore on Forward and bad links can go Back',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cards =
        (jsonDecode(File('assets/data/cards.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>()
            .map(KingdomCard.fromJson)
            .toList();
    final routes = _BrowserRoutes();
    final container = ProviderContainer(overrides: [
      allCardsProvider.overrideWith((ref) async => cards),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    addTearDown(routes.dispose);
    KingdomWebNavigation? navigation;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(builder: (_, ref, __) {
        navigation ??= KingdomWebNavigation(ref);
        ref.listen(
            setupResultProvider, (_, board) => navigation!.updateBoard(board));
        return MaterialApp.router(
          routeInformationProvider: routes,
          routeInformationParser: const KingdomRouteParser(),
          routerDelegate: navigation!,
        );
      }),
    ));
    addTearDown(navigation!.dispose);
    await tester.pumpAndSettle();
    final home = routes.value;

    await tester.tap(find.text('Generate kingdom'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(routes.lastReport, RouteInformationReportingType.navigate);
    final board = container.read(setupResultProvider)!;
    final firstCard = board.kingdomCards.first;
    final lock = find.byTooltip('Lock ${firstCard.name}');
    await tester.ensureVisible(lock);
    await tester.tap(lock);
    await tester.pumpAndSettle();
    expect(routes.lastReport, RouteInformationReportingType.neglect);
    final generated = routes.value;
    expect(generated.uri.queryParameters['kingdom'], startsWith('KF2-'));

    routes.visit(home);
    await tester.pumpAndSettle();
    expect(find.byType(ConfigurationScreen), findsOneWidget);
    routes.visit(generated);
    await tester.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(container.read(setupResultProvider)!.storageKey, board.storageKey);
    expect(container.read(setupResultProvider)!.isSlotLocked(firstCard.pileId),
        isTrue);

    container.read(setupResultProvider.notifier).state = container
        .read(setupResultProvider)!
        .copyWith(
            platinumColonyChoice: TableSetupChoice.include,
            sheltersChoice: TableSetupChoice.exclude);
    await tester.pumpAndSettle();
    final fullRoute = routes.value;
    expect(fullRoute.uri.queryParameters['kingdom'], startsWith('KF1:'));
    // A browser refresh can restore the URL without its private history state.
    routes.visit(RouteInformation(uri: fullRoute.uri));
    await tester.pumpAndSettle();
    expect(container.read(setupResultProvider)!.platinumColonyChoice,
        TableSetupChoice.include);
    expect(container.read(setupResultProvider)!.sheltersChoice,
        TableSetupChoice.exclude);

    routes.visit(RouteInformation(uri: Uri.parse('/?kingdom=broken')));
    await tester.pumpAndSettle();
    expect(find.text('Invalid share code.'), findsOneWidget);
    routes.visit(home);
    await tester.pumpAndSettle();
    expect(find.byType(ConfigurationScreen), findsOneWidget);
  });
}

class _BrowserRoutes extends RouteInformationProvider with ChangeNotifier {
  @override
  RouteInformation value = RouteInformation(uri: Uri(path: '/'));
  RouteInformationReportingType? lastReport;

  void visit(RouteInformation information) {
    value = information;
    notifyListeners();
  }

  @override
  void routerReportsNewRouteInformation(RouteInformation routeInformation,
      {RouteInformationReportingType type =
          RouteInformationReportingType.none}) {
    value = routeInformation;
    lastReport = type;
  }
}
