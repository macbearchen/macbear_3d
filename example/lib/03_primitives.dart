// ignore_for_file: file_names
import 'dart:math';

import 'main.dart';

// ignore: camel_case_types
class PrimitivesScene_03 extends M3Scene {
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 8);

    // 01: add box geometry
    final box = addMesh(M3Mesh(M3BoxGeom(1.0, 1.0, 1.0)), Vector3.zero());
    M3Texture texGrid = M3Texture.createCheckerboard(size: 5);
    box.mesh!.mtr.texDiffuse = texGrid;

    M3Texture texGrid2 = M3Texture.createCheckerboard(size: 6);

    // 02: sample cubemap
    final strPrefix = 'example/nvlobby_';
    final strExt = 'jpg';
    skybox = await M3Skybox.createCubemap(
      '${strPrefix}xpos.$strExt',
      '${strPrefix}xneg.$strExt',
      '${strPrefix}ypos.$strExt',
      '${strPrefix}yneg.$strExt',
      '${strPrefix}zpos.$strExt',
      '${strPrefix}zneg.$strExt',
    );

    // 03-1: plane geometry
    final plane = addMesh(M3Mesh(M3PlaneGeom(10, 10, uvScale: Vector2.all(5.0))), Vector3(0, 0, -1));
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    plane.mesh!.mtr.texDiffuse = texGround;

    // 03-2: sphere geometry
    final sphere = addMesh(M3Mesh(M3SphereGeom(0.5)), Vector3(2, 0, 0));
    sphere.mesh!.mtr.texDiffuse = texGrid2;

    // 03-3: cylinder geometry
    final cylinder = addMesh(M3Mesh(M3CylinderGeom(0.2, 0.5, 1)), Vector3(0, 2, 0));
    cylinder.mesh!.mtr.texDiffuse = texGrid;

    // 03-4: torus geometry
    final torus = addMesh(M3Mesh(M3TorusGeom(0.5, 0.2)), Vector3(-2, 0, 0));
    torus.mesh!.mtr.texDiffuse = texGrid2;

    // 03-5: pyramid geometry
    final pyramid = addMesh(M3Mesh(M3PyramidGeom(1, 1, 1)), Vector3(0, -2, 0));
    pyramid.mesh!.mtr.texDiffuse = texGrid2;

    // 03-6: ellipsoid geometry
    final ellipsoidA = addMesh(M3Mesh(M3EllipsoidGeom(0.5, 1, 1.5, 32, 16)), Vector3(2, 2, 2));
    ellipsoidA.mesh!.mtr.texDiffuse = texGrid2;
  }
}
