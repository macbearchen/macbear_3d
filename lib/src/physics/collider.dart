part of 'physics_engine.dart';

// dart format off
enum M3ColliderShapeType {
  cuboid,
  ball,
  cylinder,
  cone,
  capsuleX,
  capsuleY,
  capsuleZ,
  heightfield,
}
// dart format on

/// Collider descriptor
class M3ColliderDesc {
  final M3ColliderShapeType shapeType;

  // Dimensions
  double hx = 0, hy = 0, hz = 0; // cuboid (half-extents)
  double radius = 0; // ball, cylinder, cone, capsule
  double halfHeight = 0; // cylinder, cone, capsule

  // Common properties
  Vector3 localPosition = Vector3.zero();
  Quaternion localRotation = Quaternion.identity();

  double friction = 0.5;
  double restitution = 0.0;
  double density = 1.0;
  bool isSensor = false;

  M3ColliderDesc.cuboid(this.hx, this.hy, this.hz) : shapeType = M3ColliderShapeType.cuboid;
  M3ColliderDesc.ball(this.radius) : shapeType = M3ColliderShapeType.ball;
  M3ColliderDesc.cylinder({required this.radius, required this.halfHeight}) : shapeType = M3ColliderShapeType.cylinder;
  M3ColliderDesc.cone({required this.radius, required this.halfHeight}) : shapeType = M3ColliderShapeType.cone;
  M3ColliderDesc.capsuleX({required this.radius, required this.halfHeight}) : shapeType = M3ColliderShapeType.capsuleX;
  M3ColliderDesc.capsuleY({required this.radius, required this.halfHeight}) : shapeType = M3ColliderShapeType.capsuleY;
  M3ColliderDesc.capsuleZ({required this.radius, required this.halfHeight}) : shapeType = M3ColliderShapeType.capsuleZ;
}

abstract class M3Collider {}
