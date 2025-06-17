import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ventadeasientos/main.dart';
import 'package:ventadeasientos/screens/movie_list_screen.dart';

void main() {
  testWidgets('La app se inicia correctamente', (WidgetTester tester) async {
    // Construye nuestra app y dispara un frame
    await tester.pumpWidget(const CinemaApp());

    // Verifica que la pantalla inicial se muestra correctamente
    expect(find.byType(MovieListScreen), findsOneWidget);

    // Si tienes un título en la AppBar, puedes verificarlo
    expect(
      find.text('Cartelera de Cine'),
      findsOneWidget,
    ); // Ajusta esto al título real
  });

  // Puedes agregar más tests para verificar la navegación a la pantalla de compra
  // y la selección de asientos, pero esto requiere más configuración
}
