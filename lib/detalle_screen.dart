import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'editar_screen.dart';

class DetalleScreen extends StatefulWidget {
  final Map<String, dynamic> reporte;

  const DetalleScreen({super.key, required this.reporte});

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> {
  bool _isLoading = false;

  // --- FUNCIÓN PARA ABRIR GOOGLE MAPS ---
  Future<void> _abrirMapa() async {
    final lat = widget.reporte['latitud'];
    final lng = widget.reporte['longitud'];
    
    // Inyectamos las coordenadas reales en la URL
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error al intentar abrir el mapa: $e');
    }
  }

  // --- NUEVA FUNCIÓN: ELIMINAR REPORTE EN AWS ---
  Future<void> _eliminarReporte() async {
    // 1. Mostramos un cuadro de diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Reporte'),
        content: const Text('¿Estás seguro de que deseas eliminar este reporte? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return; // Si el usuario cancela, salimos

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final idReporte = widget.reporte['id']; // Obtenemos el ID del reporte actual

      final response = await http.delete(
        Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/incidencias/$idReporte'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token', // Mandamos el token de seguridad
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte eliminado con éxito')),
        );
        // Regresamos a la pantalla anterior pasándole un "true" para que sepa que debe recargar la lista
        Navigator.pop(context, true); 
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar el reporte')),
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

  // --- FUNCIÓN: EDITAR REPORTE ---
  Future<void> _editarReporte() async {
    final seActualizo = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarScreen(reporte: widget.reporte),
      ),
    );

    // Si regresamos con un 'true' (se guardó con éxito), 
    // cerramos esta pantalla para que el HomeScreen recargue la lista
    if (seActualizo == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = widget.reporte['imagen_ruta'] != null
        ? 'http://52.15.143.102/api-backend/public/${widget.reporte['imagen_ruta']}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Reporte'),
        centerTitle: true,
        // --- NUEVOS BOTONES DE ACCIÓN (LÁPIZ Y BASURERO) ---
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: _isLoading ? null : _editarReporte,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isLoading ? null : _eliminarReporte,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) // Spinner mientras se elimina
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            
            Text(
              widget.reporte['titulo'] ?? 'Sin título', 
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(widget.reporte['estado'] ?? 'Pendiente'),
              backgroundColor: Colors.orange.shade100,
              labelStyle: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 32),
            
            const Text('Descripción:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            Text(widget.reporte['descripcion'] ?? 'Sin descripción', style: const TextStyle(fontSize: 16)),
            const Divider(height: 32),
            
            const Text('Ubicación Satelital:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            Text('Latitud: ${widget.reporte['latitud']}\nLongitud: ${widget.reporte['longitud']}'),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                onPressed: _abrirMapa,
                icon: const Icon(Icons.map, color: Colors.white),
                label: const Text('VER EN GOOGLE MAPS', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}