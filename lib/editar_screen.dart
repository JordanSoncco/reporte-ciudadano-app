import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class EditarScreen extends StatefulWidget {
  final Map<String, dynamic> reporte;

  const EditarScreen({super.key, required this.reporte});

  @override
  State<EditarScreen> createState() => _EditarScreenState();
}

class _EditarScreenState extends State<EditarScreen> {
  late TextEditingController _tituloController;
  late TextEditingController _descripcionController;
  
  File? _nuevaImagen;
  Position? _nuevaPosicion;
  bool _isLoading = false;

  // --- PALETA CORPORATIVA ---
  final Color _brandBlue = const Color(0xFF001B69);
  final Color _bgLight = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.reporte['titulo']);
    _descripcionController = TextEditingController(text: widget.reporte['descripcion']);
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  // --- FUNCIÓN: SELECCIONAR IMAGEN (CÁMARA O GALERÍA) ---
  Future<void> _seleccionarImagen(ImageSource origen) async {
    final ImagePicker picker = ImagePicker();
    final XFile? foto = await picker.pickImage(source: origen, imageQuality: 80);
    
    if (foto != null) {
      setState(() {
        _nuevaImagen = File(foto.path);
      });
    }
  }

  // --- FUNCIÓN: ACTUALIZAR GPS ---
  Future<void> _obtenerNuevaUbicacion() async {
    setState(() => _isLoading = true);
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Los servicios de ubicación están desactivados.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permisos denegados.');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Permisos denegados permanentemente.');

      final position = await Geolocator.getCurrentPosition();
      setState(() => _nuevaPosicion = position);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación actualizada correctamente'), backgroundColor: Colors.green),
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

  // --- FUNCIÓN: GUARDAR CAMBIOS EN AWS ---
  Future<void> _guardarCambios() async {
    if (_tituloController.text.trim().isEmpty || _descripcionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los textos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final idReporte = widget.reporte['id'];

      // Usamos MultipartRequest para poder enviar imágenes, pero como es una edición (PUT), 
      // lo enviamos como POST y le añadimos un campo especial para que Laravel lo entienda como PUT.
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/incidencias/$idReporte')
      );

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Authorization': 'Bearer $token', // <-- NUESTRO DISFRAZ VIP PARA APACHE
      });

      // El truco para Laravel
      request.fields['_method'] = 'PUT';
      
      // Textos actualizados
      request.fields['titulo'] = _tituloController.text.trim();
      request.fields['descripcion'] = _descripcionController.text.trim();

      // Si obtuvimos nuevas coordenadas, las enviamos
      if (_nuevaPosicion != null) {
        request.fields['latitud'] = _nuevaPosicion!.latitude.toString();
        request.fields['longitud'] = _nuevaPosicion!.longitude.toString();
      }

      // Si seleccionamos una nueva foto, la enviamos
      if (_nuevaImagen != null) {
        request.files.add(await http.MultipartFile.fromPath('imagen', _nuevaImagen!.path));
      }

      var response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Reporte actualizado con éxito!')),
        );
        Navigator.pop(context, true);
      } else {
        debugPrint('\n=== ERROR AL ACTUALIZAR ===');
        debugPrint('CÓDIGO: ${response.statusCode}');
        debugPrint('RESPUESTA: $respStr');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar los cambios en el servidor')),
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
    // Foto original del reporte
    final String? imageUrlOriginal = widget.reporte['imagen_ruta'] != null
        ? 'http://52.15.143.102/api-backend/public/${widget.reporte['imagen_ruta']}'
        : null;

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
              'Editar Reporte',
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
                // --- TARJETA DE TEXTOS ---
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
                        'Modifica los detalles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _brandBlue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      TextField(
                        controller: _tituloController,
                        decoration: InputDecoration(
                          labelText: 'Título del Reporte',
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
                      
                      TextField(
                        controller: _descripcionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Descripción detallada',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          alignLabelWithHint: true,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(bottom: 60),
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

                // --- SECCIÓN: ACTUALIZAR FOTO ---
                Text(
                  'Evidencia Fotográfica',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 12),
                
                // Mostrar nueva foto (si eligió una), sino mostrar la original (si tiene)
                if (_nuevaImagen != null || imageUrlOriginal != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                      ],
                      image: _nuevaImagen != null 
                        ? DecorationImage(image: FileImage(_nuevaImagen!), fit: BoxFit.cover)
                        : DecorationImage(image: NetworkImage(imageUrlOriginal!), fit: BoxFit.cover),
                    ),
                  ),

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
                        icon: Icon(Icons.camera_alt, color: _brandBlue, size: 20),
                        label: Text('CÁMARA', style: TextStyle(color: _brandBlue, fontWeight: FontWeight.bold)),
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
                        icon: Icon(Icons.photo_library, color: _brandBlue, size: 20),
                        label: Text('GALERÍA', style: TextStyle(color: _brandBlue, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // --- SECCIÓN: ACTUALIZAR GPS ---
                Text(
                  'Ubicación Satelital',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 12),

                // Indicador visual de la ubicación a guardar
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _nuevaPosicion != null ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _nuevaPosicion != null ? Colors.green.shade200 : Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _nuevaPosicion != null ? Icons.check_circle : Icons.location_on, 
                        color: _nuevaPosicion != null ? Colors.green.shade600 : Colors.blue.shade600
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _nuevaPosicion != null 
                            ? 'Ubicación nueva lista para guardar.' 
                            : 'Manteniendo ubicación original.',
                          style: TextStyle(
                            color: _nuevaPosicion != null ? Colors.green.shade800 : Colors.blue.shade800,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF0F9D58), width: 1.5), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: _obtenerNuevaUbicacion,
                  icon: const Icon(Icons.my_location, color: Color(0xFF0F9D58)),
                  label: const Text(
                    'RE-CAPTURAR MI UBICACIÓN',
                    style: TextStyle(color: Color(0xFF0F9D58), fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),

                const SizedBox(height: 40),

                // --- BOTÓN FINAL DE GUARDAR ---
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
                    onPressed: _isLoading ? null : _guardarCambios,
                    child: const Text(
                      'GUARDAR CAMBIOS',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
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