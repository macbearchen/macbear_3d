import 'package:vector_math/vector_math.dart';

import '../m3_internal.dart';

/// Abstract physics body for an entity.
abstract class M3RigidBody {
  final int handle;

  M3RigidBody(this.handle);

  Vector3 get position;
  set position(Vector3 value);

  Quaternion get orientation;
  set orientation(Quaternion value);
}

/// Abstract physics engine interface.
abstract class M3PhysicsEngine {
  void resetWorld();

  M3RigidBody addBox(double width, double height, double depth, {Vector3? position, double density = 1.0});
  M3RigidBody addSphere(double radius, {double density = 1.0, Vector3? position});
  M3RigidBody addCylinder(double radius, double height, {double density = 1.0, Vector3? position});
  M3RigidBody addCapsule(double radius, double height, {double density = 1.0, Vector3? position});

  M3RigidBody addGround(double sizeW, double sizeH, double sizeD);
  void addBoundaryFence(double sizeW, double sizeH, double sizeD);

  double get interpolationAlpha;
  void step(double sec, {void Function()? onBeforeStep});

  bool showStats = false;
  String get info => "";
}

class M3PhysicsSystem {
  final M3PhysicsEngine engine;

  // 綁定：RigidBody → Entity
  final Map<int, M3Entity> _bodyToEntity = {};

  M3PhysicsSystem(this.engine);

  // 註冊 entity
  /*  void addEntity(M3Entity entity) {
    final body = entity.rigidBody;
    if (body == null) return;

    engine.addBody(body);
    _bodyToEntity[body.handle] = entity;
  }

  void removeEntity(M3Entity entity) {
    final body = entity.rigidBody;
    if (body == null) return;

    engine.removeBody(body);
    _bodyToEntity.remove(body.handle);
  }
*/
  // 主更新
  void update(double dt) {
    // 1️⃣ 推進 physics
    engine.step(dt);

    // 2️⃣ 同步 physics → entity
    _syncToEntities();
  }

  void _syncToEntities() {
    for (final entry in _bodyToEntity.entries) {
      final bodyHandle = entry.key;
      final entity = entry.value;
      final body = entity.rigidBody!;

      // 👉 這裡假設 body 已經被 engine 更新
      entity.transform.position = body.position;
      entity.transform.rotation = body.orientation;
    }
  }
}
