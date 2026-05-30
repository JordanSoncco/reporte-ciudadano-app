import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- Importante para controlar la barra de batería/hora
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'home_screen.dart';
import 'registro_screen.dart';
import 'recuperar_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// Ya no usamos SingleTickerProviderStateMixin porque quitamos la animación de rotación
class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  final Color _brandBlue = const Color(0xFF001B69);
  final Color _midnightBlue = const Color(0xFF040A22);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginNormal() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

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
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión con el servidor')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
          final tokenReal = data['token'];

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
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al sincronizar cuenta')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al iniciar sesión con Google')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildGoogleLogo() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
        children: [
          TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- FORZAMOS ÍCONOS BLANCOS EN LA BARRA DE ESTADO ---
      appBar: AppBar(
        toolbarHeight: 0, 
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light, // Íconos blancos (hora, batería)
          statusBarBrightness: Brightness.dark,
        ),
      ),
      extendBodyBehindAppBar: true, // Para que el degradado ocupe toda la pantalla
      
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_midnightBlue, _brandBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _brandBlue.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Hero(
                    tag: 'logo_bitglobal',
                    child: Image.asset(
                      'assets/logobit.png',
                      height: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Iniciar Sesión',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: _brandBlue,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Correo Electrónico',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade600),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: _brandBlue, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: TextStyle(color: Colors.grey.shade700),
                              prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade600),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: _brandBlue, width: 1.5),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RecuperarPasswordScreen()),
                                );
                              },
                              child: Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: _brandBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // --- AQUÍ ELIMINAMOS EL LOGO ROTANDO Y PONEMOS UN CARGADOR CLÁSICO ---
                          _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _brandBlue.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _brandBlue,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _loginNormal,
                                    child: const Text(
                                      'ENTRAR',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                          
                          const SizedBox(height: 24),
                          
                          if (!_isLoading)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.white,
                              ),
                              onPressed: _loginConGoogle,
                              icon: _buildGoogleLogo(),
                              label: const Text(
                                'Continuar con Google',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                if (!_isLoading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿No tienes cuenta? ',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegistroScreen()),
                          );
                        },
                        child: const Text(
                          'Regístrate',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}