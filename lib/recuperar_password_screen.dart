import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'restablecer_password_screen.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  State<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  // --- FUNCIÓN REAL CONECTADA A TU API ---
  Future<void> _recuperarPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa tu correo electrónico')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        // Asumiendo que esta será tu ruta en Laravel, la puedes ajustar luego
        Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Si el correo existe, recibirás un enlace de recuperación.')),
        );
        // En vez de regresar, vamos a la pantalla de poner el PIN pasándole el correo
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RestablecerPasswordScreen(email: email),
          ),
        );
      } else {
        debugPrint('Error del servidor: ${response.body}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar la solicitud. Intenta de nuevo.')),
        );
      }
    } catch (e) {
      debugPrint('Error de red: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión con el servidor')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 24),
            const Text(
              'Ingresa tu correo electrónico y te enviaremos las instrucciones para restablecer tu contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isLoading ? null : _recuperarPassword,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Enviar enlace de recuperación', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}