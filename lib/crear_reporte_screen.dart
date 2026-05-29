import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class CrearReporteScreen extends StatefulWidget {
  const CrearReporteScreen({super.key});

  @override
  State<CrearReporteScreen> createState() => _CrearReporteScreenState();
}

class _CrearReporteScreenState extends State<CrearReporteScreen> {
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  File? _imagen;
  String _latitud = '';
  String _longitud = '';
  bool _isLoading = false;

  // --- NUEVO: FUNCIÓN PARA PROCESAR LA IMAGEN SEGÚN EL ORIGEN ---
  Future<void> _procesarImagen(ImageSource fuente) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: fuente, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() {
        _imagen = File(pickedFile.path);
      });
    }
  }

  // --- NUEVO: MENÚ INFERIOR (BOTTOM SHEET) ---
  void _mostrarMenuDeImagen() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Selecciona una opción',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Tomar Foto con la Cámara'),
                onTap: () {
                  Navigator.of(context).pop(); // Cierra el menú
                  _procesarImagen(ImageSource.camera); // Abre la cámara
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.green),
                title: const Text('Elegir de la Galería'),
                onTap: () {
                  Navigator.of(context).pop(); // Cierra el menú
                  _procesarImagen(ImageSource.gallery); // Abre la galería
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // 2. FUNCIÓN PARA OBTENER EL GPS (Se mantiene intacta)
  Future<void> _obtenerUbicacion() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _latitud = position.latitude.toString();
      _longitud = position.longitude.toString();
    });
    
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Ubicación satelital obtenida!')),
      );
    }
  }

  // 3. FUNCIÓN PARA ENVIAR TODO A AWS
  Future<void> _enviarReporte() async {
    if (_tituloController.text.isEmpty || _descripcionController.text.isEmpty || _latitud.isEmpty || _imagen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faltan datos. Añade una foto y obtén el GPS.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/incidencias'),
      );

      // OJO: En un sistema real, aquí sacaríamos el user_id de SharedPreferences
      request.fields['user_id'] = '1'; 
      request.fields['titulo'] = _tituloController.text;
      request.fields['descripcion'] = _descripcionController.text;
      request.fields['latitud'] = _latitud;
      request.fields['longitud'] = _longitud;

      request.files.add(await http.MultipartFile.fromPath('imagen', _imagen!.path));

      var response = await request.send();

      if (response.statusCode == 201) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incidencia reportada con éxito')),
          );
          Navigator.pop(context, true); 
        }
      } else {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al procesar en el servidor')),
          );
        }
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Reporte')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(labelText: 'Título de la incidencia', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción detallada', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            
            // Botones de Hardware actualizados
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _mostrarMenuDeImagen, // <-- Llamamos al nuevo menú
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Añadir Foto'),
                ),
                ElevatedButton.icon(
                  onPressed: _obtenerUbicacion,
                  icon: const Icon(Icons.location_on),
                  label: const Text('GPS'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Muestra de coordenadas e imagen
            if (_latitud.isNotEmpty) Text('📍 Coordenadas: $_latitud, $_longitud', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (_imagen != null) 
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_imagen!, height: 250, fit: BoxFit.cover),
              ),
            
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue),
                    onPressed: _enviarReporte,
                    child: const Text('ENVIAR REPORTE', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
          ],
        ),
      ),
    );
  }
}