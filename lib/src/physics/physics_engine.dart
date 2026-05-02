import 'package:vector_math/vector_math.dart';

/// Abstract physics body for an entity.
abstract class M3PhysicsBody {
  Vector3 get position;
  set position(Vector3 value);

  Quaternion get orientation;
  set orientation(Quaternion value);
}

/// Abstract physics engine interface.
abstract class M3PhysicsEngine {
  void resetWorld();

  M3PhysicsBody addBox(double width, double height, double depth, {Vector3? position, double density = 1.0});
  M3PhysicsBody addSphere(double radius, {double density = 1.0, Vector3? position});
  M3PhysicsBody addCylinder(double radius, double height, {double density = 1.0, Vector3? position});
  M3PhysicsBody addCapsule(double radius, double height, {double density = 1.0, Vector3? position});
  
  M3PhysicsBody addGround(double sizeW, double sizeH, double sizeD);
  void addBoundaryFence(double sizeW, double sizeH, double sizeD);

  double get interpolationAlpha;
  void step(double sec, {void Function()? onBeforeStep});

  bool showStats = false;
  String get info => "";
}
