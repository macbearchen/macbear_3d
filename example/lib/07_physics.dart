// ignore_for_file: file_names
import 'main.dart';

// ignore: camel_case_types
class PhysicsScene_07 extends M3Scene {
  final _geomCube = M3BoxGeom(1.0, 1.0, 1.0);
  final _geomBall = M3SphereGeom(0.5);
  final _geomCylinder = M3CylinderGeom(0.5, 0.5, 1.0);

  // constructor
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 12);

    final camera2 = M3Camera();
    camera2.setLookat(Vector3(0, 4, 5), Vector3.zero(), Vector3(0, 0, 1));
    cameras.add(camera2);

    light.setEuler(0, -pi / 3, 0, distance: light.distanceToTarget); // rotate light

    // 07-1: physics static ground
    final phyEngine = M3AppEngine.instance.physicsEngine;
    phyEngine.addGround(10, 10, 2);

    List<Vector3> arrayPos = [Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(0, 3, 0), Vector3(.5, .6, 3)];
    List<Vector4> arrayColor = [Colors.yellow, Colors.red, Colors.green, Colors.blue];

    // 07-2: physics rigid box
    for (int i = 0; i < arrayPos.length; i++) {
      final pos = arrayPos[i].clone();
      pos.z += 1.5; // drop from sky

      // visual entity
      final entity = addMesh(M3Mesh(_geomCube), pos)..color = arrayColor[i];
      entity.rigidBody = phyEngine.addBox(1, 1, 1, position: pos);
    }

    // 07-3: physics rigid ball
    for (int i = 0; i < arrayPos.length; i++) {
      // drop from sky
      final pos = arrayPos[i].clone() + Vector3(0.3, 0.6, 3.0);

      final entity = addMesh(M3Mesh(_geomBall), pos)..color = arrayColor[i];
      entity.rigidBody = phyEngine.addSphere(0.5, position: pos);
    }

    // 07-4: physics rigid cylinder
    for (int i = 0; i < arrayPos.length; i++) {
      // drop from sky
      final pos = Vector3(i - 0.2, i + 0.3, i + 6.5);

      final entity = addMesh(M3Mesh(_geomCylinder), pos)..color = arrayColor[i];
      entity.physicsUpAxis = M3Axis.y;
      entity.rigidBody = phyEngine.addCylinder(0.5, 1.0, position: pos);
    }

    // sample cubemap
    skybox = M3Skybox(M3Texture.createSampleCubemap());

    // plane geometry
    final plane = addMesh(M3Mesh(M3PlaneGeom(10, 10, uvScale: Vector2.all(5.0))), Vector3(0, 0, 0));
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    plane.mesh!.mtr.texDiffuse = texGround;
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;
    light.setEuler(sec * pi / 18, -pi / 3, 0, distance: light.distanceToTarget); // rotate light
  }
}
