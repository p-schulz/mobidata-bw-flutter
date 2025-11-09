import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'models/app_theme_settings.dart';

const _prefsKeyTheme = 'settings_appTheme';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MobiDataApp());
}


class MobiDataApp extends StatefulWidget {
  const MobiDataApp({super.key});

  @override
  State<MobiDataApp> createState() => _MobiDataAppState();
}


class _MobiDataAppState extends State<MobiDataApp> {
  AppThemeSetting _appThemeSetting = AppThemeSetting.system;

  @override
  void initState() {
    super.initState();
    _loadThemeSetting();
  }

  Future<void> _loadThemeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKeyTheme);
    setState(() {
      switch (value) {
        case 'light':
          _appThemeSetting = AppThemeSetting.light;
          break;
        case 'dark':
          _appThemeSetting = AppThemeSetting.dark;
          break;
        default:
          _appThemeSetting = AppThemeSetting.system;
      }
    });
  }

  Future<void> _setThemeSetting(AppThemeSetting setting) async {
    final prefs = await SharedPreferences.getInstance();
    String value;
    switch (setting) {
      case AppThemeSetting.light:
        value = 'light';
        break;
      case AppThemeSetting.dark:
        value = 'dark';
        break;
      case AppThemeSetting.system:
      default:
        value = 'system';
    }

    await prefs.setString(_prefsKeyTheme, value);
    setState(() {
      _appThemeSetting = setting;
    });
  }

  ThemeMode get _themeMode {
    switch (_appThemeSetting) {
      case AppThemeSetting.light:
        return ThemeMode.light;
      case AppThemeSetting.dark:
        return ThemeMode.dark;
      case AppThemeSetting.system:
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseLight = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF004C97),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    final baseDark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF004C97),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'MobiData BW Starter',
      theme: baseLight,
      darkTheme: baseDark,
      themeMode: _themeMode,
      home: HomeScreen(
        appThemeSetting: _appThemeSetting,
        onChangeAppTheme: _setThemeSetting,
      ),
    );
  }
}
