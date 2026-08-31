import 'base_scene.dart';

class DoublePendulumScene extends BaseScene {
  // constrtuctor
  DoublePendulumScene({required super.physics});

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    addDoublePendulum(Vector3(0, 0, 8), 3, pi / 2, pi / 1.5);
    addDoublePendulum(Vector3(0, -2, 8), 3, pi / 2, pi / 1.6);
    addDoublePendulum(Vector3(0, -4, 8), 3, pi / 2, pi / 1.7);
    addDoublePendulum(Vector3(0, -6, 8), 3, pi / 2, pi / 1.8);
    addDoublePendulum(Vector3(0, -8, 8), 3, pi / 2, pi / 1.9);
  }

  void addDoublePendulum(Vector3 position, double length, double angle1, double angle2) {
    const double radius = 0.5;
    const double sphereDensity = 10.0; // Very heavy sphere

    final pendulumMesh = createPendulum(radius, length);

    // --- Sphere 1 ---
    final posSphere1 = position + Vector3(0, 0, -length);
    final entityS1 = addMesh(pendulumMesh.clone(), posSphere1)..color = Colors.red;
    final rbS1 = physicsSystem.addSphere(radius, desc: M3RigidBodyDesc.dynamic()..position = posSphere1);
    physicsSystem.attachEntity(entityS1, rbS1);

    // --- Sphere 2 ---
    final posSphere2 = posSphere1 + Vector3(0, 0, -length);
    final entityS2 = addMesh(pendulumMesh.clone(), posSphere2)..color = Colors.yellow;
    final rbS2 = physicsSystem.addSphere(radius, desc: M3RigidBodyDesc.dynamic()..position = posSphere2);
    physicsSystem.attachEntity(entityS2, rbS2);

    if (rbS1 is M3RapierRigidBody && rbS2 is M3RapierRigidBody) {
      rbS1.colliders.first.density = sphereDensity;

      // Joint 1: Pin Sphere 1 to World at 'position'
      world.addRevoluteJointToWorld(
        rbS1,
        Vector3(0, 1, 0), // Axis Y
        Vector3(0, 0, length), // Local anchor relative to S1 center
        position, // World anchor
      );

      rbS2.colliders.first.density = sphereDensity;
      // Joint 2: Connect Sphere 2 to Sphere 1
      world.addRevoluteJoint(
        rbS1,
        rbS2,
        Vector3(0, 1, 0), // Axis Y
        Vector3(0, 0, 0), // Local anchor 1: Center of S1
        Vector3(0, 0, length), // Local anchor 2: Up from S2 center
      );
    }
    // Initial state: Tilt by 60 degrees

    final q = Quaternion.euler(-angle1, 0, 0);
    final q2 = Quaternion.euler(-angle2, 0, 0);

    final pivot = position;
    final sphere1Center = pivot + Vector3(sin(angle1) * length, 0, -cos(angle1) * length);
    final sphere2Center = sphere1Center + Vector3(sin(angle2) * length, 0, -cos(angle2) * length);

    rbS1.setPosition(sphere1Center);
    rbS1.setRotation(q);

    rbS2.setPosition(sphere2Center);
    rbS2.setRotation(q2);
  }
}
