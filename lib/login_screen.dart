import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'registro_screen.dart';
import 'home_screen.dart';
// --- NUEVO: Importamos la pantalla de recuperación ---
import 'recuperar_password_screen.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true; // Controla si la contraseña está oculta

  // --- FUNCIÓN: INICIO DE SESIÓN CON GOOGLE (CONECTADA A LARAVEL) ---
  Future<void> _loginConGoogle() async {
    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn.instance;
      
      await googleSignIn.initialize(
        serverClientId: '1066552704276-hv495cs1180vrsk9t8e134pjhugp08li.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final authorizedUser = await googleUser.authorizationClient.authorizeScopes(['email', 'profile']);

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authorizedUser.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final correo = firebaseUser.email;
        final nombre = firebaseUser.displayName ?? 'Usuario Google';
        
        // --- NUEVA CONEXIÓN A LARAVEL ---
        final response = await http.post(
          Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/auth/google'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          body: jsonEncode({
            'name': nombre,
            'email': correo,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final tokenReal = data['token']; // Obtenemos el token de Sanctum

          // Guardamos el token real en el disco duro del celular
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', tokenReal);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('¡Bienvenido, $nombre!')),
          );
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          debugPrint('Error del servidor: ${response.body}');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al sincronizar cuenta con el servidor')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error en Google Sign In: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al iniciar sesión con Google')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNCIÓN: INICIO DE SESIÓN TRADICIONAL ---
  Future<void> _login() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json' 
        },
        body: jsonEncode({
          'email': _emailController.text.trim(), 
          'password': _passwordController.text.trim(), 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Bienvenido!')),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        print('=== ERROR EN LOGIN ===');
        print('Código de estado: ${response.statusCode}');
        print('Cuerpo: ${response.body}');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas o error de servidor')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión con el servidor')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso Ciudadano'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.location_city, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword, // <-- Usamos la variable aquí
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  // --- NUEVO: ICONO DEL OJO (SUFFIX ICON) ---
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  // ------------------------------------------
                ),
              ),
              
              // --- NUEVO: BOTÓN DE OLVIDÉ MI CONTRASEÑA ---
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecuperarPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              // --------------------------------------------

              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _login,
                      child: const Text('INICIAR SESIÓN', style: TextStyle(fontSize: 16)),
                    ),

              const SizedBox(height: 16),
              // --- BOTÓN DE GOOGLE ---
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Image.network(
                  'https://img.icons8.com/color/48/000000/google-logo.png',
                  height: 24,
                ),
                label: const Text('Continuar con Google', style: TextStyle(fontSize: 16)),
                onPressed: _loginConGoogle,
              ),
              
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegistroScreen()),
                  );
                },
                child: const Text('¿No tienes cuenta? Regístrate aquí'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}