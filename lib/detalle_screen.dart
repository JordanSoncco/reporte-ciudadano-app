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

  // --- PALETA CORPORATIVA ---
  final Color _brandBlue = const Color(0xFF001B69);
  final Color _midnightBlue = const Color(0xFF040A22); // Azul cinemático para fondo de foto

  // --- FUNCIÓN PARA ABRIR GOOGLE MAPS ---
  Future<void> _abrirMapa() async {
    final lat = widget.reporte['latitud'];
    final lng = widget.reporte['longitud'];
    
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng?q=$lat,$lng');
    
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error al intentar abrir el mapa: $e');
    }
  }

  // --- FUNCIÓN: ELIMINAR REPORTE EN AWS ---
  Future<void> _eliminarReporte() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Reporte', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que deseas eliminar este reporte? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final idReporte = widget.reporte['id'];

      final response = await http.delete(
        Uri.parse('http://52.15.143.102/api-backend/public/index.php/api/incidencias/$idReporte'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'X-Authorization': 'Bearer $token', // <-- ¡EL DISFRAZ VIP PARA APACHE!
        },
      );

      // Aceptamos tanto 200 (OK) como 204 (Sin contenido, típico de eliminaciones exitosas)
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte eliminado con éxito')),
        );
        Navigator.pop(context, true); 
      } else {
        debugPrint('Error al eliminar: ${response.statusCode} - ${response.body}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al eliminar el reporte en el servidor')),
        );
      }
    } catch (e) {
      debugPrint('Error de red al eliminar: $e');
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

    if (seActualizo == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  // --- FUNCIÓN: VISOR DE IMAGEN EN PANTALLA COMPLETA ---
  void _verImagenCompleta(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = widget.reporte['imagen_ruta'] != null
        ? 'http://52.15.143.102/api-backend/public/${widget.reporte['imagen_ruta']}'
        : null;

    return Scaffold(
      backgroundColor: Colors.white, // El fondo principal ahora es blanco
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _brandBlue),
        title: Text(
          'Detalle del Reporte',
          style: TextStyle(color: _brandBlue, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: _brandBlue),
            onPressed: _isLoading ? null : _editarReporte,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _isLoading ? null : _eliminarReporte,
          ),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: _brandBlue)) 
        : SingleChildScrollView(
            child: Stack(
              children: [
                // --- CAPA INFERIOR: VISOR DE IMAGEN CINEMÁTICO ---
                if (imageUrl != null)
                  GestureDetector(
                    onTap: () => _verImagenCompleta(imageUrl),
                    child: Container(
                      width: double.infinity,
                      height: 340, // Altura fija de la zona de imagen
                      color: _midnightBlue, // Fondo oscuro profundo
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.contain, // Muestra la imagen completa
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) => 
                                const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                          ),
                          // Botón de zoom reubicado arriba a la derecha
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.zoom_out_map, color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // --- CAPA SUPERIOR: TARJETA DE INFORMACIÓN DESLIZABLE ---
                Container(
                  // Si hay imagen, la tarjeta empieza un poco más arriba para superponerse. 
                  // Si no hay imagen, empieza desde arriba (0).
                  margin: EdgeInsets.only(top: imageUrl != null ? 300 : 0),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    // Borde redondeado SOLO en la parte superior para dar efecto de panel inferior
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      if (imageUrl != null) // Sombra solo si está superponiéndose a la imagen
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pequeña "pestaña" visual (indicador decorativo de arrastre)
                      if (imageUrl != null)
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                      Text(
                        widget.reporte['titulo'] ?? 'Sin título', 
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.w800,
                          color: _brandBlue,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildEstadoBadge(widget.reporte['estado'] ?? 'Pendiente'),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Divider(),
                      ),
                      
                      Row(
                        children: [
                          Icon(Icons.description_outlined, color: _brandBlue, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Descripción del suceso', 
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.grey.shade800
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.reporte['descripcion'] ?? 'Sin descripción', 
                        style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5)
                      ),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Divider(),
                      ),
                      
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: _brandBlue, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Ubicación Satelital', 
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.grey.shade800
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('Latitud', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('${widget.reporte['latitud']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(height: 30, width: 1, color: Colors.grey.shade300),
                            Column(
                              children: [
                                Text('Longitud', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('${widget.reporte['longitud']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // --- BOTÓN DE MAPA ESTILIZADO ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: const Color(0xFF0F9D58), // Verde Google Maps
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _abrirMapa,
                          icon: const Icon(Icons.map, color: Colors.white),
                          label: const Text(
                            'VER EN EL MAPA', 
                            style: TextStyle(
                              color: Colors.white, 
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            )
                          ),
                        ),
                      ),
                      const SizedBox(height: 20), // Margen extra al fondo
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}