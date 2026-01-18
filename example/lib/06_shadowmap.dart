// ignore_for_file: file_names
import 'main.dart';

// ignore: camel_case_types
class ShadowmapScene_06 extends M3Scene {
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 3, -pi / 5, 0, distance: 25);

    // 01: add box geometry
    M3Texture texGrid = M3Texture.createCheckerboard(size: 5);
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

    // 06-1: plane geometry
    final geomPlane = M3PlaneGeom(
      100,
      100,
      widthSegments: 100,
      heightSegments: 100,
      uvScale: Vector2.all(10.0),
      onVertex: (x, y) {
        double rad = pi / 10;
        return (cos(x * rad) + sin(y * rad));
      },
    );

    final plane = addMesh(M3Mesh(geomPlane), Vector3(0, 0, -2));
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 10,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    plane.mesh!.mtr.texDiffuse = texGround;

    final geomBox = M3BoxGeom(2.0, 1.5, 3.0);
    final geomSphere = M3SphereGeom(2);
    final geomCylinder = M3CylinderGeom(1.2, 1.2, 8, heightSegments: 2);
    final geomTorus = M3TorusGeom(2, 0.3);

    for (int i = 0; i <= 10; i++) {
      final double posX = i * 10 - 50;
      final rot = i * pi / 20;
      // 06-2: sphere geometry
      final sphere = addMesh(M3Mesh(geomSphere), Vector3(posX, 0, 2));
      sphere.mesh!.mtr.texDiffuse = texGrid2;

      // 06-3: cylinder geometry
      final cylinder = addMesh(M3Mesh(geomCylinder), Vector3(posX, 5, 3));
      cylinder.mesh!.mtr.texDiffuse = texGrid;
      cylinder.rotation.setEuler(rot, 0, 0);

      // 06-3: box geometry
      final box = addMesh(M3Mesh(geomBox), Vector3(posX, 10, 2));
      box.mesh!.mtr.texDiffuse = texGrid;
      box.rotation.setEuler(0, 0, rot);

      // 06-4: torus geometry
      final torus = addMesh(M3Mesh(geomTorus), Vector3(posX, 15, 2));
      torus.mesh!.mtr.texDiffuse = texGrid2;
      torus.rotation.setEuler(0, rot, 0);
    }
  }

  @override
  void update(Duration elapsed) {
    super.update(elapsed);

    double sec = elapsed.inMilliseconds / 1000.0;
    light.setEuler(sec * pi / 20, -pi / 4, 0, distance: 30); // rotate light
    // debugPrint('Light Direction: $dirLight');
  }
}
