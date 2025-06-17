// lib/screens/movie_list_screen.dart
import 'package:flutter/material.dart';
import 'purchase_screen.dart'; // Asegúrate de que esta ruta sea correcta
import 'historial_screen.dart'; // Importa HistorialScreen para la navegación

class Movie {
  final String title;
  final String image;
  final String genre;
  final double rating;
  final String duration;

  Movie(this.title, this.image, this.genre, this.rating, this.duration);
}

class MovieListScreen extends StatelessWidget {
  final Map<String, dynamic>? usuario;
  MovieListScreen({Key? key, this.usuario}) : super(key: key);

  final List<Movie> peliculas = [
    Movie(
      'Avengers: Endgame',
      'assets/avengers.jpg',
      'Acción/Aventura',
      8.4,
      '3h 1m',
    ),
    Movie(
      'Spider-Man: No Way Home',
      'assets/spiderman.jpg',
      'Acción/Fantasía',
      8.2,
      '2h 28m',
    ),
    Movie('The Batman', 'assets/batman.jpg', 'Acción/Crimen', 7.8, '2h 56m'),
    Movie('Dune', 'assets/dune.jpg', 'Ciencia Ficción', 8.0, '2h 35m'),
    Movie(
      'Top Gun: Maverick',
      'assets/topgun.jpg',
      'Acción/Drama',
      8.3,
      '2h 11m',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final String nombreUsuario = usuario?['nombre'] ?? 'Usuario';
    final String correoUsuario = usuario?['correo'] ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple[700]!, Colors.indigo[600]!],
            ),
          ),
        ),
        title: Text(
          'Hola, $nombreUsuario',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.history, color: Colors.white, size: 24),
              onPressed: () {
                // Navegación con push para que HistorialScreen se recargue
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            HistorialScreen(usuarioCorreo: correoUsuario),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListView.builder(
          itemCount: peliculas.length,
          itemBuilder: (context, index) {
            final pelicula = peliculas[index];
            return Container(
              margin: EdgeInsets.only(bottom: 16),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.grey[50]!],
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      // <-- ¡Añadido 'async' aquí!
                      // Navegar a PurchaseScreen y esperar el resultado.
                      // Esto no necesita devolver un resultado específico si HistorialScreen ya se recarga en initState.
                      await Navigator.push(
                        // <-- ¡Añadido 'await' aquí!
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => PurchaseScreen(
                                movieTitle: pelicula.title,
                                imagePath: pelicula.image,
                                userEmail: correoUsuario,
                              ),
                        ),
                      );
                      // Cuando la PurchaseScreen se cierre (regrese), este código continuará.
                      // No se necesita lógica explícita de "refrescar" aquí para el historial
                      // porque HistorialScreen ya se recarga en su initState al ser visitado.
                    },
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'movie_${pelicula.title}',
                            child: Container(
                              width: 80,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  pelicula.image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: Icon(
                                        Icons.movie,
                                        size: 40,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pelicula.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    pelicula.genre,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.deepPurple[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      pelicula.rating.toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Icon(
                                      Icons.schedule,
                                      color: Colors.grey[600],
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      pelicula.duration,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.deepPurple[400]!,
                                  Colors.indigo[500]!,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
