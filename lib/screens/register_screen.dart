// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import '../services/db_helper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  String _rol = 'usuario';

  void _registrar() async {
    if (_formKey.currentState!.validate()) {
      final res = await DBHelper.registrarUsuario(
        _nombre.text,
        _correo.text,
        _contrasena.text,
        _rol,
      );
      if (res == -1) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('El correo ya está registrado')));
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario registrado correctamente')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombre,
                decoration: InputDecoration(labelText: 'Nombre completo'),
                validator: (v) => v!.isEmpty ? 'Ingrese su nombre' : null,
              ),
              TextFormField(
                controller: _correo,
                decoration: InputDecoration(labelText: 'Correo'),
                validator: (v) => v!.isEmpty ? 'Ingrese su correo' : null,
              ),
              TextFormField(
                controller: _contrasena,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Contraseña'),
                validator: (v) => v!.length < 4 ? 'Mínimo 4 caracteres' : null,
              ),
              DropdownButtonFormField(
                value: _rol,
                decoration: InputDecoration(labelText: 'Rol'),
                items:
                    ['usuario', 'admin']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                onChanged: (val) => setState(() => _rol = val as String),
              ),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _registrar, child: Text('Registrar')),
            ],
          ),
        ),
      ),
    );
  }
}
