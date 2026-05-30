import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crear_reporte_screen.dart';
import 'detalle_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _incidencias = [];
  bool _isLoading = true;

  // --- PALETA DE COLORES BITGLOBAL ---
  final Color _primaryBlue = const Color(0xFF001B69); // Azul oscuro corporativo
  final Color _bgLight = const Color(0xFFF5F7FA); // Fondo gris claro moderno

  // Variables para el hardware
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime? _lastShakeTime;

  @override
  void initState() {
    super.initState();
    _fetchIncidencias();
    _inicializarNotificaciones();
    _iniciarAcelerometro();
  }

  // --- 1. CONFIGURACIÓN DE NOTIFICACIONES ---
  Future<void> _inicializarNotificaciones() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _mostrarNotificacion() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_emergencia',
      'Alertas de Emergencia',
      channelDescription: 'Notificaciones al agitar el dispositivo',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      0,
      '¡Movimiento brusco detectado!',
      '¿Ocurrió una emergencia? Registra un reporte ciudadano ahora.',
      platformDetails,
    );
  }

  // --- 2. CONFIGURACIÓN DEL ACELERÓMETRO ---
  void _iniciarAcelerometro() {
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      double force = event.x.abs() + event.y.abs() + event.z.abs();
      if (force > 35) {
        final now = DateTime.now();
        if (_lastShakeTime == null || now.difference(_lastShakeTime!) > const Duration(seconds: 5)) {
          _lastShakeTime = now;
          _mostrarNotificacion();
        }
      }
    });
  }

  // --- CONEXIÓN A AWS (AHORA CON SEGURIDAD) ---
  Future<void> _fetchIncidencias() async {
    try {
      // 1. Buscamos el token guardado en el celular
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // 2. Hacemos la petición enviando el Token en los Headers
      final response = await http.get(
        Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/incidencias'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Authorization': 'Bearer $token', // <-- LA LLAVE CON DISFRAZ VIP
        }
      );

      if (response.statusCode == 200) {
        setState(() {
          _incidencias = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  // --- WIDGET PERSONALIZADO: Píldora de Estado ---
  Widget _buildEstadoBadge(String estado) {
    Color bgColor;
    Color textColor;

    switch (estado.toLowerCase()) {
      case 'resuelto':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'en proceso':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      default: // Pendiente
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min, // <-- Evita que el Row ocupe espacio extra
          children: [
            // --- CORRECCIÓN: Ahora busca el .png ---
            Image.asset('assets/logobit.png', height: 35),
            const SizedBox(width: 10),
            // --- CORRECCIÓN: Flexible evita el desbordamiento amarillo/negro ---
            Flexible(
              child: Text(
                'Incidencias',
                style: TextStyle(
                  color: _primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: _primaryBlue),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              
              if(!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryBlue))
          : _incidencias.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No hay reportes aún.\n¡Sé el primero en aportar!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _incidencias.length,
                  itemBuilder: (context, index) {
                    final reporte = _incidencias[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final huboCambios = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetalleScreen(reporte: reporte),
                              ),
                            );
                            if (huboCambios == true) {
                              setState(() => _isLoading = true);
                              _fetchIncidencias();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // Ícono estilizado corporativo
                                Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    color: _primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.location_city,
                                    color: _primaryBlue,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reporte['titulo'] ?? 'Sin título',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildEstadoBadge(reporte['estado'] ?? 'Pendiente'),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final seCreoReporte = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CrearReporteScreen()),
          );
          
          if (seCreoReporte == true) {
            setState(() => _isLoading = true);
            _fetchIncidencias();
          }
        },
        backgroundColor: _primaryBlue,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Reportar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}