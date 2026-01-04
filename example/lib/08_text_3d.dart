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
      await textGeom.build("ABCD 1234", size: 1);

      // Create Mesh
      final mesh = M3Mesh(textGeom, material: material);
      final entity = addMesh(mesh, Vector3(-2.0, 0, 0)); // Center roughly

      // 03-2: sphere geometry
      final sphere = addMesh(M3Mesh(M3SphereGeom(0.5)), Vector3(2, 0, 2));
      // sphere.mesh!.mtr.texDiffuse = texGrid2;

      // 03-1: plane geometry
      final plane = addMesh(M3Mesh(M3PlaneGeom(10, 10, uvScale: Vector2.all(5.0))), Vector3(0, 0, -1));
      M3Texture texGround = M3Texture.createCheckerboard(
        size: 2,
        lightColor: Vector4(.7, 1, .5, 1),
        darkColor: Vector4(.5, 0.8, .3, 1),
      );
      plane.mesh!.mtr.texDiffuse = texGround;
    } catch (e) {
      debugPrint("Error loading font or building text: $e");
      // Fallback
    }
  }

  @override
  void update(Duration elapsed) {
    super.update(elapsed);

    double sec = elapsed.inMilliseconds / 1000.0;
    light.setEuler(sec * pi / 18, -pi / 3, 0, distance: light.distanceToTarget); // rotate light
  }
}
