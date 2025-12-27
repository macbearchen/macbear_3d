import 'package:flutter/material.dart';

import '../macbear_3d.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Macbear3D')),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
            FloatingActionButton(onPressed: () {}, child: const Icon(Icons.remove)),
            FloatingActionButton(onPressed: () {}, child: const Icon(Icons.light)),
            FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
          ],
        ),
        body: M3View(),
      ),
    );
  }
}
