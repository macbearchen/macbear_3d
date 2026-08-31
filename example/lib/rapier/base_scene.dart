// ignore_for_file: unused_local_variable
import 'dart:math';
export 'dart:math';
import 'package:vector_math/vector_math.dart';
export 'package:vector_math/vector_math.dart';

// Macbear3D engine
import 'package:macbear_3d/macbear_3d.dart';
export 'package:macbear_3d/macbear_3d.dart';

// Rapier physics
import 'package:rapier_physics/rapier_physics.dart';
export 'package:rapier_physics/rapier_physics.dart';

import 'rapier_physics_engine.dart';
export 'rapier_physics_engine.dart';

// Define a base scene
class BaseScene extends M3Scene {
  late final RapierWorld world;
  late final M3RigidBody rbGround;

  // 通用的靜態工廠方法
  static T createPhysicsScene<T extends BaseScene>(T Function(M3PhysicsSystem) sceneFactory) {
    final rapierEngine = M3RapierPhysicsEngine();
    final physicsSystem = M3PhysicsSystem(rapierEngine);

    // 使用傳入的工廠函數建立具體子類別
    final ret = sceneFactory(physicsSystem);

    // 設定共用的 rapierWorld
    ret.world = rapierEngine.world;
    return ret;
  }

  // constrtuctor
  BaseScene({required super.physics});

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    M3AppEngine.backgroundColor = Vector3(0.04, 0.04, 0.8);

    camera.setEuler(pi / 9, -pi / 5, 0, distance: 20);
    dirLight.lightViewer.setEuler(pi / 5, -pi / 3, 0, distance: 30);

    rbGround = addGround();

    // sample cubemap
    skybox = M3Skybox(M3Texture.createDefaultIBLCube());
  }

  M3Mesh createPendulum(double radius, double length) {
    final pendulumMesh = M3Mesh(M3Resources.unitSphere);
    pendulumMesh.subMeshes[0].localMatrix.scaleByVector3(Vector3.all(radius / 0.5));

    final rodPart = M3SubMesh(M3Resources.unitCube);
    rodPart.localMatrix = Matrix4.compose(Vector3(0, 0, length / 2), Quaternion.identity(), Vector3(0.1, 0.1, length));
    pendulumMesh.subMeshes.add(rodPart);

    return pendulumMesh;
  }

  // ── Ground ──────────────────────────────────────────────────────────────────
  M3RigidBody addGround() {
    M3Texture texGrid = M3Texture.createCheckerboard(size: 10);
    M3Material mtr = M3Material();
    mtr.diffuseTexture = texGrid;

    const hs = 10.0;
    // Fixed physics floor — top surface sits at z = 0
    final rb = physicsSystem.addBox(hs, hs, 0.5, desc: M3RigidBodyDesc.fixed()..position = Vector3(0, 0, -0.5));
    final floor = addMesh(M3Mesh(M3PlaneGeom(hs * 2, hs * 2), material: mtr), Vector3(0, 0, 0));
    floor.mesh.subMeshes[0].localMatrix.setTranslation(Vector3(0, 0, 0.5));
    floor.color = Colors.limeGreen;
    physicsSystem.attachEntity(floor, rb);
    return rb;
  }

  void addRope(int numSegments, Vector3 startPos) {
    final List<RigidBody> rbRopes = [];
    final ropeMesh = M3Mesh(M3BoxGeom(1, 0.4, 0.4));
    // Rope Joint
    final hookPos = Vector3(-0.5, 0, 0);
    for (int i = 0; i < numSegments; i++) {
      final ropePos = Vector3(i.toDouble(), 0, 0) + startPos;
      // Use thin segments along X axis
      final rope = addMesh(ropeMesh, ropePos)..color = Colors.lightCoral;
      final rbRope = physicsSystem.addBox(0.5, 0.1, 0.1, desc: M3RigidBodyDesc.dynamic()..position = ropePos);
      physicsSystem.attachEntity(rope, rbRope);

      if (rbRope is M3RapierRigidBody) {
        rbRopes.add(rbRope);
        RopeJoint ropeJoint;
        if (i == 0) {
          // Anchor start of first segment to the wall
          ropeJoint = world.addRopeJoint(rbRopes[i], world.groundBody, hookPos, ropePos + hookPos, 0.05);
        } else {
          // Connect start of current segment to end of previous segment
          ropeJoint = world.addRopeJoint(rbRopes[i], rbRopes[i - 1], hookPos, -hookPos, 0.05);
        }
        world.setJointLimits(ropeJoint, JointAxis.angX, -0.3, 0.3);
      }
    }
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;
    dirLight.lightViewer.setEuler(sec * pi / 18, -pi / 3, 0); // rotate light
  }
}
