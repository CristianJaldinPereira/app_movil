// lib/services/db_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;
  static const int _databaseVersion = 3; // <-- ¡INCREMENTA LA VERSIÓN AQUÍ!
  // (Antes era 2, ahora es 3)

  static Future<Database> getDatabase() async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'compras.db');
    _db = await openDatabase(
      path,
      version: _databaseVersion, // Usa la nueva versión
      onCreate: (db, version) async {
        // Se crea la base desde cero (cuando no existe)
        // Asegúrate de que todas las tablas y columnas necesarias existan
        await db.execute('''
          CREATE TABLE IF NOT EXISTS usuarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT,
            correo TEXT UNIQUE,
            contrasena TEXT,
            rol TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS compras (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT,
            correo TEXT,
            pelicula TEXT,
            asiento TEXT,
            fecha TEXT -- <-- ¡Añadida la columna 'fecha' aquí!
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS asientos_ocupados (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pelicula TEXT NOT NULL,
            fecha TEXT NOT NULL,
            asiento_id TEXT NOT NULL,
            UNIQUE(pelicula, fecha, asiento_id) ON CONFLICT IGNORE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Se ejecuta al subir la versión, para crear tablas faltantes o añadir columnas
        if (oldVersion < 2) {
          // Si vienes de la versión 1 o inferior, asegura que 'usuarios' existe
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
          // <-- ¡Nueva migración para la versión 3!
          // Aseguramos que la tabla 'compras' tenga la columna 'fecha'
          try {
            await db.execute('ALTER TABLE compras ADD COLUMN fecha TEXT;');
            print(
              'DEBUG (DBHelper): Columna "fecha" añadida a la tabla "compras".',
            );
          } catch (e) {
            // Esto se capturará si la columna ya existe por alguna razón
            print(
              'DEBUG (DBHelper): Error al añadir columna "fecha" a "compras": $e',
            );
            print(
              'DEBUG (DBHelper): Posiblemente la columna "fecha" ya existe. Saltando ALTER.',
            );
          }
          // Asegúrate también de crear la tabla 'asientos_ocupados' si no existía antes de v3
          await db.execute('''
            CREATE TABLE IF NOT EXISTS asientos_ocupados (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              pelicula TEXT NOT NULL,
              fecha TEXT NOT NULL,
              asiento_id TEXT NOT NULL,
              UNIQUE(pelicula, fecha, asiento_id) ON CONFLICT IGNORE
            )
          ''');
          print(
            'DEBUG (DBHelper): Tabla "asientos_ocupados" verificada/creada en v3.',
          );
        }
        // Puedes agregar más migraciones para futuras versiones (oldVersion < 4, etc.)
      },
    );
    return _db!;
  }

  // Método para registrar usuario (estático)
  static Future<int> registrarUsuario(
    String nombre,
    String correo,
    String contrasena,
    String rol,
  ) async {
    final db = await getDatabase();
    try {
      final id = await db.insert(
        'usuarios',
        {
          'nombre': nombre,
          'correo': correo,
          'contrasena': contrasena,
          'rol': rol,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      ); // Usa replace si quieres que se actualice si ya existe
      print(
        'DEBUG (DBHelper): Usuario registrado/actualizado: $correo, ID: $id',
      );
      return id;
    } catch (e) {
      print('ERROR (DBHelper): Error al registrar usuario $correo: $e');
      return -1; // error si el correo ya existe
    }
  }

  // Método para login de usuario (estático)
  static Future<Map<String, dynamic>?> loginUsuario(
    String correo,
    String contrasena,
  ) async {
    final db = await getDatabase();
    final result = await db.query(
      'usuarios',
      where: 'correo = ? AND contrasena = ?',
      whereArgs: [correo, contrasena],
    );
    if (result.isNotEmpty) {
      print('DEBUG (DBHelper): Login exitoso para: $correo');
      return result.first;
    } else {
      print('DEBUG (DBHelper): Login fallido para: $correo');
      return null;
    }
  }

  // Método para listar usuarios por rol (estático)
  static Future<List<Map<String, dynamic>>> listarUsuariosPorRol(
    String rol,
  ) async {
    final db = await getDatabase();
    print('DEBUG (DBHelper): Listando usuarios con rol: $rol');
    return await db.query('usuarios', where: 'rol = ?', whereArgs: [rol]);
  }

  // *** MÉTODO PARA INSERTAR COMPRA (CRUCIAL PARA EL HISTORIAL) ***
  static Future<int> insertCompra(Map<String, dynamic> compra) async {
    final db = await getDatabase();
    try {
      final id = await db.insert(
        'compras',
        compra,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print(
        'DEBUG (DBHelper): Compra insertada: ${compra['pelicula']} para ${compra['correo']}, ID: $id',
      );
      return id;
    } catch (e) {
      print('ERROR (DBHelper): Error al insertar compra: $e');
      return -1; // Retorna -1 en caso de error
    }
  }

  // *** MÉTODO PARA OBTENER COMPRAS (USADO POR HistorialScreen) ***
  static Future<List<Map<String, dynamic>>> getComprasByCorreo(
    String correo,
  ) async {
    final db = await getDatabase();
    print('DEBUG (DBHelper): Obteniendo compras para: $correo');
    final compras = await db.query(
      'compras',
      where: 'correo = ?',
      whereArgs: [correo],
      orderBy: 'fecha DESC, id DESC', // ¡Ahora 'fecha' existirá!
    );
    print(
      'DEBUG (DBHelper): Compras encontradas para $correo: ${compras.length}',
    );
    return compras;
  }
}
