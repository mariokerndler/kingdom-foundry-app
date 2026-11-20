import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/setup_exception.dart';
import '../models/setup_result.dart';
import '../providers/card_data_providers.dart';
import '../providers/config_provider.dart';
import '../providers/generation_provider.dart';
import '../providers/history_provider.dart';
import '../services/history_service.dart';
import 'configuration_screen.dart';
import 'results_screen.dart';

class KingdomRouteParser extends RouteInformationParser<RouteInformation> {
  const KingdomRouteParser();

  @override
  Future<RouteInformation> parseRouteInformation(
          RouteInformation routeInformation) =>
      SynchronousFuture(routeInformation);

  @override
  RouteInformation restoreRouteInformation(RouteInformation configuration) =>
      configuration;
}

class KingdomWebNavigation extends RouterDelegate<RouteInformation>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<RouteInformation> {
  KingdomWebNavigation(this._ref);

  final WidgetRef _ref;
  static const _boardKey = ValueKey('kingdom-board');
  RouteInformation _entry = RouteInformation(uri: Uri(path: '/'));
  bool _ready = false;
  bool _disposed = false;
  String? _error;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  RouteInformation get currentConfiguration => _entry;

  @override
  Future<void> setNewRoutePath(RouteInformation configuration) {
    _entry = configuration;
    _ready = false;
    _error = null;
    final code = _entry.uri.queryParameters['kingdom'];
    if (code != null) unawaited(_loadBoard(configuration, code));
    return SynchronousFuture(null);
  }

  Future<void> _loadBoard(RouteInformation entry, String code) async {
    try {
      final cards = await _ref.read(allCardsProvider.future);
      if (_disposed || !identical(_entry, entry)) return;
      final backup = entry.state;
      SetupResult? board;
      if (backup is String) {
        try {
          board = decodeKingdomBackup(backup, cards).single;
        } catch (_) {
          // The public code can still work if the saved snapshot is obsolete.
        }
      }
      final restored =
          board ?? resolveSharedKingdom(code, cards, _ref.read(configProvider));
      final opened = restoreKingdom(_ref, restored);
      _entry = RouteInformation(
          uri: entry.uri, state: encodeKingdomBackup([opened]));
      _ready = true;
      if (board == null) {
        unawaited(_ref.read(historyProvider.notifier).push(opened));
      }
    } catch (error) {
      if (_disposed || !identical(_entry, entry)) return;
      _error = switch (error) {
        FormatException(:final message) => message.toString(),
        SetupException(:final message) => message,
        _ => 'Could not load the shared kingdom.',
      };
    }
    notifyListeners();
  }

  RouteInformation _entryFor(SetupResult board) => RouteInformation(
        uri: _entry.uri.replace(queryParameters: {
          ..._entry.uri.queryParameters,
          'kingdom': board.hasTableSetupChoices
              ? encodeFullSetup(board)
              : encodeSharePayload(board),
        }),
        state: encodeKingdomBackup([board]),
      );

  void updateBoard(SetupResult? board) {
    final context = navigatorKey.currentContext;
    if (!_ready || board == null || context == null) return;
    Router.neglect(context, () {
      _entry = _entryFor(board);
      notifyListeners();
    });
  }

  @override
  Widget build(BuildContext context) => Navigator(
        key: navigatorKey,
        pages: [
          MaterialPage<void>(
            key: const ValueKey('configuration'),
            child: ConfigurationScreen(onOpenResults: () {
              final board = _ref.read(setupResultProvider);
              if (board == null) return;
              Router.navigate(context, () {
                _entry = _entryFor(board);
                _ready = true;
                _error = null;
                notifyListeners();
              });
            }),
          ),
          if (_entry.uri.queryParameters.containsKey('kingdom'))
            MaterialPage<void>(
              key: _boardKey,
              child: _ready
                  ? const ResultsScreen()
                  : Scaffold(
                      appBar: AppBar(title: const Text('Shared kingdom')),
                      body: Center(
                        child: _error == null
                            ? const CircularProgressIndicator(
                                semanticsLabel: 'Loading shared kingdom')
                            : Padding(
                                padding: const EdgeInsets.all(24),
                                child:
                                    Text(_error!, textAlign: TextAlign.center),
                              ),
                      ),
                    ),
            ),
        ],
        onDidRemovePage: (page) {
          if (page.key != _boardKey ||
              !_entry.uri.queryParameters.containsKey('kingdom')) {
            return;
          }
          Router.neglect(context, () {
            final query = Map.of(_entry.uri.queryParameters)..remove('kingdom');
            _entry = RouteInformation(
                uri: Uri(
                    path: _entry.uri.path,
                    queryParameters: query.isEmpty ? null : query));
            _ready = false;
            _error = null;
            notifyListeners();
          });
        },
      );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
