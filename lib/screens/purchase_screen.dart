// lib/screens/purchase_screen.dart
import 'package:flutter/material.dart';
import 'movie_list_screen.dart'; // Make sure this path is correct
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math';
import 'package:intl/intl.dart'; // Import for date formatting

// --- Asiento Class ---
// Add unique ID and proper equality checks for collection operations
class Asiento {
  final int fila;
  final int columna;
  bool ocupado;
  bool seleccionado;

  Asiento({
    required this.fila,
    required this.columna,
    this.ocupado = false,
    this.seleccionado = false,
  });

  // Unique identifier for a seat (e.g., "F1C1")
  String get id => "F${fila + 1}C${columna + 1}";

  // Override equals and hashCode for proper list comparisons (e.g., in `recomendados.contains(a)`)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Asiento &&
          runtimeType == other.runtimeType &&
          fila == other.fila &&
          columna == other.columna;

  @override
  int get hashCode => fila.hashCode ^ columna.hashCode;
}

// --- PurchaseScreen Widget ---
class PurchaseScreen extends StatefulWidget {
  final String movieTitle;
  final String imagePath;
  final String? userEmail; // Optional: Pass user email for purchase data

  const PurchaseScreen({
    required this.movieTitle,
    required this.imagePath,
    this.userEmail,
    Key? key,
  }) : super(key: key);

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen>
    with TickerProviderStateMixin {
  final int filas = 6;
  final int columnas = 8;
  List<Asiento> asientos = [];
  List<Asiento> recomendados = [];
  Database? _db;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Track the selected date for the movie screening
  DateTime _selectedDate = DateTime.now();

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

    // Initial setup: Generate seats, init DB, then load occupied seats for initial date
    _initializeScreenData();
    _animationController.forward();
  }

  Future<void> _initializeScreenData() async {
    // Generate all physical seats once
    _generarAsientosPhysical();
    await _inicializarDB();
    // Load occupied seats for the initially selected date
    await _loadOccupiedSeatsForDate(_selectedDate);
    // Ensure UI reflects initial state after loading
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    // It's good practice to close the database when the screen is disposed
    // if this is the primary screen interacting with it.
    _db?.close();
    super.dispose();
  }

  // --- Database Methods ---
  Future<void> _inicializarDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'compras.db');
    _db = await openDatabase(
      path,
      version: 5, // Increment version for new `asientos_ocupados` table
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS compras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT,
            correo TEXT,
            pelicula TEXT,
            asiento TEXT, -- e.g., "F1C1"
            fecha TEXT -- Store as 'YYYY-MM-DD'
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS usuarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT,
            correo TEXT UNIQUE,
            contrasena TEXT,
            rol TEXT
          )
        ''');
        // New table to track occupied seats for specific movies and dates
        await db.execute('''
          CREATE TABLE IF NOT EXISTS asientos_ocupados (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pelicula TEXT NOT NULL,
            fecha TEXT NOT NULL, -- Store as 'YYYY-MM-DD'
            asiento_id TEXT NOT NULL, -- e.g., "F1C1"
            UNIQUE(pelicula, fecha, asiento_id) ON CONFLICT IGNORE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Handle database schema upgrades
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
          // Add 'fecha' column to 'compras' if it doesn't exist
          try {
            await db.execute('ALTER TABLE compras ADD COLUMN fecha TEXT;');
          } catch (e) {
            // Column might already exist if created manually or in a previous iteration
            print(
              'DEBUG: Column "fecha" already exists in "compras" table. Skipping ALTER.',
            );
          }
        }
        if (oldVersion < 4) {
          // Create the new asientos_ocupados table
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
  }

  // Save purchase and mark seats as occupied
  Future<void> _guardarCompra(
    String nombre,
    String correo,
    String pelicula,
    String asientoId, // Use asientoId for consistency
    String fechaStr, // 'YYYY-MM-DD' format
  ) async {
    if (_db == null) return;
    await _db!.transaction((txn) async {
      // 1. Insert into 'compras' table (purchase history)
      await txn.insert(
        'compras',
        {
          'nombre': nombre,
          'correo': correo,
          'pelicula': pelicula,
          'asiento': asientoId,
          'fecha': fechaStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      ); // Use replace to update if somehow duplicated

      // 2. Insert into 'asientos_ocupados' table (seat availability for specific show)
      await txn.insert(
        'asientos_ocupados',
        {'pelicula': pelicula, 'fecha': fechaStr, 'asiento_id': asientoId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      ); // Ignore if already exists (e.g., from double-tap)
    });
  }

  // Load occupied seats for a given date and movie
  Future<void> _loadOccupiedSeatsForDate(DateTime date) async {
    if (_db == null) return;

    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    print(
      'DEBUG: Loading occupied seats for ${widget.movieTitle} on $formattedDate',
    );

    final List<Map<String, dynamic>> occupiedRecords = await _db!.query(
      'asientos_ocupados',
      where: 'pelicula = ? AND fecha = ?',
      whereArgs: [widget.movieTitle, formattedDate],
    );

    if (mounted) {
      setState(() {
        // Reset all seats to not occupied and not selected first
        for (var asiento in asientos) {
          asiento.ocupado = false;
          asiento.seleccionado =
              false; // Deselect any previously selected seats
        }

        // Mark seats as occupied based on loaded data
        for (var record in occupiedRecords) {
          final asientoId = record['asiento_id'] as String; // e.g., "F1C1"
          // Find the corresponding asiento object and mark it occupied
          final asientoToOccupy = asientos.firstWhere(
            (a) => a.id == asientoId,
            orElse:
                () => Asiento(
                  fila: -1,
                  columna: -1,
                ), // Should not happen if logic is sound
          );
          if (asientoToOccupy.fila != -1) {
            // Check if a valid seat was found
            asientoToOccupy.ocupado = true;
          }
        }
        print('DEBUG: ${occupiedRecords.length} seats loaded as occupied.');
      });
    }
  }

  // --- Seat Generation & Logic ---
  // This function now just generates the physical layout of seats
  void _generarAsientosPhysical() {
    asientos = List.generate(filas * columnas, (index) {
      int fila = index ~/ columnas;
      int col = index % columnas;
      return Asiento(
        fila: fila,
        columna: col,
      ); // Initially, no seats are occupied randomly
    });
  }

  double _calcularScore(Asiento a) {
    double cf = (filas - 1) / 2;
    double cc = (columnas - 1) / 2;
    return sqrt(pow(a.fila - cf, 2) + pow(a.columna - cc, 2));
  }

  void _recomendar() {
    if (!mounted) return; // Always check mounted before setState
    setState(() {
      // Clear previous recommendations and selection
      for (var asiento in asientos) {
        asiento.seleccionado = false;
      }
      recomendados.clear();

      List<Asiento> libres = asientos.where((a) => !a.ocupado).toList();
      libres.sort((a, b) => _calcularScore(a).compareTo(_calcularScore(b)));
      recomendados = libres.take(3).toList(); // Take top 3 recommended
    });
  }

  Color _colorAsiento(Asiento a) {
    if (a.ocupado) return Colors.grey.shade400;
    if (a.seleccionado) return const Color(0xFFFF6B35);
    if (recomendados.contains(a)) return const Color(0xFF4CAF50);
    return const Color(0xFF2196F3);
  }

  IconData _iconoAsiento(Asiento a) {
    if (a.ocupado) return Icons.close;
    if (a.seleccionado) return Icons.check;
    if (recomendados.contains(a)) return Icons.star;
    return Icons.event_seat;
  }

  // --- Purchase Flow ---
  void _comprarAsientosSeleccionados(BuildContext ctx) async {
    final seleccionados = asientos.where((a) => a.seleccionado).toList();

    if (seleccionados.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: const Text("Selecciona al menos un asiento"),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    final nombreController = TextEditingController(
      text: widget.userEmail?.split('@').first ?? '',
    );
    final correoController = TextEditingController(text: widget.userEmail);
    DateTime? tempFechaFuncion =
        _selectedDate; // Initialize with the current selected date

    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerDialogContext, setStateDialog) {
            // Use innerDialogContext for actions inside dialog
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.shopping_cart, color: Color(0xFF2196F3)),
                  const SizedBox(width: 8),
                  const Text("Finalizar Compra"),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Película: ${widget.movieTitle}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Asientos: ${seleccionados.map((a) => a.id).join(", ")}",
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Total: \$${seleccionados.length * 150} MXN",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nombreController,
                      decoration: InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: correoController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Date selection within the dialog
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context:
                                    innerDialogContext, // Use inner context for date picker
                                initialDate: tempFechaFuncion ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: Color(0xFF2196F3),
                                        onPrimary: Colors.white,
                                        onSurface: Colors.black87,
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF2196F3,
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setStateDialog(() {
                                  // Update dialog's state
                                  tempFechaFuncion = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade50,
                              ),
                              child: Text(
                                tempFechaFuncion == null
                                    ? 'Seleccionar fecha de función'
                                    : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(tempFechaFuncion!),
                                style: TextStyle(
                                  color:
                                      tempFechaFuncion == null
                                          ? Colors.grey
                                          : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (mounted) {
                      Navigator.of(innerDialogContext).pop(); // Pop the dialog
                    }
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    String nombre = nombreController.text.trim();
                    String correo = correoController.text.trim();

                    if (nombre.isEmpty ||
                        correo.isEmpty ||
                        tempFechaFuncion == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: const Text(
                              "Llena todos los campos y selecciona la fecha",
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    // Format date consistently for DB storage
                    String fechaStr = DateFormat(
                      'yyyy-MM-dd',
                    ).format(tempFechaFuncion!);
                    for (var asiento in seleccionados) {
                      await _guardarCompra(
                        nombre,
                        widget.userEmail ?? correo,
                        widget.movieTitle,
                        asiento.id,
                        fechaStr,
                      );
                      asiento.ocupado = true;
                      asiento.seleccionado = false;
                    }

                    // Crucial: Update the _selectedDate state of the PurchaseScreen
                    // so the main screen updates when the dialog closes.
                    if (mounted) {
                      setState(() {
                        _selectedDate = tempFechaFuncion!;
                        recomendados
                            .clear(); // Clear recommendations after purchase
                      });
                      // No need to call _loadOccupiedSeatsForDate here, as setState
                      // will rebuild and the `ocupado` state is already updated.
                      // If you were not updating locally, you would call it here.
                    }

                    if (!mounted) return;
                    Navigator.of(innerDialogContext).pop(); // Pop the dialog

                    if (mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text("¡Compra realizada con éxito!"),
                            ],
                          ),
                          backgroundColor: const Color(0xFF4CAF50),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );

                      // Navigate back to movie list, ensuring it's still mounted
                      Navigator.pushAndRemoveUntil(
                        ctx,
                        MaterialPageRoute(builder: (_) => MovieListScreen()),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text('Confirmar Compra'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- UI Building Methods ---
  // Function to select a date for the movie screening
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 90),
      ), // 3 months from now
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2196F3), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black87, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2196F3), // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
          recomendados.clear(); // Clear recommendations when date changes
        });
        // Load occupied seats for the newly selected date
        await _loadOccupiedSeatsForDate(_selectedDate);
      }
    }
  }

  Widget _buildLeyenda() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Leyenda',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLeyendaItem(Colors.grey.shade400, Icons.close, 'Ocupado'),
              _buildLeyendaItem(
                const Color(0xFF2196F3),
                Icons.event_seat,
                'Disponible',
              ),
              _buildLeyendaItem(
                const Color(0xFF4CAF50),
                Icons.star,
                'Recomendado',
              ),
              _buildLeyendaItem(
                const Color(0xFFFF6B35),
                Icons.check,
                'Seleccionado',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeyendaItem(Color color, IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildPantalla() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade300, Colors.grey.shade100],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'PANTALLA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asientosSeleccionados = asientos.where((a) => a.seleccionado).length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.movieTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Movie Image
            Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(widget.imagePath, fit: BoxFit.cover),
              ),
            ),

            // Date Selection Row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMMM yyyy').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF2196F3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _recomendar,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text("Recomendar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          asientosSeleccionados > 0
                              ? () => _comprarAsientosSeleccionados(context)
                              : null,
                      icon: const Icon(Icons.shopping_cart),
                      label: Text("Comprar ($asientosSeleccionados)"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Legend
            _buildLeyenda(),

            // Screen Display
            _buildPantalla(),

            // Seats Grid
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnas,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: asientos.length,
                  itemBuilder: (context, index) {
                    final a = asientos[index];
                    return GestureDetector(
                      onTap: () {
                        if (!a.ocupado) {
                          if (mounted) {
                            // Check mounted before setState
                            setState(() {
                              a.seleccionado = !a.seleccionado;
                              // Clear recommendations when a seat is manually selected
                              if (a.seleccionado) {
                                recomendados.clear();
                              }
                            });
                          }
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          color: _colorAsiento(a),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow:
                              a.seleccionado
                                  ? [
                                    BoxShadow(
                                      color: _colorAsiento(a).withOpacity(0.4),
                                      spreadRadius: 2,
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _iconoAsiento(a),
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              a.id, // Use the Asiento's ID
                              style: TextStyle(
                                color:
                                    a.ocupado ? Colors.white54 : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
