# 🎬 Cinema App

Aplicación móvil desarrollada con **Flutter** para la compra de boletos de cine, con sistema de autenticación y gestión de historial de compras.

## 🛠 Requisitos

Antes de comenzar, asegúrate de tener instalado lo siguiente:

- Flutter SDK (versión recomendada: 3.19 o superior)
- Android Studio (o VSCode con extensiones para Flutter)
- Dispositivo/emulador Android
- Android NDK **27.0.12077973**

## 🚀 Pasos para correr el proyecto

1. **Clonar el repositorio**

```bash
git clone <URL_DEL_REPOSITORIO>
cd app_movil
```

2. **Instalar dependencias**
```bash
flutter pub get
```

3. **Correr el proyecto**
```bash
flutter run
```

## 👥 Usuarios de prueba

Cuando la app se inicia por primera vez, se crean automáticamente dos usuarios en la base de datos local:

| Rol     | Correo              | Contraseña |
|---------|---------------------|------------|
| Admin   | admin@cine.com      | 1234       |
| Usuario | usuario@cine.com    | 1234       |

## 📁 Estructura del proyecto

```bash
lib/
├── main.dart # Punto de entrada de la app
├── screens/
│ ├── login_screen.dart
│ ├── movie_list_screen.dart
│ ├── historial_screen.dart
│ └── purchase_screen.dart
├── services/
│ └── db_helper.dart # Controlador para la base de datos SQLite
assets/
├── avengers.jpg
├── batman.jpg
├── dune.jpg
├── spiderman.jpg
└── topgun.jpg
```

## 📬 Contacto

Si tienes dudas o quieres colaborar, abre un issue o contacta al autor del proyecto.