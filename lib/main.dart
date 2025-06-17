import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'screens/login_screen.dart';
import 'screens/movie_list_screen.dart';
import 'screens/historial_screen.dart';
import 'services/db_helper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('es');

  final db = await DBHelper.getDatabase();
  final existing = await db.query('usuarios');
  if (existing.isEmpty) {
    await db.insert('usuarios', {
      'nombre': 'Admin',
      'correo': 'admin@cine.com',
      'contrasena': '1234',
      'rol': 'admin',
    });
    await db.insert('usuarios', {
      'nombre': 'Usuario',
      'correo': 'usuario@cine.com',
      'contrasena': '1234',
      'rol': 'usuario',
    });
    print('Usuarios de prueba insertados');
  }

  runApp(const CinemaApp());
}

class CinemaApp extends StatelessWidget {
  const CinemaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cinema App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        if (settings.name == '/historial') {
          final correo = settings.arguments as String? ?? '';
          return MaterialPageRoute(
            builder: (_) => HistorialScreen(usuarioCorreo: correo),
          );
        }
        return null;
      },
      routes: {
        '/login': (context) => const LoginScreen(),
        '/movies': (context) => MovieListScreen(),
      },
    );
  }
}
