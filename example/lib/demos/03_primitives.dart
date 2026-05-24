// ignore_for_file: file_names
import '../main_all.dart';

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
    box.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid;

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
    plane.mesh!.subMeshes[0].mtr.diffuseTexture = texGround;

    // 03-2: sphere geometry
    final sphere = addMesh(M3Mesh(M3SphereGeom(0.5)), Vector3(2, 0, 0));
    sphere.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;

    // 03-3: cylinder geometry
    final cylinder = addMesh(M3Mesh(M3CylinderGeom(0.2, 0.5, 1, heightSegments: 2)), Vector3(0, 2, 0));
    cylinder.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid;
    final cylY = addMesh(M3Mesh(M3CylinderGeom(0.2, 0.5, 1, heightSegments: 2, axis: M3Axis.y)), Vector3(0, 2, 1.5));
    cylY.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid;
    final cylX = addMesh(M3Mesh(M3CylinderGeom(0.2, 0.5, 1, heightSegments: 2, axis: M3Axis.x)), Vector3(0, 2, 2.5));
    cylX.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid;

    final cyliFlat = addMesh(M3Mesh(M3CylinderGeom(0.2, 0.5, 1, heightSegments: 2, creaseAngle: 1)), Vector3(-1, 2, 0));
    cyliFlat.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid;

    // 03-4: torus geometry
    final torus = addMesh(M3Mesh(M3TorusGeom(0.5, 0.2)), Vector3(-2, 0, 0));
    torus.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;
    final torusY = addMesh(M3Mesh(M3TorusGeom(0.5, 0.2, axis: M3Axis.y)), Vector3(-2, 0, 2));
    torusY.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;
    final torusX = addMesh(M3Mesh(M3TorusGeom(0.5, 0.2, axis: M3Axis.x)), Vector3(-2, 0, 4));
    torusX.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;

    // 03-5: pyramid geometry
    _pyramid = addMesh(M3Mesh(M3PyramidGeom(1, 1, 1)), Vector3(0, -2, 0));
    _pyramid!.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;
    final pyramidY = addMesh(M3Mesh(M3PyramidGeom(0.6, 0.6, 1, axis: M3Axis.y)), Vector3(0, -2, 1));
    pyramidY.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;
    final pyramidX = addMesh(M3Mesh(M3PyramidGeom(0.6, 0.6, 1, axis: M3Axis.x)), Vector3(0, -2, 2));
    pyramidX.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;

    // 03-6: ellipsoid geometry
    final ellipsoid = addMesh(M3Mesh(M3EllipsoidGeom(0.9, 0.6, 0.3)), Vector3(2, 2, 0));
    ellipsoid.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;

    // 03-7: capsule geometry
    final capsule = addMesh(M3Mesh(M3CapsuleGeom(0.3, 1)), Vector3(-2, 2, 0));
    capsule.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;
    final capsuleY = addMesh(M3Mesh(M3CapsuleGeom(0.3, 1, axis: M3Axis.y)), Vector3(-2, 2, 1.5));
    capsuleY.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;
    final capsuleX = addMesh(M3Mesh(M3CapsuleGeom(0.3, 1, axis: M3Axis.x)), Vector3(-2, 2, 2.5));
    capsuleX.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;

    // 03-8: octahedral geometry
    final octahedral = addMesh(M3Mesh(M3OctahedralGeom(0.5)), Vector3(0, 0, 1.5));
    octahedral.mesh!.subMeshes[0].mtr.diffuseTexture = texGrid2;

    // 03-9: axis gizmo
    addMesh(M3Resources.axisGizmoMesh, Vector3.zero());

    // 03-10: Create a terrain-like plane with smooth shading
    final smoothPlane = M3Mesh(
      M3PlaneGeom(
        8,
        8,
        widthSegments: 8,
        heightSegments: 8,
        uvScale: Vector2.all(4.0),
        shading: M3ShadingMode.smooth,
        onVertex: (x, y) {
          return sin(x * 0.5) * cos(y * 0.5) * 2.0;
        },
      ),
    );
    smoothPlane.subMeshes[0].mtr.diffuseTexture = texGround;
    addMesh(smoothPlane, Vector3(-4.1, 9, 1.2));

    // 03-11: Create a terrain-like plane with flat shading
    final flatPlane = M3Mesh(
      M3PlaneGeom(
        8,
        8,
        widthSegments: 8,
        heightSegments: 8,
        uvScale: Vector2.all(4.0),
        shading: M3ShadingMode.flat,
        onVertex: (x, y) {
          return sin(x * 0.5) * cos(y * 0.5) * 2.0;
        },
      ),
    );
    flatPlane.subMeshes[0].mtr.diffuseTexture = texGround;
    addMesh(flatPlane, Vector3(4.1, 9, 1.2));
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
