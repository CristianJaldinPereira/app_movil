import 'dart:math';
import '../screens/purchase_screen.dart'; // Para usar la clase Asiento

class RecomendadorAsientos {
  final int filas;
  final int columnas;
  List<Asiento> asientos;

  RecomendadorAsientos(this.filas, this.columnas, this.asientos);

  // 1. Distancia euclidiana al centro óptimo
  double calcularDistancia(Asiento a) {
    double cf = (filas - 1) / 2;
    double cc = (columnas - 1) / 2;
    return sqrt(pow(a.fila - cf, 2) + pow(a.columna - cc, 2));
  }

  // 2. Penalizaciones por condiciones desfavorables
  double calcularPenalizaciones(Asiento a) {
    double penalizacion = 0;

    // Ejemplo de penalización: asiento al borde (fila 0 o última fila)
    if (a.fila == 0 || a.fila == filas - 1) {
      penalizacion += 2.0;
    }

    // Penalización si está en columna de pasillo (por ejemplo, columnas 0 y columnas-1)
    if (a.columna == 0 || a.columna == columnas - 1) {
      penalizacion += 1.5;
    }

    // Puedes agregar más reglas aquí...

    return penalizacion;
  }

  // 3. Ajustes por preferencias del usuario
  double calcularAjustes(Asiento a, Map<String, dynamic> preferencias) {
    double ajuste = 0;

    // Ejemplo: preferencia por filas delanteras
    if (preferencias['prefiereFilasDelanteras'] == true) {
      ajuste -= (filas - 1 - a.fila) * 0.5; // Recompensa filas delanteras
    }

    // Ejemplo: preferencia por columna central
    if (preferencias['prefiereCentro'] == true) {
      double centro = (columnas - 1) / 2;
      ajuste -=
          (a.columna - centro).abs() * 0.3; // Recompensa columnas centrales
    }

    // Puedes añadir más preferencias

    return ajuste;
  }

  // Score total sumando los tres factores
  double calcularScore(Asiento a, Map<String, dynamic> preferencias) {
    return calcularDistancia(a) +
        calcularPenalizaciones(a) +
        calcularAjustes(a, preferencias);
  }

  // Devuelve los n mejores asientos recomendados según el score
  List<Asiento> recomendar(int n, Map<String, dynamic> preferencias) {
    List<Asiento> libres = asientos.where((a) => !a.ocupado).toList();

    libres.sort(
      (a, b) => calcularScore(
        a,
        preferencias,
      ).compareTo(calcularScore(b, preferencias)),
    );

    return libres.take(n).toList();
  }
}
