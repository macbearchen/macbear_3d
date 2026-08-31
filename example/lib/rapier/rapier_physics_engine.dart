import 'package:macbear_3d/macbear_3d.dart';
import 'package:rapier_physics/rapier_physics.dart' as rapier;
import 'package:vector_math/vector_math.dart';

class M3RapierRigidBody extends rapier.RigidBody implements M3RigidBody {
  M3RapierRigidBody(super.handle, super.world);
}

class M3RapierCollider extends rapier.Collider implements M3Collider {
  M3RapierCollider(super.handle, super.body);
}

class M3RapierPhysicsEngine implements M3PhysicsEngine {
  final rapier.RapierWorld world = rapier.RapierWorld();
  bool _initialized = false;

  @override
  Future<void> init({Vector3? gravity}) async {
    if (_initialized) return;
    await world.init(gravity: gravity ?? Vector3(0, 0, -9.81));
    _initialized = true;
  }

  @override
  void dispose() {
    world.destroy();
  }

  @override
  void resetWorld() {
    world.destroy();
  }

  @override
  M3RigidBody createRigidBody(M3RigidBodyDesc desc) {
    rapier.RigidBodyDesc rapierDesc = _mapRigidBodyDesc(desc);
    final rb = world.createRigidBody(rapierDesc);
    return M3RapierRigidBody(rb.handle, world);
  }

  @override
  void removeRigidBody(M3RigidBody body) {
    if (body is M3RapierRigidBody) {
      world.removeRigidBody(body);
    }
  }

  @override
  M3Collider createCollider(M3RigidBody body, M3ColliderDesc desc) {
    if (body is! M3RapierRigidBody) {
      throw ArgumentError('Body must be an M3RapierRigidBody');
    }
    rapier.ColliderDesc rapierDesc = _mapColliderDesc(desc);
    final collider = world.createCollider(body, rapierDesc);
    return M3RapierCollider(collider.handle, body);
  }

  @override
  void step(double sec) {
    if (!_initialized) return;

    world.step();
  }

  @override
  String get info => 'rapier physics (v${world.version})';

  rapier.RigidBodyDesc _mapRigidBodyDesc(M3RigidBodyDesc desc) {
    rapier.RigidBodyDesc rapierDesc;
    switch (desc.type) {
      case M3RigidBodyType.dynamic:
        rapierDesc = rapier.RigidBodyDesc.dynamic();
        break;
      case M3RigidBodyType.fixed:
        rapierDesc = rapier.RigidBodyDesc.fixed();
        break;
      case M3RigidBodyType.kinematicPositionBased:
        rapierDesc = rapier.RigidBodyDesc.kinematicPositionBased();
        break;
      case M3RigidBodyType.kinematicVelocityBased:
        rapierDesc = rapier.RigidBodyDesc.kinematicVelocityBased();
        break;
    }
    rapierDesc.position.setFrom(desc.position);
    rapierDesc.rotation.setFrom(desc.rotation);
    rapierDesc.linearVelocity.setFrom(desc.linearVelocity);
    rapierDesc.angularVelocity.setFrom(desc.angularVelocity);
    rapierDesc.linearDamping = desc.linearDamping;
    rapierDesc.angularDamping = desc.angularDamping;
    rapierDesc.canSleep = desc.canSleep;
    rapierDesc.ccdEnabled = desc.ccdEnabled;
    return rapierDesc;
  }

  rapier.ColliderDesc _mapColliderDesc(M3ColliderDesc desc) {
    rapier.ColliderDesc rapierDesc;
    switch (desc.shapeType) {
      case M3ColliderShapeType.cuboid:
        rapierDesc = rapier.ColliderDesc.cuboid(desc.hx, desc.hy, desc.hz);
        break;
      case M3ColliderShapeType.ball:
        rapierDesc = rapier.ColliderDesc.ball(desc.radius);
        break;
      case M3ColliderShapeType.cylinder:
        rapierDesc = rapier.ColliderDesc.cylinder(halfHeight: desc.halfHeight, radius: desc.radius);
        break;
      case M3ColliderShapeType.cone:
        rapierDesc = rapier.ColliderDesc.cone(halfHeight: desc.halfHeight, radius: desc.radius);
        break;
      case M3ColliderShapeType.capsuleX:
        rapierDesc = rapier.ColliderDesc.capsuleX(halfHeight: desc.halfHeight, radius: desc.radius);
        break;
      case M3ColliderShapeType.capsuleY:
        rapierDesc = rapier.ColliderDesc.capsuleY(halfHeight: desc.halfHeight, radius: desc.radius);
        break;
      case M3ColliderShapeType.capsuleZ:
        rapierDesc = rapier.ColliderDesc.capsuleZ(halfHeight: desc.halfHeight, radius: desc.radius);
        break;
      case M3ColliderShapeType.heightfield:
        throw UnimplementedError('Heightfield collider not supported in M3RapierPhysicsEngine yet');
    }
    rapierDesc.localPosition.setFrom(desc.localPosition);
    rapierDesc.localRotation.setFrom(desc.localRotation);
    rapierDesc.friction = desc.friction;
    rapierDesc.restitution = desc.restitution;
    rapierDesc.density = desc.density;
    // rapierDesc.isSensor = desc.isSensor;
    return rapierDesc;
  }
}
