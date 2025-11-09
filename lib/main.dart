import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

enum AppThemeSetting {
  system,
  light,
  dark,
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MobiDataApp());
}

class MobiDataApp extends StatelessWidget {
  const MobiDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MobiData BW in Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF004C97)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
