import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _nombreUsuario = 'Ciudadano'; 

  // --- PALETA DE COLORES BITGLOBAL ---
  final Color _primaryBlue = const Color(0xFF001B69); 
  final Color _bgLight = const Color(0xFFF0F4F8); 

  // Variables para el hardware
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime? _lastShakeTime;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
    _fetchIncidencias();
    _inicializarNotificaciones();
    _iniciarAcelerometro();
  }

  Future<void> _cargarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nombreUsuario = prefs.getString('nombre') ?? 'Ciudadano';
    });
  }

  // --- FUNCIÓN AUXILIAR: Darle un formato bonito a la fecha ---
  String _formatearFecha(String? fechaIso) {
    if (fechaIso == null) return 'Fecha desconocida';
    try {
      final fecha = DateTime.parse(fechaIso);
      // Agregamos un 0 a la izquierda si el día o mes es menor a 10
      final dia = fecha.day.toString().padLeft(2, '0');
      final mes = fecha.month.toString().padLeft(2, '0');
      return '$dia/$mes/${fecha.year}';
    } catch (e) {
      return 'Recientemente';
    }
  }

  // --- CONFIGURACIÓN DE NOTIFICACIONES ---
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

  // --- CONFIGURACIÓN DEL ACELERÓMETRO ---
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

  // --- CONEXIÓN A AWS ---
  Future<void> _fetchIncidencias() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/incidencias'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Authorization': 'Bearer $token', 
        }
      );

      if (response.statusCode == 200) {
        setState(() {
          _incidencias = jsonDecode(response.body);
          _incidencias = _incidencias.reversed.toList(); 
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
      default:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset('assets/logobit.png', height: 26),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola,',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _nombreUsuario,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                      tooltip: 'Cerrar sesión',
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('token');
                        await prefs.remove('nombre');
                        
                        if(!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // --- TITULO ACTUALIZADO A COMUNIDAD ---
              const Text(
                'Comunidad',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Descubre lo que sucede a tu alrededor',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, 
      ),
      child: Scaffold(
        backgroundColor: _bgLight,
        body: Column(
          children: [
            _buildHeader(),
            
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchIncidencias,
                color: _primaryBlue,
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: _primaryBlue))
                    : _incidencias.isEmpty
                        ? Stack(
                            children: [
                              ListView(), 
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05), 
                                            blurRadius: 20, 
                                            offset: const Offset(0, 10),
                                          )
                                        ]
                                      ),
                                      child: Icon(Icons.public, size: 60, color: Colors.grey.shade300),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'No hay reportes comunitarios aún.\n¡Sé el primero en aportar!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16, height: 1.5),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            padding: const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 100),
                            itemCount: _incidencias.length,
                            itemBuilder: (context, index) {
                              final reporte = _incidencias[index];
                              
                              final String? imageUrl = reporte['imagen_ruta'] != null
                                  ? 'http://52.15.143.102/api-backend/public/${reporte['imagen_ruta']}'
                                  : null;

                              // Extraemos el nombre del autor (si tu API lo envía como user -> name)
                              // Si no encuentra el dato, muestra "Ciudadano Anónimo"
                              final String autor = reporte['user']?['name'] ?? 'Ciudadano Anónimo';
                              
                              // Extraemos y formateamos la fecha
                              final String fechaReal = _formatearFecha(reporte['created_at']);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () async {
                                      final huboCambios = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetalleScreen(reporte: reporte),
                                        ),
                                      );
                                      if (huboCambios == true) {
                                        _fetchIncidencias();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            height: 85,
                                            width: 80,
                                            decoration: BoxDecoration(
                                              color: _bgLight,
                                              borderRadius: BorderRadius.circular(16),
                                              image: imageUrl != null
                                                  ? DecorationImage(
                                                      image: NetworkImage(imageUrl),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                            child: imageUrl == null
                                                ? Icon(Icons.maps_home_work_rounded, color: Colors.grey.shade400, size: 30)
                                                : null,
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        reporte['titulo'] ?? 'Sin título',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 16,
                                                          color: Colors.black87,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                
                                                // --- NUEVO: AUTOR DEL REPORTE ---
                                                Row(
                                                  children: [
                                                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        autor,
                                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                
                                                // --- NUEVO: FECHA DEL REPORTE ---
                                                Row(
                                                  children: [
                                                    Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      fechaReal,
                                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                                    ),
                                                  ],
                                                ),
                                                
                                                const SizedBox(height: 10),
                                                _buildEstadoBadge(reporte['estado'] ?? 'Pendiente'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
        
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () async {
              final seCreoReporte = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CrearReporteScreen()),
              );
              
              if (seCreoReporte == true) {
                _fetchIncidencias();
              }
            },
            backgroundColor: _primaryBlue,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            label: const Text(
              'Reportar', 
              style: TextStyle(
                color: Colors.white, 
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              )
            ),
          ),
        ),
      ),
    );
  }
}