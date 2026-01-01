// ignore_for_file: file_names
import 'dart:math';

import 'main.dart';

// ignore: camel_case_types
class SkyboxScene_02 extends M3Scene {
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 8);

    // 01: box geometry
    final box = addMesh(M3Mesh(M3BoxGeom(1.0, 1.0, 1.0)), Vector3.zero());
    M3Texture texGrid = M3Texture.createCheckerboard(size: 5);
    box.mesh!.mtr.texDiffuse = texGrid;

    // 02: sample cubemap
    skybox = M3Skybox(M3Texture.createSampleCubemap());
  }
}
