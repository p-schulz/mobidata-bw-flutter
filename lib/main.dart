import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MobiDataApp());
}

class MobiDataApp extends StatelessWidget {
  const MobiDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MobiData BW Starter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF004C97)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
