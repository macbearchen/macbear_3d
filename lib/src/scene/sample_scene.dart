part of 'scene.dart';

class SampleScene extends M3Scene {
  final _geomCube = M3BoxGeom(1.0, 1.0, 1.0);
  final _geomSphere = M3SphereGeom(0.5);
  final _geomPlane = M3PlaneGeom(20.0, 20.0, widthSegments: 50, heightSegments: 50, uvScale: Vector2(10.0, 10.0));

  // constructor
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setLookat(Vector3(0, 6, 8), Vector3(0, 0, 2), Vector3(0, 0, 1));
    camera.setEuler(pi / 6, -pi / 5, 0, distance: 10);

    final camera2 = M3Camera();
    camera2.setLookat(Vector3(0, 4, 5), Vector3.zero(), Vector3(0, 0, 1));
    cameras.add(camera2);

    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    M3Texture texGrid2 = M3Texture.createCheckerboard(size: 6);
    M3Texture texGrid = M3Texture.createCheckerboard(size: 3);

    // create physics ground rigid body, 4 fences
    M3AppEngine.instance.physicsEngine.addGround(20, 20, 10);
    M3AppEngine.instance.physicsEngine.addFence(20, 20, 10);
    final world = M3AppEngine.instance.physicsEngine.world!;

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
    int countX = 3, countY = 3, countZ = 12;
    for (int i = 0; i < countX; i++) {
      for (int j = 0; j < countY; j++) {
        for (int k = 0; k < countZ; k++) {
          final delta = Random().nextDouble() * 0.5 - 0.25;
          final pos = Vector3(i * 2.0 + delta, j * 2.0 + delta, k * 2.0 + delta);
          pos.z += 1.0; // drop from sky

          final meshColor = colors[k % colors.length];
          // create visual entity
          M3Entity entity;
          M3Mesh mesh;
          M3Texture tex;

          // create rigid body
          oimo.Shape oimoShape;
          switch ((k + 1) % 2) {
            case 0:
              oimoShape = oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), 1.0, 1.0, 1.0);
              tex = texGrid;
              mesh = M3Mesh(_geomCube);
              break;
            default:
              oimoShape = oimo.Sphere(oimo.ShapeConfig(geometry: oimo.Shapes.sphere), 0.5);
              tex = texGrid2;
              mesh = M3Mesh(_geomSphere);
              break;
          }
          entity = addMesh(mesh, pos)..color = meshColor;
          entity.mesh!.mtr.texDiffuse = tex;

          final config = oimo.ObjectConfigure(
            shapes: [oimoShape],
            position: pos,
            move: true, // dynamic
          );
          final rb = world.add(config) as oimo.RigidBody;

          // link
          entity.rigidBody = rb;
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
  void update(Duration elapsed) {
    super.update(elapsed);

    double sec = elapsed.inMilliseconds / 1000.0;

    light.setEuler(sec * pi / 18, -pi / 3, 0, distance: light.distanceToTarget); // rotate light
    // debugPrint('Light Direction: $dirLight');
  }

  @override
  void render2D() {
    // draw rectangle full-screen
    final renderEngine = M3AppEngine.instance.renderEngine;
    Matrix4 mat2D = Matrix4.identity();

    final sampleString = "Macbear 3D: sample scene";
    mat2D.setTranslation(Vector3(3, 3, 0));
    renderEngine.text2D.drawText(sampleString, mat2D, color: Vector4(0, 0.1, 0, 1));
    mat2D.setTranslation(Vector3(0, 1, 0));
    renderEngine.text2D.drawText(sampleString, mat2D, color: Vector4(0, 0.9, 0, 1));
  }
}
