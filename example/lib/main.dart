import 'dart:math';
import 'package:flutter/material.dart' hide Colors, Matrix4;
import 'package:vector_math/vector_math.dart';

// Macbear3D engine
import 'package:macbear_3d/macbear_3d.dart';

void main() {
  M3AppEngine.instance.onDidInit = onDidInit;

  runApp(const MyApp());
}

Future<void> onDidInit() async {
  M3Log.h('example/main.dart', 'onDidInit');
  final appEngine = M3AppEngine.instance;
  appEngine.renderEngine.createShadowMap(width: 1024, height: 1024);
  M3AppEngine.backgroundColor = Vector3(0.1, 0.6, 0.3);

  await appEngine.setScene(MyScene());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Macbear 3D Example')),
        body: const M3View(),
      ),
    );
  }
}

// Define a simple scene
class MyScene extends M3Scene {
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 8);
    camera.csmCount = 0;

    M3Mesh meshGrid = M3Mesh(M3PlaneGeom(10, 10));

    // add geometry
    addMesh(M3Mesh(M3BoxGeom(1.0, 1.0, 1.0)), Vector3(0, 0, 2.5)).color = Colors.blue;
    addMesh(M3Mesh(M3SphereGeom(0.5)), Vector3(0, 0, 0)).color = Colors.red;
    addMesh(M3Mesh(M3TorusGeom(1, 0.2)), Vector3(0, 0, 0)).color = Colors.green;
    final plane = addMesh(meshGrid, Vector3(0, 0, -1)).color = Colors.skyBlue;

    // String strTex = 'astc/test_12x12.astc';
    String strTex = 'astc/test_4x4.astc';
    // String strTex = 'data_test/land.pvr';

    M3Texture texGrid = await M3Texture.loadTexture(strTex);
    // M3Texture texGrid = M3Texture.createCheckerboard(size: 10);
    meshGrid.subMeshes.first.mtr.diffuseTexture = texGrid;
  }

  @override
  void render2D() {
    super.render2D();

    final texDebug = M3Resources.text2D.mtr.diffuseTexture;
    texDebug.debugDraw(0, 0, 0.6, 0.6);
  }
}
