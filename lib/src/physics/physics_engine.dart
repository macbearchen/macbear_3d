import 'package:oimo_physics/oimo_physics.dart' as oimo;
import 'package:vector_math/vector_math.dart';

/// Physics simulation engine wrapper for oimo_physics with gravity and collision.
class M3PhysicsEngine {
  // physics
  late oimo.World? _world;
  oimo.World? get world => _world;

  // update per step
  double _accumulator = 0.0;
  int _maxStepsPerFrame = 3;
  set maxStepsPerFrame(int val) {
    _maxStepsPerFrame = val;
    _accumulator = 0;
  }

  M3PhysicsEngine() {
    resetWorld();
  }

  void resetWorld() {
    final worldConfig = oimo.WorldConfigure(gravity: Vector3(0, 0, -9.81), isStat: true, scale: 1.0);
    final world = oimo.World(worldConfig);
    _world = world;
    _accumulator = 0;
  }

  oimo.RigidBody _addPrimitive(oimo.Shape shape, {double density = 1.0, Vector3? position}) {
    // static body (density is zero)
    final config = oimo.ObjectConfigure(shapes: [shape], move: density > 0.0, position: position);
    final rb = _world?.add(config) as oimo.RigidBody;
    return rb;
  }

  oimo.RigidBody addBox(double width, double height, double depth, {Vector3? position, double density = 1.0}) {
    final shape = oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box, density: density), width, height, depth);
    final rb = _addPrimitive(shape, density: density, position: position);
    return rb;
  }

  oimo.RigidBody addSphere(double radius, {double density = 1.0, Vector3? position}) {
    final shape = oimo.Sphere(oimo.ShapeConfig(geometry: oimo.Shapes.sphere, density: density), radius);
    final rb = _addPrimitive(shape, density: density, position: position);
    return rb;
  }

  oimo.RigidBody addCylinder(double radius, double height, {double density = 1.0, Vector3? position}) {
    final shape = oimo.Cylinder(oimo.ShapeConfig(geometry: oimo.Shapes.cylinder, density: density), radius, height);
    final rb = _addPrimitive(shape, density: density, position: position);
    return rb;
  }

  oimo.RigidBody addCapsule(double radius, double height, {double density = 1.0, Vector3? position}) {
    final shape = oimo.Capsule(oimo.ShapeConfig(geometry: oimo.Shapes.capsule, density: density), radius, height);
    final rb = _addPrimitive(shape, density: density, position: position);
    return rb;
  }

  double get interpolationAlpha {
    if (_world == null) return 0.0;
    return _accumulator / _world!.timeStep;
  }

  void update(double sec, {void Function()? onBeforeStep}) {
    if (_world == null) return;

    _accumulator += sec;
    int steps = 0;
    while (_accumulator >= _world!.timeStep && steps < _maxStepsPerFrame) {
      if (onBeforeStep != null) onBeforeStep();
      _world!.step();
      _accumulator -= _world!.timeStep;
      steps++;
    }
  }

  oimo.RigidBody addGround(double sizeW, double sizeH, double sizeD) {
    final groundConfig = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), sizeW, sizeH, sizeD)],
      position: Vector3(0.0, 0.0, -sizeD / 2.0),
    );
    // ignore: unused_local_variable
    final rbGround = _world?.add(groundConfig) as oimo.RigidBody;
    return rbGround;
  }

  void addBoundaryFence(double sizeW, double sizeH, double sizeD) {
    final fencePosX = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), sizeD, sizeH, sizeD)],
      position: Vector3((sizeW + sizeD) / 2, 0, 0),
    );
    _world?.add(fencePosX);

    final fenceNegX = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), sizeD, sizeH, sizeD)],
      position: Vector3((sizeW + sizeD) / -2, 0, 0),
    );
    _world?.add(fenceNegX);

    final fencePosY = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), sizeW, sizeD, sizeD)],
      position: Vector3(0, (sizeW + sizeD) / 2, 0),
    );
    _world?.add(fencePosY);
    final fenceNegY = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), sizeW, sizeD, sizeD)],
      position: Vector3(0, (sizeW + sizeD) / -2, 0),
    );
    _world?.add(fenceNegY);
  }
}
