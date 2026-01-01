// ignore_for_file: file_names
import 'dart:math';

import 'package:oimo_physics/oimo_physics.dart' as oimo;

import 'main.dart';

// ignore: camel_case_types
class PhysicsScene_07 extends M3Scene {
  final _geomCube = M3BoxGeom(1.0, 1.0, 1.0);
  final _geomBall = M3SphereGeom(0.5);

  // constructor
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 8);

    final camera2 = M3Camera();
    camera2.setLookat(Vector3(0, 4, 5), Vector3.zero(), Vector3(0, 0, 1));
    cameras.add(camera2);

    final world = M3AppEngine.instance.physicsEngine.world!;

    // 07-1: physics static ground
    final groundConfig = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), 10, 10, 2)],
      position: Vector3(0.0, 0.0, -2 / 2.0 - 1),
    );
    // ignore: unused_local_variable
    final rbGround = world.add(groundConfig) as oimo.RigidBody;

    // create body models
    List<Vector3> arrayPos = [Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(0, 3, 0), Vector3(0.2, 0.4, 3)];
    List<Vector4> arrayColor = [Colors.yellow, Colors.red, Colors.green, Colors.blue];

    // 07-2: physics rigid box
    for (int i = 0; i < arrayPos.length; i++) {
      final pos = arrayPos[i];
      pos.z += 3.0; // drop from sky

      // create visual entity
      final entity = addMesh(M3Mesh(_geomCube), pos)..color = arrayColor[i];

      // create rigid box
      final config = oimo.ObjectConfigure(
        shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), 1.0, 1.0, 1.0)],
        position: pos,
        move: true, // dynamic
      );
      final rb = world.add(config) as oimo.RigidBody;

      // link
      entity.rigidBody = rb;
    }

    // 07-3: physics rigid ball
    for (int i = 0; i < arrayPos.length; i++) {
      final pos = arrayPos[i];
      pos.z += 5.0; // drop from sky

      // create visual entity
      final entity = addMesh(M3Mesh(_geomBall), pos)..color = arrayColor[i];

      // create rigid sphere
      final config = oimo.ObjectConfigure(
        shapes: [oimo.Sphere(oimo.ShapeConfig(geometry: oimo.Shapes.sphere), 0.5)],
        position: pos,
        move: true, // dynamic
      );
      final rb = world.add(config) as oimo.RigidBody;

      // link
      entity.rigidBody = rb;
    }

    // sample cubemap
    skybox = M3Skybox(M3Texture.createSampleCubemap());

    // plane geometry
    final plane = addMesh(M3Mesh(M3PlaneGeom(10, 10, uvScale: Vector2.all(5.0))), Vector3(0, 0, -1));
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    plane.mesh!.mtr.texDiffuse = texGround;
  }

  @override
  void update(Duration elapsed) {
    super.update(elapsed);

    double sec = elapsed.inMilliseconds / 1000.0;

    light.setEuler(sec * pi / 18, -pi / 3, 0, distance: light.distanceToTarget); // rotate light
    // debugPrint('Light Direction: $dirLight');
  }
}
