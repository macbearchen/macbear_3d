// ignore_for_file: unused_local_variable
import 'base_scene.dart';

// Define a physics scene for testing
class PhysicsScene extends BaseScene {
  final ballMesh = M3Mesh(M3Resources.unitSphere);
  final boxMesh = M3Mesh(M3Resources.unitCube);
  final capsuleMesh = M3Mesh(M3CapsuleGeom(radius: 0.5, height: 1.0, axis: M3Axis.z));
  final coneMesh = M3Mesh(M3CylinderGeom(topRadius: 0.0, bottomRadius: 0.8, height: 2.0, axis: M3Axis.y));

  PrismaticJoint? _liftJoint;

  // ── Spawner state ──────────────────────────────────────────────────────────
  static final Vector3 _spawnOrigin = Vector3(0, 0, 12);
  static const int _maxSpawnedBodies = 1000;
  static const double _spawnInterval = 0.1; // 10 bodies/sec
  int _spawnedCount = 0;
  double _spawnAccum = 0.0;
  final Random _rng = Random();

  // Vivid colour palette for spawned bodies
  static final List<Vector4> _palette = [
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.skyBlue,
    Colors.lightGreen,
    Colors.pink,
    Colors.purple,
    Colors.lightCoral,
    Colors.white,
    Colors.cyan,
  ];

  // constructor
  PhysicsScene({required super.physics});

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    M3AppEngine.backgroundColor = Vector3(0.1, 0.3, 0.15);

    camera.setEuler(pi / 8, -pi / 4, 0, distance: 30);
    dirLight.lightViewer.setEuler(pi / 5, -pi / 3, 0, distance: 30); // rotate light

    // addMesh(M3Mesh(M3PlaneGeom(10, 10)), Vector3(0, 0, -1)).color = Colors.skyBlue;

    // Cylindrical Joint (GenericJoint)
    // Locked: X, Y, AngX, AngY. Free: Z, AngZ.
    final box = addMesh(M3Mesh(M3BoxGeom(1, 1, 1)), Vector3(-4, 4, 7))..color = Colors.lightGreen;
    final rbBox = physicsSystem.addBox(0.5, 0.5, 0.5, desc: M3RigidBodyDesc.dynamic()..position = Vector3(-4, 4, 7));
    physicsSystem.attachEntity(box, rbBox);

    if (rbBox is M3RapierRigidBody) {
      final cylJoint = world.addGenericJoint(rbBox, world.groundBody, Vector3.zero(), Vector3(-4, 4, 7));
      // Configure constraints
      world.lockJointAxis(cylJoint, JointAxis.x, true);
      world.lockJointAxis(cylJoint, JointAxis.y, true);
      world.lockJointAxis(cylJoint, JointAxis.angX, true);
      world.lockJointAxis(cylJoint, JointAxis.angY, true);

      // Set static motor for rotation, dynamic for translation
      world.configureJointMotor(cylJoint, JointAxis.angZ, targetVel: 5.0, damping: 0.5);
    }

    // walls, falling, fan, lift, rope
    addWalls(6);
    // addGridFall();
    // addFalling();
    addFan(Vector3(0, -12, 4));
    addLift(Vector3(5, -12, 8));
    addRope(12, Vector3(12, 0, 8));
    // time-based spawner starts automatically via update()

    addHeightGeom();

    // axis gizmo
    addMesh(M3Resources.axisGizmoMesh, Vector3(0, 0, 0));
  }

  void swapYZ(Vector3 v) {
    double temp = v.y;
    v.y = v.z;
    v.z = temp;
  }

  void addGridFall() {
    final size = 8;
    for (int k = 0; k < 28; k++) {
      for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
          Vector3 ballPos = Vector3((i - size / 2) * 1.2, (j - size / 2) * 1.2, 6 + k * 3);
          // swapYZ(ballPos);
          final ball = addMesh(ballMesh.clone(), ballPos);
          final rbBall = physicsSystem.addSphere(0.5, desc: M3RigidBodyDesc.dynamic()..position = ballPos);
          physicsSystem.attachEntity(ball, rbBall);

          if (i == 0) {
            ball.color = Colors.red;
          } else if (j == 0) {
            ball.color = Colors.blue;
          }
          /*
          final boxPos = Vector3((i - size / 2) * 1.2, (j - size / 2) * 1.2, 7.5 + k * 3);
          final box = addMesh(boxMesh, boxPos)..color = Colors.blue;
          final rbBox = physicsSystem.addBox(0.5, 0.5, 0.5, M3RigidBodyDesc.dynamic()..position = boxPos);
          physicsSystem.attachEntity(box, rbBox);
          */
        }
      }
    }
  }

  void addFalling() {
    final cylGeom = M3CylinderGeom(topRadius: 0.5, bottomRadius: 0.5, height: 1.0, axis: M3Axis.y);
    // vertical falling
    final random = Random();
    for (int i = 0; i < 30; i++) {
      final ballPos = Vector3(random.nextDouble() * 3 - 4, random.nextDouble() * 3 - 4, 10 + i * 2.2);
      final boxPos = Vector3(random.nextDouble() * 4, random.nextDouble() * 4, 10 + i * 1.5);
      final cylPos = Vector3(random.nextDouble() * 3 - 4, random.nextDouble() * 3 + 1, 10 + i * 2);

      // ball
      final ball = addMesh(ballMesh.clone(), ballPos)..color = Colors.skyBlue;
      final rbBall = physicsSystem.addSphere(0.5, desc: M3RigidBodyDesc.dynamic()..position = ballPos);
      physicsSystem.attachEntity(ball, rbBall);

      // box
      final box = addMesh(M3Mesh(M3Resources.unitCube), boxPos)..color = Colors.yellow;
      final rbBox = physicsSystem.addBox(0.5, 0.5, 0.5, desc: M3RigidBodyDesc.dynamic()..position = boxPos);
      physicsSystem.attachEntity(box, rbBox);

      // cylinder
      final cylinder = addMesh(M3Mesh(cylGeom), cylPos)..color = Colors.lightGreen;
      final rbCyl = physicsSystem.addCylinder(
        radius: 0.5,
        halfHeight: 0.5,
        desc: M3RigidBodyDesc.dynamic()..position = cylPos,
      );
      physicsSystem.attachEntity(cylinder, rbCyl);
    }
  }

  void addFan(Vector3 pos) {
    // Motorized Fan (Revolute)
    final entityFan = addMesh(M3Mesh(M3BoxGeom(3, 0.6, 0.2)), pos)..color = Colors.orange;
    final rbFan = physicsSystem.addBox(1.5, 0.3, 0.1, desc: M3RigidBodyDesc.dynamic()..position = pos);
    physicsSystem.attachEntity(entityFan, rbFan);

    // Get world body and joint to it
    if (rbFan is M3RapierRigidBody) {
      final fanJoint = world.addRevoluteJointToWorld(rbFan, Vector3(0, 0, 1), Vector3.zero(), pos);
      world.configureRevoluteMotor(fanJoint, targetVel: 10.0, damping: 1.0);
      rbFan.wakeUp();
    }
  }

  void addLift(Vector3 pos) {
    // Motorized Lift (Prismatic) — slides along X: (-2,-2,6) <-> (4,-2,6)
    // Anchor is fixed at the start position; targetPos is the offset along X (0=start, 6=end).
    final entityLift = addMesh(M3Mesh(M3BoxGeom(2, 2, 0.2)), pos)..color = Colors.purple;
    final rbLift = physicsSystem.addBox(1, 1, 0.1, desc: M3RigidBodyDesc.dynamic()..position = pos);
    physicsSystem.attachEntity(entityLift, rbLift);

    if (rbLift is M3RapierRigidBody) {
      final liftJoint = world.addPrismaticJointToWorld(rbLift, Vector3(1, 0, 0), Vector3.zero(), pos);
      world.configurePrismaticMotor(liftJoint, targetPos: 0.0, stiffness: 100.0, damping: 20.0);
      _liftJoint = liftJoint;
      rbLift.wakeUp();
    }
  }

  double onWave(double x, double y) {
    double rad = pi / 3;
    if (y >= 5 && (x <= -5 || x >= 5)) {
      return 7;
    }
    return (cos(x * rad) + sin(y * rad));
  }

  void addHeightGeom() {
    // 04-2: plane geometry
    final geomPlane = M3PlaneGeom(
      12,
      12,
      widthSegments: 3,
      heightSegments: 3,
      uvScale: Vector2.all(5.0),
      shading: M3ShadingMode.flat,
      onVertex: onWave,
    );

    geomPlane.funcVertex = onWave;
    final hf = geomPlane.toHeightField();
    final hfData = hf.data;
    final plane = addMesh(M3Mesh(geomPlane), Vector3(0, 0, 2));

    Vector3 scale = Vector3(12, 1, 12);
    Vector3 pos = Vector3(0, 0, 2);

    final rbHeightfield = world.addHeightfield(
      heights: hfData,
      nrows: geomPlane.widthSegments + 1,
      ncols: geomPlane.heightSegments + 1,
      scale: scale,
      desc: RigidBodyDesc.fixed()..position = pos,
    );
    final q = Quaternion.euler(0, pi / 2, 0); //pi / 2, 0);
    rbHeightfield.setRotation(q);
  }

  // ── Spawner ────────────────────────────────────────────────────────────────
  /// Spawns one random rigid body thrown from [_spawnOrigin] with random velocity.
  void _spawnBody() {
    if (_spawnedCount >= _maxSpawnedBodies) return;

    // Random lateral velocity (XY) + slight inward push toward origin
    final vx = (_rng.nextDouble() - 0.5) * 12.0;
    final vy = (_rng.nextDouble() - 0.5) * 12.0;
    final vz = (_rng.nextDouble() * 5.0 + 6.0); // downward
    final vel = Vector3(vx, vy, vz);

    final desc = M3RigidBodyDesc.dynamic()
      ..position = Vector3(_spawnOrigin.x, _spawnOrigin.y, _spawnOrigin.z)
      ..linearVelocity = vel;

    final color = _palette[_rng.nextInt(_palette.length)];
    final shapeType = _rng.nextInt(3); // 0 = sphere, 1 = box, 2 = capsule

    switch (shapeType) {
      case 0: // sphere
        final entity = addMesh(ballMesh.clone(), desc.position)..color = color;
        final rb = physicsSystem.addSphere(0.45, desc: desc);
        physicsSystem.attachEntity(entity, rb);
        break;
      case 1: // box
        final entity = addMesh(M3Mesh(M3Resources.unitCube), desc.position)..color = color;
        final rb = physicsSystem.addBox(0.45, 0.45, 0.45, desc: desc);
        physicsSystem.attachEntity(entity, rb);
        break;
      case 2: // capsule
        final entity = addMesh(capsuleMesh.clone(), desc.position)..color = color;
        final rb = physicsSystem.addCapsule(radius: 0.35, halfHeight: 0.45, desc: desc);
        physicsSystem.attachEntity(entity, rb);
        break;
    }

    _spawnedCount++;
  }

  @override
  void update(double delta) {
    // Oscillate along X: targetPos 0 = (-2,-2,6), targetPos 6 = (4,-2,6)
    final t = DateTime.now().millisecondsSinceEpoch / 1200.0;
    final targetX = (sin(t) + 1.0) / 2.0 * 6.0; // smooth 0..6
    world.configurePrismaticMotor(_liftJoint!, targetPos: targetX, stiffness: 100.0, damping: 20.0);

    // Spawn bodies at 10/sec up to _maxSpawnedBodies
    if (_spawnedCount < _maxSpawnedBodies) {
      _spawnAccum += delta;
      while (_spawnAccum >= _spawnInterval && _spawnedCount < _maxSpawnedBodies) {
        _spawnBody();
        _spawnAccum -= _spawnInterval;
      }
    }

    super.update(delta);
  }
}
