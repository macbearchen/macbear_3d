part of 'scene.dart';

/// A demonstration scene with cubes, spheres, physics, and a skybox.
class SampleScene extends M3Scene {
  final _geomCube = M3Resources.unitCube;
  final _geomSphere = M3Resources.unitSphere;
  final _geomCylinder = M3CylinderGeom(0.5, 0.5, 1.0);
  final _geomPlane = M3PlaneGeom(20.0, 20.0, widthSegments: 50, heightSegments: 50, uvScale: Vector2(10.0, 10.0));

  // constructor
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    light.setLookat(Vector3(0, 0, 20), Vector3(0, 0, 1), Vector3(0, 1, 0));

    camera.setLookat(Vector3(0, 6, 8), Vector3(0, 0, 2), Vector3(0, 0, 1));
    camera.setEuler(pi / 6, -pi / 5, 0, distance: 10);

    final camera2 = M3Camera();
    int halfView = 3;
    camera2.setViewport(-halfView, -halfView, halfView * 2, halfView * 2, fovy: 40, far: 20);
    camera2.setLookat(Vector3(0, 8, 1), Vector3.zero(), Vector3(0, 0, 1));
    cameras.add(camera2);

    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    M3Texture texGrid2 = M3Texture.createCheckerboard(size: 6);
    M3Texture texGrid = M3Texture.createCheckerboard(size: 3);

    // create physics ground rigid body, 4 fences
    final phyEngine = M3AppEngine.instance.physicsEngine;
    phyEngine.addGround(20, 20, 10);
    phyEngine.addBoundaryFence(20, 20, 10);

    // ground plane model
    final meshPlane = addMesh(M3Mesh(_geomPlane), Vector3(0, 0, 0))..color = Vector4(1.0, 1.0, 1.0, 1);
    // (optional) link meshPlane to rbGround if you want it to move, but it's static.

    List<Vector4> colors = [
      // Colors.lightGray,
      Colors.pink,
      Colors.orange,
      Colors.yellow,
      Colors.lightGreen,
      Colors.cyan,
      Colors.lightBlue,
      Colors.violet,
    ];

    // cube model (dynamic)
    int countX = 4, countY = 4, countZ = 8;
    for (int i = 0; i < countX; i++) {
      for (int j = 0; j < countY; j++) {
        for (int k = 0; k < countZ; k++) {
          final delta = Random().nextDouble() * 0.5 - 0.25 - 2;
          final pos = Vector3(i * 2.0 + delta, j * 2.0 + delta, k * 3.0 + delta);
          pos.z += 3.0; // drop from sky

          final meshColor = colors[k % colors.length];
          M3Mesh mesh;
          oimo.RigidBody rb;
          M3Axis phyUpAxis = M3Axis.z;

          // visual entity, rigid body
          switch (k % 3) {
            case 0:
              mesh = M3Mesh(_geomSphere);
              mesh.mtr.texDiffuse = texGrid2;
              rb = phyEngine.addSphere(0.5, density: 1.0, position: pos);
              break;
            case 1:
              mesh = M3Mesh(_geomCube);
              mesh.mtr.texDiffuse = texGrid;
              rb = phyEngine.addBox(1.0, 1.0, 1.0, density: 1.0, position: pos);
              break;
            default:
              mesh = M3Mesh(_geomCylinder);
              mesh.mtr.texDiffuse = texGrid2;
              rb = phyEngine.addCylinder(0.5, 1.0, density: 1.0, position: pos);
              phyUpAxis = M3Axis.y;
              break;
          }
          M3Entity entity = addMesh(mesh, pos)..color = meshColor;
          entity.rigidBody = rb;
          entity.physicsUpAxis = phyUpAxis;
        }
      }
    }

    // sample cubemap
    skybox = M3Skybox(M3Texture.createSampleCubemap(gridCount: 11));

    meshPlane.mesh!.mtr.texDiffuse = texGround;
    meshPlane.mesh!.mtr.specular = Vector3.zero();
    meshPlane.mesh!.mtr.shininess = 1;
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;

    light.setEuler(sec * pi / 18, -pi / 1.8, 0, distance: light.distanceToTarget); // rotate light
    // debugPrint('Light Direction: $dirLight');
  }

  @override
  void render2D() {
    // draw rectangle full-screen
    Matrix4 mat2D = Matrix4.identity();

    final sampleString = "Macbear 3D: sample scene";
    mat2D.setTranslation(Vector3(3, 3, 0));
    M3Resources.text2D.drawText(sampleString, mat2D, color: Vector4(0, 0.1, 0, 1));
    mat2D.setTranslation(Vector3(0, 1, 0));
    M3Resources.text2D.drawText(sampleString, mat2D, color: Vector4(0, 0.9, 0, 1));
  }
}
