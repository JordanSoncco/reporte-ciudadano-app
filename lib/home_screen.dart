import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'crear_reporte_screen.dart';
import 'detalle_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _incidencias = [];
  bool _isLoading = true;

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
    
    // Pedir permiso en Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _mostrarNotificacion() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_emergencia', // ID interno
      'Alertas de Emergencia', // Nombre visible
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
    // Escuchamos los datos del sensor en tiempo real
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // Sumamos la fuerza G en los ejes X, Y, Z
      double force = event.x.abs() + event.y.abs() + event.z.abs();
      
      // Si la fuerza supera los 35 (agitar fuerte)
      if (force > 35) {
        final now = DateTime.now();
        // Un temporizador de 5 segundos para que no te inunde de notificaciones
        if (_lastShakeTime == null || now.difference(_lastShakeTime!) > const Duration(seconds: 5)) {
          _lastShakeTime = now;
          _mostrarNotificacion(); // Disparamos la alerta
        }
      }
    });
  }

  // --- 3. CONEXIÓN A AWS ---
  Future<void> _fetchIncidencias() async {
    try {
      final response = await http.get(
        Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/incidencias'),
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
    // Apagamos el sensor cuando se cierra la app para ahorrar batería
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidencias de la Ciudad'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Borramos el token del teléfono
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              
              // Regresamos al Login
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
          ? const Center(child: CircularProgressIndicator())
          : _incidencias.isEmpty
              ? const Center(child: Text('No hay reportes aún. ¡Registra el primero!'))
              : ListView.builder(
                  itemCount: _incidencias.length,
                  itemBuilder: (context, index) {
                    final reporte = _incidencias[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.report_problem, color: Colors.orange),
                        title: Text(reporte['titulo'] ?? 'Sin título', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Estado: ${reporte['estado']}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        
                        // --- AQUÍ ESTÁ LA MAGIA DE LA SINCRONIZACIÓN ---
                        onTap: () async {
                          // Esperamos a que el usuario regrese de la pantalla de detalles
                          final huboCambios = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetalleScreen(reporte: reporte),
                            ),
                          );

                          // Si la pantalla de detalles nos devolvió "true" (porque se editó o borró),
                          // volvemos a descargar la lista de AWS.
                          if (huboCambios == true) {
                            setState(() => _isLoading = true);
                            _fetchIncidencias();
                          }
                        },
                        // -----------------------------------------------
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
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
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}