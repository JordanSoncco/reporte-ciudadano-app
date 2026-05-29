import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // --- NUEVA LÍNEA: Despertamos a Firebase ---
  await Firebase.initializeApp();

  // Verificamos si ya hay un token guardado
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  runApp(MyApp(isLoggedIn: token != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reporte Ciudadano',
      theme: ThemeData(primarySwatch: Colors.blue),
      // Si isLoggedIn es true, va a HomeScreen, si no, a LoginScreen
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}