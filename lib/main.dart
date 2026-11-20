import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/config_provider.dart';
import 'providers/generation_provider.dart';
import 'screens/configuration_screen.dart';
import 'screens/web_navigation.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await _startApp();
}

Future<void> _startApp() async {
  final SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    runApp(const MaterialApp(
      home: Scaffold(
          body: Center(
              child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Could not open local settings.'),
          FilledButton(onPressed: _startApp, child: Text('Retry')),
        ]),
      ))),
    ));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const KingdomFoundryApp(),
    ),
  );
}

class KingdomFoundryApp extends ConsumerStatefulWidget {
  const KingdomFoundryApp({super.key});

  @override
  ConsumerState<KingdomFoundryApp> createState() => _KingdomFoundryAppState();
}

class _KingdomFoundryAppState extends ConsumerState<KingdomFoundryApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final _webNavigation = kIsWeb ? KingdomWebNavigation(ref) : null;

  @override
  void dispose() {
    _webNavigation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final useDarkMode = ref.watch(configProvider).useDarkMode;
    final webNavigation = _webNavigation;
    if (webNavigation != null) {
      ref.listen(
          setupResultProvider, (_, board) => webNavigation.updateBoard(board));
    }
    ref.listen(storageNoticeProvider, (_, notice) {
      if (notice == null) return;
      final messenger = _messenger.currentState;
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(
        content: Text(notice.message),
        action: notice.retry == null
            ? null
            : SnackBarAction(label: 'Try again', onPressed: notice.retry!),
      ));
    });

    if (webNavigation != null) {
      return MaterialApp.router(
        title: 'Kingdom Foundry',
        scaffoldMessengerKey: _messenger,
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: useDarkMode ? ThemeMode.dark : ThemeMode.light,
        routeInformationParser: const KingdomRouteParser(),
        routerDelegate: webNavigation,
      );
    }

    return MaterialApp(
      title: 'Kingdom Foundry',
      scaffoldMessengerKey: _messenger,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: useDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const ConfigurationScreen(),
    );
  }
}
