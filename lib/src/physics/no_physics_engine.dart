import 'package:vector_math/vector_math.dart';
import 'physics_engine.dart';

/// No-op rigid body used when physics is disabled or not available
class M3NoRigidBody implements M3RigidBody {
  @override
  final int handle;

  M3NoRigidBody(this.handle);

  @override
  Quaternion orientation = Quaternion.identity();

  @override
  Vector3 position = Vector3.zero();
}

/// No-op physics engine used when physics is disabled or not available
class M3NoPhysicsEngine implements M3PhysicsEngine {
  int _nextHandle = 1;

  int _genHandle() => _nextHandle++;

  @override
  void resetWorld() {
    // do nothing
  }

  @override
  M3RigidBody addBox(double width, double height, double depth, {Vector3? position, double density = 1.0}) {
    return M3NoRigidBody(_genHandle());
  }

  @override
  M3RigidBody addSphere(double radius, {double density = 1.0, Vector3? position}) {
    return M3NoRigidBody(_genHandle());
  }

  @override
  M3RigidBody addCylinder(double radius, double height, {double density = 1.0, Vector3? position}) {
    return M3NoRigidBody(_genHandle());
  }

  @override
  M3RigidBody addCapsule(double radius, double height, {double density = 1.0, Vector3? position}) {
    return M3NoRigidBody(_genHandle());
  }

  @override
  M3RigidBody addGround(double sizeW, double sizeH, double sizeD) {
    return M3NoRigidBody(_genHandle());
  }

  @override
  void addBoundaryFence(double sizeW, double sizeH, double sizeD) {
    // do nothing
  }

  @override
  double get interpolationAlpha => 1.0;

  @override
  void step(double sec, {void Function()? onBeforeStep}) {
    onBeforeStep?.call(); // 👈 這個建議保留
  }

  @override
  String get info => "NoPhysicsEngine (disabled)";
}
