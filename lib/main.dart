import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'models/app_theme_setting.dart';
import 'services/cache_service.dart';

const _prefsKeyTheme = 'settings_appTheme';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheService.init();
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobility4BW',
      theme: AppThemeSettings.lightTheme,
      darkTheme: AppThemeSettings.darkTheme,
      themeMode: _appThemeSetting.themeMode,
      home: HomeScreen(
        appThemeSetting: _appThemeSetting,
        onChangeAppTheme: _setThemeSetting,
      ),
    );
  }
}
