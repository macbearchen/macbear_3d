// ignore_for_file: file_names
import 'main.dart';

// ignore: camel_case_types
class PrimitivesScene_03 extends M3Scene {
  M3Entity? _pyramid;

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
    final plane = addMesh(M3Mesh(M3PlaneGeom(20, 20, uvScale: Vector2.all(5.0))), Vector3(0, 0, -1));
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    plane.mesh!.mtr.texDiffuse = texGround;

    // 03-2: sphere geometry
    final sphere = addMesh(M3Mesh(M3SphereGeom(0.5)), Vector3(2, 0, 0));
    sphere.mesh!.mtr.texDiffuse = texGrid2;

    final sphere2 = addMesh(M3Mesh(M3SphereGeom(1)), Vector3(0, 8, 1))..color = Vector4(1, 0, 0, 1);
    final sphere3 = addMesh(M3Mesh(M3SphereGeom(1.5)), Vector3(-6, 6, 1.5))..color = Vector4(0, 1, 0, 1);
    sphere2.mesh!.mtr.texDiffuse = texGrid2;
    sphere3.mesh!.mtr.texDiffuse = texGrid2;

    // 03-3: cylinder geometry
    final cylinder = addMesh(M3Mesh(M3CylinderGeom(0.2, 0.5, 1, heightSegments: 2)), Vector3(0, 2, 0));
    cylinder.mesh!.mtr.texDiffuse = texGrid;

    final cyliFlat = addMesh(M3Mesh(M3CylinderGeom(0.2, 0.5, 1, heightSegments: 2, creaseAngle: 1)), Vector3(-1, 2, 0));
    cyliFlat.mesh!.mtr.texDiffuse = texGrid;

    // 03-4: torus geometry
    final torus = addMesh(M3Mesh(M3TorusGeom(0.5, 0.2)), Vector3(-2, 0, 0));
    torus.mesh!.mtr.texDiffuse = texGrid2;

    // 03-5: pyramid geometry
    _pyramid = addMesh(M3Mesh(M3PyramidGeom(1, 1, 1)), Vector3(0, -2, 0));
    _pyramid!.mesh!.mtr.texDiffuse = texGrid2;

    // 03-6: ellipsoid geometry
    final ellipsoid = addMesh(M3Mesh(M3EllipsoidGeom(0.9, 0.6, 0.3)), Vector3(2, 2, 0));
    ellipsoid.mesh!.mtr.texDiffuse = texGrid2;

    // 03-7: capsule geometry
    final capsule = addMesh(M3Mesh(M3CapsuleGeom(0.3, 1)), Vector3(-2, 2, 0));
    capsule.mesh!.mtr.texDiffuse = texGrid2;
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;
    light.setEuler(sec * pi / 5, -pi / 3, 0, distance: light.distanceToTarget); // rotate light
    // debugPrint('Light Direction: $dirLight');

    if (_pyramid != null) {
      // final quatYPos90 = Quaternion.euler(0, pi / 2, 0);
      _pyramid!.rotation = Quaternion.euler(0, 0, sec * pi / 8);
    }
  }
}
