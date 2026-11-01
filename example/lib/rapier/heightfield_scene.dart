import 'dart:math' as math;

import 'package:flutter/services.dart' hide Matrix4;
import 'package:material_ui/material_ui.dart' as fm;

import 'base_scene.dart';

// ── Car scene ───────────────────────────────────────────────────────────────

class HeightfieldScene extends BaseScene {
  // Car state
  late _CarVehicle _car;
  late _CarInputController _inputCtrl;

  // UI control state for car
  double uiSteering = 0.0; // -1..1
  double uiThrottle = 0.0; // -1..1
  bool uiBrake = false;

  HeightfieldScene({required super.physics});

  @override
  Future<void> load() async {
    await super.load();

    // Keyboard / touch input for car
    _inputCtrl = _CarInputController(this);
    inputController = _inputCtrl;

    addMesh(M3Resources.axisGizmoMesh, Vector3(0, 0, 10));

    // Create a heightmap
    addHeightField(80, 80, onVertex: onWave, pos: Vector3(50, 0, 0));
    addHeightField(80, 80, onVertex: onRipple, pos: Vector3(-50, 0, 0));
    final rbLoop = addHeightField(20, 40, onVertex: onCircle, pos: Vector3(0, 10, 20));
    final quatRot = Quaternion.euler(0, pi, 0);
    rbLoop.setRotation(quatRot);

    // Spawn the car above the terrain centre
    _car = _CarVehicle.spawn(this, spawnPos: Vector3(0, 0, 3));

    // final posBox = Vector3(0, 0, 5);
    // final box = addMesh(M3Mesh(M3BoxGeom(2, 1, 2)), posBox)..color = Colors.lightGreen;
    // final rbBox = physicsSystem.addBox(1, 0.5, 1, desc: M3RigidBodyDesc.dynamic()..position = posBox);
    // physicsSystem.attachEntity(box, rbBox);
  }

  // ── Heightfield helpers ──────────────────────────────────────────────────

  double onCircle(double x, double y) {
    const double radius = 20.0;
    final r2 = radius * radius - y * y;
    if (r2 <= 0) return 0;
    return -math.sqrt(r2);
  }

  double onWave(double x, double y) {
    double rad = pi / 9;
    double limit = 20;
    if (y >= limit && (x <= -limit || x >= limit)) {
      return 2;
    }
    return (cos(x * rad) + sin(y * rad)) * 0.8;
  }

  double onRipple(double x, double y) {
    Vector2 center = Vector2(0, 0);
    const double wavelength = 18;
    const double amplitude = 1;
    final dx = x - center.x;
    final dy = y - center.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    return amplitude * math.cos(dist / wavelength * math.pi * 2);
  }

  M3RigidBody addHeightField(double width, double height, {Function(double x, double y)? onVertex, Vector3? pos}) {
    final sizeX = width;
    final sizeZ = height;

    final geomPlane = M3PlaneGeom(
      sizeX,
      sizeZ,
      widthSegments: 60,
      heightSegments: 60,
      axis: M3Axis.y,
      uvScale: Vector2.all(5.0),
      onVertex: onVertex,
    );
    M3Texture texGrid = M3Texture.createCheckerboard(size: 4);
    M3Material mtr = M3Material();
    mtr.diffuseTexture = texGrid;

    final plane = addMesh(M3Mesh(geomPlane, material: mtr), Vector3(0, 0, 0));

    Vector3 scale = Vector3(sizeX, 1, sizeZ);
    pos ??= Vector3(0, 0, 4);

    final hf = geomPlane.toHeightField();
    M3RigidBody rbHF = physicsSystem.engine.createRigidBody(M3RigidBodyDesc.fixed()..position = pos);
    if (rbHF is M3RapierRigidBody) {
      world.createHeightfieldCollider(rbHF, hf.data, geomPlane.widthSegments + 1, geomPlane.heightSegments + 1, scale);
    }

    physicsSystem.attachEntity(plane, rbHF);
    final rotAngle = pi * 0.5;
    rbHF.setRotation(Quaternion.euler(0, rotAngle, 0));
    return rbHF;
  }

  void addFalling() {
    final cylGeom = M3CylinderGeom(topRadius: 0.5, bottomRadius: 0.5, height: 1.0, axis: M3Axis.y);
    final ballMesh = M3Mesh(M3Resources.unitSphere);
    final cubeMesh = M3Mesh(M3Resources.unitCube);

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
      final box = addMesh(cubeMesh.clone(), boxPos)..color = Colors.yellow;
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

  // ── Per-frame update ─────────────────────────────────────────────────────

  @override
  void update(double delta) {
    if (_inputCtrl.brake) {
      uiThrottle = 0.0;
    }

    // Combine keyboard input with UI slider/button inputs
    final effectiveThrottle = _inputCtrl.throttle != 0.0 ? _inputCtrl.throttle : uiThrottle;
    final effectiveSteer = _inputCtrl.steer != 0.0 ? _inputCtrl.steer : uiSteering;
    final effectiveBrake = _inputCtrl.brake || uiBrake;

    // Step vehicle controller before physics simulation step
    _car.preStep(delta, effectiveThrottle, effectiveSteer, effectiveBrake);
    super.update(delta);
    // Update visual wheel positions from raycast wheel states
    _car.postStep();

    // Camera locks on the back of the car chassis
    final carPos = _car.chassisBody.position;
    final carRot = _car.chassisBody.rotation;
    final backward = carRot.rotate(Vector3(-1, 0, 0)); // car forward is +X, so rear is -X
    final carYaw = math.atan2(backward.y, backward.x);

    camera.target = carPos;
    camera.setEuler(-carYaw + math.pi / 2, -math.pi / 8, 0, distance: 18);
  }

  void resetCar() {
    uiSteering = 0.0;
    uiThrottle = 0.0;
    uiBrake = false;
    _car.reset(Vector3(0, 0, 7));
  }

  @override
  fm.Widget buildUI(fm.BuildContext context) {
    return fm.StatefulBuilder(
      builder: (context, setState) {
        return fm.Stack(
          children: [
            // 200x200 control pad on the left, vertically centered
            fm.Align(
              alignment: fm.Alignment.centerLeft,
              child: fm.Padding(
                padding: const fm.EdgeInsets.only(left: 20.0),
                child: fm.Container(
                  width: 200,
                  height: 200,
                  decoration: fm.BoxDecoration(
                    color: fm.Colors.black54,
                    borderRadius: fm.BorderRadius.circular(16),
                    border: fm.Border.all(color: fm.Colors.white24, width: 1.5),
                  ),
                  child: fm.Stack(
                    children: [
                      // Vertical slider for Engine Force / Throttle (left strip)
                      fm.Positioned(
                        left: 4,
                        top: 10,
                        bottom: 10,
                        width: 50,
                        child: fm.Column(
                          children: [
                            const fm.Text(
                              'Power',
                              style: fm.TextStyle(color: fm.Colors.white, fontSize: 11, fontWeight: fm.FontWeight.bold),
                            ),
                            fm.Expanded(
                              child: fm.RotatedBox(
                                quarterTurns: 3, // vertical: up is forward
                                child: fm.Slider(
                                  value: uiThrottle,
                                  min: -1.0,
                                  max: 1.0,
                                  divisions: 20,
                                  label: uiThrottle.toStringAsFixed(2),
                                  activeColor: fm.Colors.greenAccent,
                                  onChanged: (val) {
                                    setState(() => uiThrottle = val);
                                  },
                                ),
                              ),
                            ),
                            fm.Text(
                              '${(uiThrottle * 100).toInt()}%',
                              style: const fm.TextStyle(color: fm.Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),

                      // Brake button (top right inside the pad)
                      fm.Positioned(
                        right: 36,
                        top: 20,
                        child: fm.GestureDetector(
                          onTapDown: (_) => setState(() {
                            uiBrake = true;
                            uiThrottle = 0.0;
                          }),
                          onTapUp: (_) => setState(() => uiBrake = false),
                          onTapCancel: () => setState(() => uiBrake = false),
                          child: fm.Container(
                            width: 68,
                            height: 68,
                            decoration: fm.BoxDecoration(
                              shape: fm.BoxShape.circle,
                              color: uiBrake ? fm.Colors.redAccent : fm.Colors.red.withValues(alpha: 0.75),
                              border: fm.Border.all(color: fm.Colors.white, width: 2),
                              boxShadow: const [fm.BoxShadow(color: fm.Colors.black45, blurRadius: 6, spreadRadius: 1)],
                            ),
                            child: const fm.Center(
                              child: fm.Text(
                                'BRAKE',
                                style: fm.TextStyle(
                                  color: fm.Colors.white,
                                  fontSize: 12,
                                  fontWeight: fm.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Horizontal slider for Steering (along bottom right)
                      fm.Positioned(
                        left: 56,
                        right: 4,
                        bottom: 8,
                        child: fm.Column(
                          mainAxisSize: fm.MainAxisSize.min,
                          children: [
                            const fm.Text(
                              'Steer',
                              style: fm.TextStyle(color: fm.Colors.white, fontSize: 11, fontWeight: fm.FontWeight.bold),
                            ),
                            fm.Slider(
                              value: uiSteering,
                              min: -1.0,
                              max: 1.0,
                              divisions: 20,
                              label: uiSteering.toStringAsFixed(2),
                              activeColor: fm.Colors.blueAccent,
                              onChanged: (val) {
                                setState(() => uiSteering = val);
                              },
                              onChangeEnd: (val) {
                                setState(() => uiSteering = 0.0);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _car.dispose();
    super.dispose();
  }
}

// ── Car vehicle (using DynamicRayCastVehicleController) ──────────────────────

class _CarVehicle {
  static const double _chassisHx = 2.0;
  static const double _chassisHy = 0.7;
  static const double _chassisHz = 0.35;

  static const double _wheelRadius = 0.5;
  static const double _wheelWidth = 0.2; // half-width of cylinder mesh
  static const double _wheelOffsetX = 1.5; // front/rear from center
  static const double _wheelOffsetY = 1.05; // left/right from center
  static const double _wheelOffsetZ = -0.15; // chassis attachment point in Z

  // Drive / steering tunables
  static const double _maxEngineForce = 1600.0; // N per wheel
  static const double _brakeForce = 80.0; // N·s impulse limit
  static const double _steerAngle = 25.0 * pi / 180.0; // +/- 25 degrees (~0.436 rad)

  final VehicleController controller;
  final M3RapierRigidBody chassisBody;
  final List<M3Entity> wheelEntities;

  _CarVehicle._({required this.controller, required this.chassisBody, required this.wheelEntities});

  /// Factory: spawns the full car (chassis rigid body + raycast wheels) in [scene].
  static _CarVehicle spawn(HeightfieldScene scene, {required Vector3 spawnPos}) {
    // ── Chassis Rigid Body ──────────────────────────────────────────────────
    final bodyDesc = M3RigidBodyDesc.dynamic()
      ..position = spawnPos
      ..linearDamping = 0.3
      ..angularDamping = 1.5;

    final chassisRb = scene.physicsSystem.addBox(_chassisHx, _chassisHy, _chassisHz, desc: bodyDesc);
    if (chassisRb is M3RapierRigidBody) {
      final collider = chassisRb.colliders[0];
      collider.density = 100.0;
      collider.friction = 0.5;
      collider.restitution = 0.05;
    }

    // ── Visual Chassis Mesh ─────────────────────────────────────────────────
    final chassisGeom = M3BoxGeom(_chassisHx * 2, _chassisHy * 2, _chassisHz * 2);
    final chassisMesh = M3Mesh(chassisGeom);
    chassisMesh.subMeshes[0].mtr.diffuse = Vector4(0.1, 0.45, 0.9, 1.0); // blue body

    // Roof / cabin sub-mesh (smaller box on top)
    final cabinSub = M3SubMesh(M3BoxGeom(_chassisHx * 1.0, _chassisHy * 1.8, _chassisHz * 1.6));
    cabinSub.localMatrix = Matrix4.compose(
      Vector3(-0.2, 0, _chassisHz + _chassisHz * 0.8),
      Quaternion.identity(),
      Vector3.all(1),
    );
    cabinSub.mtr.diffuse = Vector4(0.15, 0.55, 1.0, 1.0);
    chassisMesh.subMeshes.add(cabinSub);

    final chassisEntity = scene.addMesh(chassisMesh, spawnPos);
    scene.physicsSystem.attachEntity(chassisEntity, chassisRb);

    // ── Vehicle Controller ──────────────────────────────────────────────────
    // +Z is up (axis 2), +X is forward (axis 0)
    final controller = VehicleController.create(scene.world, chassisRb as RigidBody, upAxis: 2, forwardAxis: 0);

    // ── Suspension & Wheel Tuning ───────────────────────────────────────────
    final tuning = const WheelTuning(
      suspensionStiffness: 45.0,
      suspensionCompression: 2.5,
      suspensionDamping: 4.5,
      maxSuspensionTravel: 0.45,
      frictionSlip: 8.5,
      maxSuspensionForce: 8000.0,
    );

    // Wheel attachment points in chassis space:
    // [frontLeft, frontRight, rearLeft, rearRight]
    // +X: front, -X: rear
    // -Y: left, +Y: right
    final wheelConfigs = [
      (pos: Vector3(_wheelOffsetX, -_wheelOffsetY, _wheelOffsetZ), isFront: true),
      (pos: Vector3(_wheelOffsetX, _wheelOffsetY, _wheelOffsetZ), isFront: true),
      (pos: Vector3(-_wheelOffsetX, -_wheelOffsetY, _wheelOffsetZ), isFront: false),
      (pos: Vector3(-_wheelOffsetX, _wheelOffsetY, _wheelOffsetZ), isFront: false),
    ];

    final downDir = Vector3(0, 0, -1);
    final axleDir = Vector3(0, -1, 0);

    // ── Visual Wheel Mesh ───────────────────────────────────────────────────
    final texGrid = M3Texture.createCheckerboard(size: 6);
    final wheelGeom = M3CylinderGeom(
      topRadius: _wheelRadius,
      bottomRadius: _wheelRadius,
      height: _wheelWidth * 2,
      axis: M3Axis.y,
    );
    final baseWheelMesh = M3Mesh(wheelGeom);
    baseWheelMesh.subMeshes[0].mtr
      ..diffuseTexture = texGrid
      ..diffuse = Vector4(1.0, 0, 1.0, 1.0);
    final hubSub = M3SubMesh(
      M3CylinderGeom(
        topRadius: _wheelRadius * 0.35,
        bottomRadius: _wheelRadius * 0.35,
        height: _wheelWidth * 2.1,
        axis: M3Axis.y,
      ),
    );
    hubSub.mtr.diffuse = Vector4(1.0, 0.5, 0.0, 1.0); // silver
    baseWheelMesh.subMeshes.add(hubSub);

    final List<M3Entity> wheelEntities = [];

    for (final cfg in wheelConfigs) {
      controller.addWheel(
        cfg.pos,
        direction: downDir,
        axle: axleDir,
        suspensionRestLength: 0.4,
        radius: _wheelRadius,
        tuning: tuning,
      );

      final wheelMesh = baseWheelMesh.clone();
      final initialPos = spawnPos + cfg.pos + Vector3(0, 0, -0.4);
      final entity = scene.addMesh(wheelMesh, initialPos);
      wheelEntities.add(entity);
    }

    return _CarVehicle._(
      controller: controller,
      chassisBody: chassisRb as M3RapierRigidBody,
      wheelEntities: wheelEntities,
    );
  }

  /// Sets wheel inputs and advances the vehicle controller.
  /// **Must be called before [super.update] / [world.step]**.
  void preStep(double dt, double throttle, double steer, bool brake) {
    // Steer angle: steer = -1 (left) -> positive rotation around +Z (turns left)
    final steerAngle = -steer * _steerAngle;
    controller.setSteering(0, steerAngle);
    controller.setSteering(1, steerAngle);

    final engineForce = throttle * _maxEngineForce;
    final currentBrake = brake ? _brakeForce : 0.0;

    for (int i = 0; i < 4; i++) {
      controller.setEngineForce(i, engineForce);
      controller.setBrake(i, currentBrake);
    }

    controller.update(dt);
  }

  /// Syncs visual wheel meshes to raycast wheel states after physics step.
  void postStep() {
    final chassisRot = chassisBody.rotation;
    for (int i = 0; i < wheelEntities.length; i++) {
      final state = controller.wheelState(i);
      final entity = wheelEntities[i];

      entity.position = state.center;

      final steerRot = Quaternion.axisAngle(Vector3(0, 0, 1), state.steering);
      final spinRot = Quaternion.axisAngle(Vector3(0, 1, 0), state.rotation);
      entity.rotation = chassisRot * steerRot * spinRot;
    }
  }

  void reset(Vector3 spawnPos) {
    chassisBody.setPosition(spawnPos);
    chassisBody.setRotation(Quaternion.identity());
    chassisBody.setLinearVelocity(Vector3.zero());
    chassisBody.setAngularVelocity(Vector3.zero());
  }

  void dispose() {
    controller.dispose();
  }
}

// ── Input controller ─────────────────────────────────────────────────────────

class _CarInputController extends M3InputController {
  final HeightfieldScene scene;
  late final M3CameraOrbitController _orbit;

  double throttle = 0.0; // -1..1  (positive = forward)
  double steer = 0.0; // -1..1  (negative = left, positive = right)
  bool brake = false;

  _CarInputController(this.scene) {
    _orbit = M3CameraOrbitController(scene.camera);
  }

  @override
  void update(double dt) {
    final kb = M3AppEngine.instance.keyboard;
    throttle = 0.0;
    steer = 0.0;
    brake = false;

    if (kb.isPressed(LogicalKeyboardKey.keyW) || kb.isPressed(LogicalKeyboardKey.arrowUp)) {
      throttle = 1.0;
    } else if (kb.isPressed(LogicalKeyboardKey.keyS) || kb.isPressed(LogicalKeyboardKey.arrowDown)) {
      throttle = -1.0;
    }

    if (kb.isPressed(LogicalKeyboardKey.keyA) || kb.isPressed(LogicalKeyboardKey.arrowLeft)) {
      steer = -1.0;
    } else if (kb.isPressed(LogicalKeyboardKey.keyD) || kb.isPressed(LogicalKeyboardKey.arrowRight)) {
      steer = 1.0;
    }

    if (kb.isPressed(LogicalKeyboardKey.space)) {
      brake = true;
    }

    if (kb.isPressed(LogicalKeyboardKey.keyR)) {
      scene.resetCar();
    }
  }

  @override
  void onScroll(double scrollDelta) => _orbit.onScroll(scrollDelta);

  @override
  void onKeyDown(KeyDownEvent e) {
    if (e.logicalKey == LogicalKeyboardKey.keyR) {
      scene.resetCar();
    } else if (e.logicalKey == LogicalKeyboardKey.keyA || e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      steer = -1.0;
    } else if (e.logicalKey == LogicalKeyboardKey.keyD || e.logicalKey == LogicalKeyboardKey.arrowRight) {
      steer = 1.0;
    } else if (e.logicalKey == LogicalKeyboardKey.keyW || e.logicalKey == LogicalKeyboardKey.arrowUp) {
      throttle = 1.0;
    } else if (e.logicalKey == LogicalKeyboardKey.keyS || e.logicalKey == LogicalKeyboardKey.arrowDown) {
      throttle = -1.0;
    }
  }

  @override
  void onKeyRepeat(PhysicalKeyboardKey key) {}

  @override
  void onKeyUp(KeyUpEvent e) {
    if (e.logicalKey == LogicalKeyboardKey.keyA || e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (steer < 0) steer = 0.0;
    } else if (e.logicalKey == LogicalKeyboardKey.keyD || e.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (steer > 0) steer = 0.0;
    } else if (e.logicalKey == LogicalKeyboardKey.keyW || e.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (throttle > 0) throttle = 0.0;
    } else if (e.logicalKey == LogicalKeyboardKey.keyS || e.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (throttle < 0) throttle = 0.0;
    }
  }

  @override
  void onTouchDown(M3Touch touch) => _orbit.onTouchDown(touch);

  @override
  void onTouchMove(M3Touch touch) => _orbit.onTouchMove(touch);

  @override
  void onTouchUp(M3Touch touch) => _orbit.onTouchUp(touch);
}
