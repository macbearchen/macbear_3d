import '../m3_internal.dart';

/// Physics-entity binding layer.
class M3PhysicsSystem {
  final M3PhysicsEngine _engine;

  // update per step
  double _accumulator = 0.0;
  final double _timeStep = 1 / 60.0;
  final int _maxStepsPerFrame = 6;

  double get _interpolationAlpha {
    return _accumulator / _timeStep;
  }

  // 綁定：RigidBody → Entity
  final Map<int, M3Entity> _bodyToEntity = {};

  /// constructor
  M3PhysicsSystem(this._engine);

  M3PhysicsEngine get engine => _engine;
  String get info {
    return _engine.info;
  }

  Future<void> init({Vector3? gravity}) async {
    await _engine.init(gravity: gravity);
  }

  /// dispose physics system
  void dispose() {
    _engine.dispose();
    _bodyToEntity.clear();
  }

  /// reset physics system
  void reset() {
    _engine.resetWorld();
    _bodyToEntity.clear();
    _accumulator = 0.0;
  }

  /// add box rigid body
  M3RigidBody addBox(double hx, double hy, double hz, {M3RigidBodyDesc? desc}) {
    final body = _engine.createRigidBody(desc ?? M3RigidBodyDesc.dynamic());
    _engine.createCollider(body, M3ColliderDesc.cuboid(hx, hy, hz));
    return body;
  }

  /// add sphere rigid body
  M3RigidBody addSphere(double radius, {M3RigidBodyDesc? desc}) {
    final body = _engine.createRigidBody(desc ?? M3RigidBodyDesc.dynamic());
    _engine.createCollider(body, M3ColliderDesc.ball(radius));
    return body;
  }

  /// add cylinder rigid body
  M3RigidBody addCylinder({required double radius, required double halfHeight, M3RigidBodyDesc? desc}) {
    final body = _engine.createRigidBody(desc ?? M3RigidBodyDesc.dynamic());
    _engine.createCollider(body, M3ColliderDesc.cylinder(radius: radius, halfHeight: halfHeight));
    return body;
  }

  /// Adds a capsule-shaped rigid body.
  ///
  /// [axis] specifies the capsule's long axis in this package's
  /// Z-up coordinate system. Defaults to [M3Axis.z] (upright).
  M3RigidBody addCapsule({
    required double radius,
    required double halfHeight,
    M3RigidBodyDesc? desc,
    M3Axis axis = M3Axis.z,
  }) {
    final body = _engine.createRigidBody(desc ?? M3RigidBodyDesc.dynamic());
    M3ColliderDesc colliderDesc;
    if (axis == M3Axis.x) {
      colliderDesc = M3ColliderDesc.capsuleX(radius: radius, halfHeight: halfHeight);
    } else if (axis == M3Axis.y) {
      colliderDesc = M3ColliderDesc.capsuleY(radius: radius, halfHeight: halfHeight);
    } else {
      colliderDesc = M3ColliderDesc.capsuleZ(radius: radius, halfHeight: halfHeight);
    }
    _engine.createCollider(body, colliderDesc);
    return body;
  }

  /// attach entity to physics body
  void attachEntity(M3Entity entity, M3RigidBody body) {
    entity.rigidBody = body;
    _bodyToEntity[body.handle] = entity;
  }

  /// detach entity from physics body
  void detachEntity(M3Entity entity) {
    final body = entity.rigidBody;
    if (body != null) {
      _bodyToEntity.remove(body.handle);
      entity.rigidBody = null;
    }
  }

  /// update physics world
  void update(double dt, {void Function()? onBeforeStep}) {
    _accumulator += dt;
    int steps = 0;
    while (_accumulator >= _timeStep && steps < _maxStepsPerFrame) {
      if (onBeforeStep != null) onBeforeStep();
      _engine.step(_timeStep);
      _accumulator -= _timeStep;
      steps++;
    }

    // sync physics to entities
    _syncToEntities();
  }

  // sync from physics system to entities
  void _syncToEntities() {
    for (final entity in _bodyToEntity.values) {
      entity.syncFromPhysics(_interpolationAlpha);
    }
  }
}
