import 'base_scene.dart';

class CompoundScene extends BaseScene {
  final _random = Random();

  // ── Dumbbell spawner ────────────────────────────────────────────────────────
  static const int _maxSpawned = 500;
  static const double _spawnInterval = 0.1; // 10 dumbbells/sec
  int _spawnedCount = 0;
  double _spawnAccum = 0.0;

  CompoundScene({required super.physics});

  @override
  Future<void> load() async {
    await super.load();

    // Add a compound "Dumbbell" object
    addDumbbell(Vector3(0, 0, 4));
    addTable(Vector3(0, 0, 6));
    addTable(Vector3(0, 0, 8));
    addTable(Vector3(1, 0, 3));

    // Dynamic green sphere at (-3, -2, 5.0) — radius 0.8 for both physics & mesh
    final pos2 = Vector3(-3, -2, 5.0);
    final rb = physicsSystem.addSphere(0.8, desc: M3RigidBodyDesc.dynamic()..position = pos2);
    final entity = addMesh(M3Mesh(M3SphereGeom(0.8)), pos2)..color = Colors.lime;
    physicsSystem.attachEntity(entity, rb);
  }

  void addDumbbell(Vector3 pos) {
    const offset = 0.6;
    // 1. Create a single dynamic rigid body, The handle (middle bar)
    final rb = physicsSystem.addBox(offset, 0.1, 0.1, desc: M3RigidBodyDesc.dynamic()..position = pos);

    // 2. Add multiple colliders with offsets
    if (rb is M3RapierRigidBody) {
      // Left weight
      world.createCollider(
        rb,
        ColliderDesc.ball(0.3)
          ..restitution = 0.9
          ..localPosition = Vector3(-offset, 0, 0),
      );

      // Right weight
      world.createCollider(rb, ColliderDesc.ball(0.6)..localPosition = Vector3(offset, 0, 0));

      // 3. Create a single visual mesh for the whole assembly
      final dumbbellMesh = M3Mesh(M3BoxGeom(offset * 2, 0.2, 0.2));

      // Add left weight as a submesh
      final leftSub = M3SubMesh(M3Resources.unitSphere);
      leftSub.localMatrix = Matrix4.compose(Vector3(-offset, 0, 0), Quaternion.identity(), Vector3.all(0.6));
      leftSub.mtr.diffuse = Vector4(1.0, 1.0, 0.0, 1.0);
      dumbbellMesh.subMeshes.add(leftSub);

      // Add right weight as a submesh
      final rightSub = M3SubMesh(M3Resources.unitSphere);
      rightSub.localMatrix = Matrix4.compose(Vector3(offset, 0, 0), Quaternion.identity(), Vector3.all(1.2));
      rightSub.mtr.diffuse = Vector4(0.0, 1.0, 1.0, 1.0);
      dumbbellMesh.subMeshes.add(rightSub);

      final dumbbellEntity = addMesh(dumbbellMesh, pos);
      physicsSystem.attachEntity(dumbbellEntity, rb);

      // Give it some initial rotation and angular velocity to see it tumble
      rb.setRotation(Quaternion(0.2, 0.3, 0.1, 1.0));
      rb.setAngularVelocity(
        Vector3(_random.nextDouble() * 6 - 3, _random.nextDouble() * 6 - 3, _random.nextDouble() * 6 + 6),
      );
    }
  }

  void addTable(Vector3 pos) {
    // Tabletop: wide flat box
    const double topW = 1.6, topD = 0.9, topH = 0.08;
    const double legR = 0.07, legH = 0.6;
    const double legOffX = 0.65, legOffY = 0.35;

    final rb = physicsSystem.addBox(topW / 2, topH / 2, topD / 2, desc: M3RigidBodyDesc.dynamic()..position = pos);

    if (rb is M3RapierRigidBody) {
      // Four legs as cylinder colliders
      final legOffsets = [
        Vector3(-legOffX, -(topH / 2 + legH / 2), -legOffY),
        Vector3(legOffX, -(topH / 2 + legH / 2), -legOffY),
        Vector3(-legOffX, -(topH / 2 + legH / 2), legOffY),
        Vector3(legOffX, -(topH / 2 + legH / 2), legOffY),
      ];
      for (final offset in legOffsets) {
        world.createCollider(
          rb,
          ColliderDesc.cuboid(legR, legH / 2, legR)
            ..restitution = 0.3
            ..localPosition = offset,
        );
      }

      // ── Visual mesh ──────────────────────────────────────────────────────────
      M3Material mtrWood = M3Material()..diffuse = Vector4(0.76, 0.52, 0.24, 1.0); // warm wood
      final tableMesh = M3Mesh(M3BoxGeom(topW, topH, topD), material: mtrWood);
      for (final offset in legOffsets) {
        final legSub = M3SubMesh(M3BoxGeom(legR * 2, legH, legR * 2));
        legSub.localMatrix = Matrix4.compose(offset, Quaternion.identity(), Vector3.all(1.0));
        legSub.mtr.diffuse = Vector4(0.55, 0.35, 0.15, 1.0); // darker wood
        tableMesh.subMeshes.add(legSub);
      }

      final tableEntity = addMesh(tableMesh, pos);
      physicsSystem.attachEntity(tableEntity, rb);

      // Random tumble so tables fall chaotically
      rb.setRotation(
        Quaternion(
          _random.nextDouble() * 0.4 - 0.2,
          _random.nextDouble() * 0.4 - 0.2,
          _random.nextDouble() * 0.4 - 0.2,
          1.0,
        ),
      );
      rb.setAngularVelocity(
        Vector3(_random.nextDouble() * 4 - 2, _random.nextDouble() * 4 - 2, _random.nextDouble() * 3 + 2),
      );
    }
  }

  final posArray = [
    Vector3(2, 0, 8),
    Vector3(2, 2, 8),
    Vector3(0, 2, 8),
    Vector3(-2, 2, 8),
    Vector3(-2, 0, 8),
    Vector3(-2, -2, 8),
    Vector3(0, -2, 8),
    Vector3(2, -2, 8),
  ];
  @override
  void update(double delta) {
    // Alternate: even spawn → dumbbell, odd spawn → table
    if (_spawnedCount < _maxSpawned) {
      _spawnAccum += delta;
      while (_spawnAccum >= _spawnInterval && _spawnedCount < _maxSpawned) {
        if (_spawnedCount.isEven) {
          addDumbbell(posArray[_spawnedCount % posArray.length]);
        } else {
          addTable(posArray[_spawnedCount % posArray.length]);
        }
        _spawnedCount++;
        _spawnAccum -= _spawnInterval;
      }
    }
    super.update(delta);
  }
}
