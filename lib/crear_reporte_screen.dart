import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class CrearReporteScreen extends StatefulWidget {
  const CrearReporteScreen({super.key});

  @override
  State<CrearReporteScreen> createState() => _CrearReporteScreenState();
}

class _CrearReporteScreenState extends State<CrearReporteScreen> {
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  
  File? _imagen;
  Position? _posicionActual;
  bool _isLoading = false;

  // --- PALETA CORPORATIVA ---
  final Color _brandBlue = const Color(0xFF001B69);
  final Color _bgLight = const Color(0xFFF5F7FA);

  // --- FUNCIÓN: SELECCIONAR IMAGEN (CÁMARA O GALERÍA) ---
  Future<void> _seleccionarImagen(ImageSource origen) async {
    final ImagePicker picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: origen, imageQuality: 80);
    
    if (foto != null) {
      setState(() {
        _imagen = File(foto.path);
      });
    }
  }

  // --- FUNCIÓN: OBTENER GPS ---
  Future<void> _obtenerUbicacion() async {
    setState(() => _isLoading = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están desactivados.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos denegados permanentemente.');
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _posicionActual = position);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación obtenida correctamente'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNCIÓN: ENVIAR DATOS A AWS ---
  Future<void> _enviarReporte() async {
    if (_tituloController.text.isEmpty || _descripcionController.text.isEmpty || _imagen == null || _posicionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos, toma una foto y obtén tu ubicación.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      debugPrint('\n=== MI LLAVE SECRETA ES: $token ===\n');

      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/incidencias')
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Authorization': 'Bearer $token', // <-- LA LLAVE CON DISFRAZ VIP
      });

      request.fields['titulo'] = _tituloController.text;
      request.fields['descripcion'] = _descripcionController.text;
      request.fields['estado'] = 'Pendiente';
      request.fields['latitud'] = _posicionActual!.latitude.toString();
      request.fields['longitud'] = _posicionActual!.longitude.toString();

      request.files.add(await http.MultipartFile.fromPath('imagen', _imagen!.path));

      var response = await request.send();
      
      // Leemos la respuesta exacta del servidor de AWS
      final respStr = await response.stream.bytesToString();

      // Permitimos que pase tanto si Laravel devuelve 200 (OK) o 201 (Creado)
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Reporte enviado con éxito!')),
        );
        Navigator.pop(context, true); 
      } else {
        // SI HAY UN ERROR, LO IMPRIMIMOS EN LA CONSOLA PARA LEERLO
        debugPrint('\n=== ERROR REAL DE LARAVEL ===');
        debugPrint('CÓDIGO DE ESTADO: ${response.statusCode}');
        debugPrint('MENSAJE DEL SERVIDOR: $respStr');
        debugPrint('=============================\n');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El servidor rechazó los datos (revisa la consola)')),
        );
      }
    } catch (e) {
      debugPrint('Error de conexión en Flutter: $e');
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
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: _brandBlue),
        title: Row(
          children: [
            Image.asset('assets/logobit.png', height: 28),
            const SizedBox(width: 12),
            Text(
              'Nuevo Reporte',
              style: TextStyle(color: _brandBlue, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- TARJETA DE FORMULARIO ---
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalles del Suceso',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _brandBlue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // CAMPO: TÍTULO
                      TextField(
                        controller: _tituloController,
                        decoration: InputDecoration(
                          labelText: 'Título corto (Ej. Semáforo roto)',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          prefixIcon: Icon(Icons.title, color: Colors.grey.shade500),
                          filled: true,
                          fillColor: _bgLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _brandBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // CAMPO: DESCRIPCIÓN
                      TextField(
                        controller: _descripcionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Describe qué está ocurriendo...',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: Icon(Icons.description_outlined, color: Colors.grey.shade500),
                          ),
                          filled: true,
                          fillColor: _bgLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _brandBlue, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),

                // --- SECCIÓN: EVIDENCIA VISUAL ---
                Text(
                  'Evidencia Fotográfica',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 12),
                
                // VISTA PREVIA DE LA FOTO
                if (_imagen != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16), // <-- CORREGIDO AQUÍ
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        // <-- CORREGIDO AQUÍ: Usamos Colors.black12 que es una constante segura
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                      ],
                      image: DecorationImage(
                        image: FileImage(_imagen!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                
                // --- BOTONES DE CÁMARA Y GALERÍA ---
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: _brandBlue, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: () => _seleccionarImagen(ImageSource.camera),
                        icon: Icon(Icons.camera_alt, color: _brandBlue),
                        label: Text(
                          'CÁMARA',
                          style: TextStyle(color: _brandBlue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: _brandBlue, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: () => _seleccionarImagen(ImageSource.gallery),
                        icon: Icon(Icons.photo_library, color: _brandBlue),
                        label: Text(
                          'GALERÍA',
                          style: TextStyle(color: _brandBlue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // --- SECCIÓN: UBICACIÓN GPS ---
                Text(
                  'Ubicación Satelital',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 12),

                if (_posicionActual != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Ubicación capturada correctamente.', style: TextStyle(color: Colors.green)),
                        ),
                      ],
                    ),
                  ),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF0F9D58), width: 1.5), // Verde Google Maps
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: _obtenerUbicacion,
                  icon: const Icon(Icons.my_location, color: Color(0xFF0F9D58)),
                  label: Text(
                    _posicionActual == null ? 'OBTENER MI UBICACIÓN' : 'ACTUALIZAR UBICACIÓN',
                    style: const TextStyle(color: Color(0xFF0F9D58), fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),

                const SizedBox(height: 40),

                // --- BOTÓN FINAL DE ENVÍO ---
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: _brandBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _enviarReporte,
                    child: const Text(
                      'ENVIAR REPORTE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // --- SPINNER DE CARGA TIPO OVERLAY ---
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}