// ignore_for_file: file_names
import 'dart:math';

import 'main.dart';

// ignore: camel_case_types
class ObjTeapotScene_04 extends M3Scene {
  M3Entity? _teapot;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 8);

    // plane geometry
    final geomPlane = M3PlaneGeom(
      10,
      10,
      widthSegments: 60,
      heightSegments: 60,
      uvScale: Vector2.all(5.0),
      onVertex: (x, y) {
        double rad = pi / 2;
        return (cos(x * rad) + sin(y * rad)) / 2;
      },
    );
    final plane = addMesh(M3Mesh(geomPlane), Vector3(0, 0, -1));

    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    plane.mesh!.mtr.texDiffuse = texGround;

    // 04: obj model - using M3Mesh.load()
    final meshTeapot = await M3Mesh.load('example/teapot.obj');
    _teapot = addMesh(meshTeapot, Vector3(0, 0, 0));
    _teapot!.color = Vector4(1.0, 0.5, 0.0, 1);

    // set background color
    M3AppEngine.backgroundColor = Vector3(0, 0, 0.36);
  }

  @override
  void update(Duration elapsed) {
    super.update(elapsed);

    double sec = elapsed.inMilliseconds / 1000.0;
    light.setEuler(sec * pi / 18, -pi / 3, 0, distance: light.distanceToTarget); // rotate light
    // debugPrint('Light Direction: $dirLight');

    double angle = sec * pi / 4; // 45 degree per second

    if (_teapot != null) {
      final quatYPos90 = Quaternion.euler(0, pi / 2, 0);
      _teapot!.rotation = quatYPos90 * Quaternion.euler(angle, 0, 0);
    }
  }
}
