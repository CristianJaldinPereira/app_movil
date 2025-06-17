import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart'; // Importa esto para el formato de fechas

class HistorialScreen extends StatefulWidget {
  final String usuarioCorreo;
  const HistorialScreen({required this.usuarioCorreo, Key? key})
    : super(key: key);

  @override
  _HistorialScreenState createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen>
    with TickerProviderStateMixin {
  Database? _database;
  List<Map<String, dynamic>> compras = [];
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Se inicializa la base de datos y se cargan las compras automáticamente al entrar a la pantalla
    _initializeDatabaseAndLoadCompras();
  }

  Future<void> _initializeDatabaseAndLoadCompras() async {
    try {
      await abrirBaseDeDatos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al inicializar el historial: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Asegura que isLoading siempre se desactive al finalizar la inicialización
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _database?.close();
    super.dispose();
  }

  Future<void> abrirBaseDeDatos() async {
    try {
      final pathDB = await getDatabasesPath();
      _database = await openDatabase(
        p.join(pathDB, 'compras.db'),
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS compras(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT,
              correo TEXT,
              pelicula TEXT,
              asiento TEXT,
              fecha TEXT
            )
          ''');
          // CORRECCIÓN: Eliminadas las creaciones duplicadas de usuarios y asientos_ocupados aquí
        },
        version: 4, // ¡Versión consistente con PurchaseScreen y LoginScreen!
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS usuarios (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nombre TEXT,
                correo TEXT UNIQUE,
                contrasena TEXT,
                rol TEXT
              )
            ''');
          }
          if (oldVersion < 3) {
            try {
              await db.execute('ALTER TABLE compras ADD COLUMN fecha TEXT;');
            } catch (e) {
              print(
                'DEBUG: Column "fecha" already exists in "compras" table. Skipping ALTER.',
              );
            }
          }
          if (oldVersion < 4) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS asientos_ocupados (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                pelicula TEXT NOT NULL,
                fecha TEXT NOT NULL,
                asiento_id TEXT NOT NULL,
                UNIQUE(pelicula, fecha, asiento_id) ON CONFLICT IGNORE
              )
            ''');
          }
        },
      );
      if (!mounted) return;
      await cargarCompras(); // Llama a cargarCompras una vez que la DB esté abierta
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir la base de datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> cargarCompras() async {
    try {
      if (_database == null || !_database!.isOpen) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La base de datos no está abierta.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      // Imprime el correo del usuario para depuración
      print('DEBUG: Cargando compras para el correo: ${widget.usuarioCorreo}');

      final datos = await _database!.query(
        'compras',
        where: 'correo = ?',
        whereArgs: [widget.usuarioCorreo],
        orderBy: 'fecha DESC, id DESC', // Ordenar por fecha más reciente
      );

      // Imprime la cantidad de compras encontradas para depuración
      print('DEBUG: Cantidad de compras encontradas: ${datos.length}');
      if (datos.isEmpty) {
        print('DEBUG: No se encontraron compras para este usuario.');
      } else {
        print('DEBUG: Primer compra encontrada: ${datos.first}');
      }

      if (!mounted) return;
      setState(() {
        compras = datos;
        isLoading = false; // Se asegura de que se desactive el loading
      });
      _animationController.forward(
        from: 0.0,
      ); // Reinicia la animación al cargar
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar las compras: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('ERROR: Error al cargar compras: $e'); // Para depuración
    }
  }

  String _getUserName() {
    return widget.usuarioCorreo
        .split('@')
        .first
        .split('.')
        .where((name) => name.isNotEmpty)
        .map((name) => name[0].toUpperCase() + name.substring(1).toLowerCase())
        .join(' ');
  }

  String _formatEmail(String email) {
    if (email.length > 20) {
      return '${email.substring(0, 17)}...';
    }
    return email;
  }

  IconData _getMovieIcon(String movieTitle) {
    final titleLower = movieTitle.toLowerCase();
    if (titleLower.contains('acción') || titleLower.contains('action')) {
      return Icons.local_fire_department;
    } else if (titleLower.contains('comedia') ||
        titleLower.contains('comedy')) {
      return Icons.sentiment_very_satisfied;
    } else if (titleLower.contains('terror') || titleLower.contains('horror')) {
      return Icons.psychology;
    } else if (titleLower.contains('romance')) {
      return Icons.favorite;
    } else if (titleLower.contains('drama')) {
      return Icons.theater_comedy;
    } else if (titleLower.contains('ciencia ficción') ||
        titleLower.contains('scifi')) {
      return Icons.rocket_launch;
    }
    return Icons.movie;
  }

  Color _getCardColor(int index) {
    final colors = [
      const Color(0xFF6366F1), // Azul violeta
      const Color(0xFF8B5CF6), // Morado
      const Color(0xFF06B6D4), // Cian
      const Color(0xFF10B981), // Verde esmeralda
      const Color(0xFFF59E0B), // Naranja ámbar
      const Color(0xFFEF4444), // Rojo
      const Color(0xFFEC4899), // Rosa
      const Color(0xFF3B82F6), // Azul
    ];
    return colors[index % colors.length];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.movie_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Aún no has comprado boletos!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando compres tu primer boleto,\naparecerá aquí tu historial',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              if (mounted)
                Navigator.pop(context); // Volver a la pantalla anterior
            },
            icon: const Icon(Icons.local_movies),
            label: const Text('Ver Películas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando historial...',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildCompraCard(Map<String, dynamic> compra, int index) {
    final cardColor = _getCardColor(index);
    final movieIcon = _getMovieIcon(compra['pelicula'] ?? '');

    // Parsear la fecha del string a DateTime
    DateTime? purchaseDate;
    if (compra['fecha'] != null) {
      try {
        purchaseDate = DateTime.parse(compra['fecha']);
      } catch (e) {
        print('Error parsing date: ${compra['fecha']} - $e');
      }
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.0, 0.5 + (index * 0.1)),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Interval(
                (index * 0.1).clamp(0.0, 0.7),
                ((index * 0.1) + 0.3).clamp(0.3, 1.0),
                curve: Curves.easeOutBack,
              ),
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: cardColor.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cardColor, cardColor.withOpacity(0.8)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                movieIcon,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    compra['pelicula'] ?? 'Película',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Compra #${compra['id']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cliente:',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      compra['nombre'] ?? 'Sin nombre',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_seat,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Asiento:',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        compra['asiento'] ?? 'Sin asiento',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.email,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Email:',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatEmail(compra['correo'] ?? ''),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Función:',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      // ¡Formatea la fecha de forma amigable!
                                      purchaseDate != null
                                          ? DateFormat(
                                            'dd \'de\' MMMM \'de\' yyyy',
                                            'es', // Asegúrate de tener el paquete intl y haber importado 'es'
                                          ).format(purchaseDate)
                                          : 'Fecha desconocida',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mi Historial',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              _getUserName(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (mounted) Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => isLoading = true);
              cargarCompras(); // Recarga explícita si el usuario presiona el botón
            },
          ),
        ],
      ),
      body:
          isLoading
              ? _buildLoadingState()
              : compras.isEmpty
              ? _buildEmptyState()
              : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.confirmation_number,
                            color: Color(0xFF6366F1),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total de compras',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '${compras.length} ${compras.length == 1 ? 'boleto' : 'boletos'}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '✓ Activo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: compras.length,
                      itemBuilder: (context, index) {
                        return _buildCompraCard(compras[index], index);
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
