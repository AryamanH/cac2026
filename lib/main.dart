import 'package:flutter/material.dart';

import 'data/service_graph_repository.dart';
import 'screens/service_graph_home.dart';
import 'state/service_graph_controller.dart';

void main() => runApp(const ServiceGraphApp());

class ServiceGraphApp extends StatefulWidget {
  const ServiceGraphApp({super.key});

  @override
  State<ServiceGraphApp> createState() => _ServiceGraphAppState();
}

class _ServiceGraphAppState extends State<ServiceGraphApp> {
  late final ServiceGraphController _controller =
      ServiceGraphController(InMemoryServiceGraphRepository())..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _seed = Color(0xFF3D5A6C);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The First 90 Days',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: _seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: ServiceGraphHome(controller: _controller),
    );
  }
}
