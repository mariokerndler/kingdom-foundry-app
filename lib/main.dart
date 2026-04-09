import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/config_provider.dart';
import 'screens/configuration_screen.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DominionApp(),
    ),
  );
}

class DominionApp extends StatelessWidget {
  const DominionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                      'Dominion Setup',
      debugShowCheckedModeBanner: false,
      theme:                      buildLightTheme(),
      darkTheme:                  buildDarkTheme(),
      themeMode:                  ThemeMode.system,
      home:                       const ConfigurationScreen(),
    );
  }
}
