import os

main_path = 'lib/main.dart'
settings_path = 'lib/providers/settings_provider.dart'

# 1. Update main.dart
with open(main_path, 'r') as f:
    main_code = f.read()

main_code = main_code.replace("import 'package:flutter/services.dart';", "import 'package:flutter/services.dart';\nimport 'package:shared_preferences/shared_preferences.dart';")
main_code = main_code.replace("runApp(const MyApp());", '''
  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('theme_mode');
  ThemeMode initialThemeMode = ThemeMode.system;
  if (themeStr != null) {
    if (themeStr == 'system') initialThemeMode = ThemeMode.system;
    else if (themeStr == 'dark') initialThemeMode = ThemeMode.dark;
    else initialThemeMode = ThemeMode.light;
  } else {
    final isDark = prefs.getBool('isDarkMode');
    if (isDark != null) {
      initialThemeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  runApp(MyApp(initialThemeMode: initialThemeMode));
''')

main_code = main_code.replace("class MyApp extends StatelessWidget {\n  const MyApp({super.key});", "class MyApp extends StatelessWidget {\n  final ThemeMode initialThemeMode;\n  const MyApp({super.key, required this.initialThemeMode});")
main_code = main_code.replace("ChangeNotifierProvider(create: (_) => SettingsProvider()),", "ChangeNotifierProvider(create: (_) => SettingsProvider(initialThemeMode)),")

with open(main_path, 'w') as f:
    f.write(main_code)

# 2. Update settings_provider.dart
with open(settings_path, 'r') as f:
    settings_code = f.read()

settings_code = settings_code.replace("ThemeMode _themeMode = ThemeMode.system;", "late ThemeMode _themeMode;")
settings_code = settings_code.replace("SettingsProvider() {", "SettingsProvider(ThemeMode initialTheme) {\n    _themeMode = initialTheme;")

with open(settings_path, 'w') as f:
    f.write(settings_code)

