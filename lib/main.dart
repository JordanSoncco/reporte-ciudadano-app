import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'login_screen.dart';
import 'home_screen.dart';

void main() async {
  // Asegura que los bindings de Flutter estén listos antes de ejecutar código asíncrono
  WidgetsFlutterBinding.ensureInitialized();
  
  // --- MEJORA PRO: Bloquear la orientación en vertical ---
  // Evita que la pantalla rote y desajuste el diseño o la cámara
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Despertamos a Firebase
  await Firebase.initializeApp();

  // Verificamos si ya hay un token guardado en la memoria local
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  runApp(MyApp(isLoggedIn: token != null));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    // --- COLOR CORPORATIVO GLOBAL ---
    const Color brandBlue = Color(0xFF001B69);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reporte Ciudadano',
      
      // --- TEMA GLOBAL MEJORADO (MATERIAL 3) ---
      theme: ThemeData(
        useMaterial3: true,
        // colorScheme inyecta tu azul corporativo en todos los widgets por defecto (calendarios, switches, etc)
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandBlue,
          primary: brandBlue,
        ),
        // Fondo gris claro moderno global para ahorrar código en las demás pantallas
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        // Estilo global de las barras superiores para que siempre mantengan la estética
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: brandBlue),
          titleTextStyle: TextStyle(
            color: brandBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      
      // Si el token existe entra directo al Home, de lo contrario pide Login
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}