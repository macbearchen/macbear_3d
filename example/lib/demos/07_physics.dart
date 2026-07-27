// ignore_for_file: file_names
import '../main_all.dart';

// ignore: camel_case_types
class PhysicsScene_07 extends DemoScene {
  final _geomCylinder = M3CylinderGeom(topRadius: 0.5, bottomRadius: 0.5, height: 1.0, axis: M3Axis.y);

  // constructor
  PhysicsScene_07() : super(physics: M3PhysicsSystem(M3RapierPhysicsEngine()));

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 12);

    M3Texture texGrid = M3Texture.createCheckerboard(size: 6);
    final cubeMesh = M3Mesh(M3Resources.unitCube);
    cubeMesh.subMeshes[0].mtr.diffuseTexture = texGrid;

    final ballMesh = M3Mesh(M3Resources.unitSphere);
    ballMesh.subMeshes[0].mtr.diffuseTexture = texGrid;

    final cylinderMesh = M3Mesh(_geomCylinder);
    cylinderMesh.subMeshes[0].mtr.diffuseTexture = texGrid;

    // 07-1: physics static ground
    physicsSystem.addBox(5, 5, 2, desc: M3RigidBodyDesc.fixed()..position = Vector3(0, 0, -2));

    List<Vector3> arrayPos = [Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(0, 3, 0), Vector3(.5, .6, 3)];
    List<Vector4> arrayColor = [Colors.yellow, Colors.red, Colors.green, Colors.blue];

    // 07-2: physics rigid box
    for (int i = 0; i < arrayPos.length; i++) {
      final pos = arrayPos[i].clone();
      pos.z += 1.5; // drop from sky

      // visual entity
      final entity = addMesh(cubeMesh, pos)..color = arrayColor[i];
      final rb = physicsSystem.addBox(0.5, 0.5, 0.5, desc: M3RigidBodyDesc.dynamic()..position = pos);
      physicsSystem.attachEntity(entity, rb);
    }

    // 07-3: physics rigid ball
    for (int i = 0; i < arrayPos.length; i++) {
      // drop from sky
      final pos = arrayPos[i].clone() + Vector3(0.3, 0.6, 3.0);

      final entity = addMesh(ballMesh, pos)..color = arrayColor[i];
      final rb = physicsSystem.addSphere(0.5, desc: M3RigidBodyDesc.dynamic()..position = pos);
      physicsSystem.attachEntity(entity, rb);
    }

    // 07-4: physics rigid cylinder
    for (int i = 0; i < arrayPos.length; i++) {
      // drop from sky
      final pos = Vector3(i - 0.2, i + 0.3, i + 6.5);

      final entity = addMesh(cylinderMesh, pos)..color = arrayColor[i];
      final rb = physicsSystem.addCylinder(
        radius: 0.5,
        halfHeight: 0.5,
        desc: M3RigidBodyDesc.dynamic()..position = pos,
      );
      physicsSystem.attachEntity(entity, rb);
    }

    // sample cubemap
    // skybox = M3Skybox(M3Texture.createSampleCubemap());
    skybox = M3Skybox(M3Texture.createDefaultIBLCube());

    // plane geometry
    final plane = addMesh(
      M3Mesh(M3PlaneGeom(10, 10, widthSegments: 16, heightSegments: 16, uvScale: Vector2.all(5.0))),
      Vector3(0, 0, 0),
    );
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    plane.mesh.subMeshes[0].mtr.diffuseTexture = texGround;
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;
  }
}
