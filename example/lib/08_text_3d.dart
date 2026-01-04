// ignore_for_file: file_names
import 'dart:math';

import 'main.dart';

// ignore: camel_case_types
class Text3DScene_08 extends M3Scene {
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 8);

    // Lighting (ambient not supported directly on scene, handled by light setup or shaders)
    // light.color = Vector4(1, 1, 1, 1);
    // light.setEuler(0, 0, 0, distance: 20); // standard light

    // Create Material
    final material = M3Material();
    material.diffuse = Vector4(1.0, 0.5, 0.0, 1.0); // Orange
    material.shininess = 32;

    try {
      // Create Text Geometry
      final textGeom = M3TextGeom();

      // NOTE: This requires 'assets/example/test.ttf' or similar to be present.
      // We'll try to load a font. Please update path if needed.
      await textGeom.loadTtf('assets/example/test.ttf');
      // await textGeom.build("HELLO 3D!", size: 0.5, depth: 0.2);
      await textGeom.build("ABCD 1234", size: 1, depth: 1.0);

      // Create Mesh
      final mesh = M3Mesh(textGeom, material: material);
      final entity = addMesh(mesh, Vector3(-2.0, 0, 0)); // Center roughly

      // Add a rotating cube for reference
      final cubeGeom = M3BoxGeom(1, 1, 1);
      final cubeMat = M3Material();
      cubeMat.diffuse = Vector4(0.0, 0.5, 1.0, 1.0);
      final cube = M3Mesh(cubeGeom, material: cubeMat);
      addMesh(cube, Vector3(2, 0, 0));
    } catch (e) {
      debugPrint("Error loading font or building text: $e");
      // Fallback
    }
  }

  @override
  void update(Duration elapsed) {
    super.update(elapsed);
    // camera.lookAt(Vector3.zero());
  }
}
