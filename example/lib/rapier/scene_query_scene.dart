// ignore_for_file: unused_local_variable, unused_field
import 'dart:math' as math;

import 'base_scene.dart';

/// Demo scene showcasing Scene Query features:
/// - Raycasting (`castRayAndGetNormal`)
/// - Shape sweeping (`castShape`)
/// - Point projection (`projectPoint`)
/// - Point intersection test (`intersectionsWithPoint`)
/// - Shape intersection test (`intersectionWithShape`)
class SceneQueryScene extends BaseScene {
  late M3Entity _pointerEntity;
  late M3Entity _rayHitEntity;
  late M3Entity _sweepEntity;
  late M3Entity _shapeIntersectEntity;
  final rayOrigin = Vector3(0, 0, 3);
  final sweepOrigin = Vector3(-1, -1, 1.4);
  final M3LineGeom _line = M3LineGeom(Vector3(0, 0, 0), Vector3(1, 1, 1));
  final M3LineGeom _sweepLine = M3LineGeom(Vector3(0, 0, 0), Vector3(1, 1, 1));

  // Query state results
  String _raycastInfo = 'Raycast: None';
  String _pointProjInfo = 'Project Point: None';
  String _pointIntersectInfo = 'Point Intersect: None';
  String _shapeSweepInfo = 'Shape Sweep: None';
  String _shapeIntersectInfo = 'Shape Intersect: None';

  double _queryAngle = 0.0;

  SceneQueryScene({required super.physics});

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    M3AppEngine.backgroundColor = Vector3(0.05, 0.08, 0.12);
    camera.setEuler(math.pi / 6, -math.pi / 4, 0, distance: 22);

    _buildObjects();

    // Visual indicators for query points
    _pointerEntity = addMesh(M3Mesh(M3SphereGeom(0.2)), Vector3(0, 0, 2))..color = Colors.green;
    _rayHitEntity = addMesh(M3Mesh(M3SphereGeom(0.12)), Vector3(0, 0, 0))..color = Colors.red;
    _sweepEntity = addMesh(M3Mesh(M3SphereGeom(0.5)), sweepOrigin)..color = Colors.cyan;
    _shapeIntersectEntity = addMesh(M3Mesh(M3SphereGeom(1.2)), Vector3(0, -4, 2))..color = Colors.magenta;

    // Dynamic green sphere at (-3, -3, 8.0) — radius 0.8 for both physics & mesh
    final radius = 2.0;
    final pos2 = Vector3(-3, 3, 8.0);
    final rb = physicsSystem.addSphere(radius, desc: M3RigidBodyDesc.dynamic()..position = pos2);
    final entity = addMesh(M3Mesh(M3SphereGeom(radius)), pos2)..color = Colors.lime;
    physicsSystem.attachEntity(entity, rb);

    // axis gizmo
    addMesh(M3Resources.axisGizmoMesh, Vector3(0, 0, 0));
  }

  void _buildObjects() {
    // Fixed orange box at (3, 2, 0.5) — half-extents 0.5 → 1×1×1 visual
    final pos1 = Vector3(3, 2, 0.5);
    final rb1 = physicsSystem.addBox(0.5, 0.5, 0.5, desc: M3RigidBodyDesc.fixed()..position = pos1);
    final entity1 = addMesh(M3Mesh(M3Resources.unitCube), pos1)..color = Colors.orange;
    physicsSystem.attachEntity(entity1, rb1);

    // Fixed purple box at (0, -4, 1) — half-extents 1 → 2×2×2 visual
    final pos3 = Vector3(0, -4, 1);
    final rb3 = physicsSystem.addBox(1, 1, 1, desc: M3RigidBodyDesc.fixed()..position = pos3);
    final entity3 = addMesh(M3Mesh(M3BoxGeom(2, 2, 2)), pos3)..color = Colors.purple;
    physicsSystem.attachEntity(entity3, rb3);
  }

  @override
  void update(double delta) {
    super.update(delta);

    _queryAngle += delta;

    // 1. Raycast with normal
    final rayAngle = _queryAngle / 2;
    final rayDir = Vector3(math.cos(rayAngle), math.sin(rayAngle), -0.6).normalized();
    final rayHit = world.castRayAndGetNormal(rayOrigin, rayDir, maxToi: 15.0);
    if (rayHit != null) {
      _rayHitEntity.position = rayHit.point;
      _raycastInfo =
          'Raycast: Hit TOI=${rayHit.toi.toStringAsFixed(2)}, Pt=(${rayHit.point.x.toStringAsFixed(1)}, ${rayHit.point.y.toStringAsFixed(1)}, ${rayHit.point.z.toStringAsFixed(1)})';
    } else {
      _raycastInfo = 'Raycast: Miss';
      _rayHitEntity.position = rayOrigin + rayDir * 5.0;
    }

    // 2. Project Point
    final testPt = Vector3(3.2 + math.sin(_queryAngle * 2) * 2, 2.1, 0.6);
    _pointerEntity.position = testPt;

    final proj = world.projectPoint(testPt);
    if (proj != null) {
      final isInside = proj.isInside;
      _pointerEntity.color = isInside ? Colors.red : Colors.green;
      _pointProjInfo = 'Project Point: Dist=${(proj.point - testPt).length.toStringAsFixed(2)}, Inside=$isInside';
    } else {
      _pointerEntity.color = Colors.gray;
      _pointProjInfo = 'Project Point: None';
    }
    _pointerEntity.color.a = 0.5;

    // 3. Point Intersections
    final ptColliders = world.intersectionsWithPoint(testPt);
    _pointIntersectInfo = 'Point Intersect: ${ptColliders.length} colliders';

    // 4. Shape Sweep (Cast Sphere)
    final sweepAngle = _queryAngle * -0.6;
    final sweepDir = Vector3(math.cos(sweepAngle), math.sin(sweepAngle), 0.0);
    final sweepVel = sweepDir * 8.0;
    final sweepHit = world.castShape(sweepOrigin, Quaternion.identity(), sweepVel, ColliderDesc.ball(0.5), maxToi: 1.0);
    if (sweepHit != null) {
      _sweepEntity.position = sweepOrigin + sweepVel * sweepHit.toi;
      _shapeSweepInfo = 'Shape Sweep: Hit TOI=${sweepHit.toi.toStringAsFixed(2)}';
    } else {
      _sweepEntity.position = sweepOrigin + sweepVel;
      _shapeSweepInfo = 'Shape Sweep: No collision';
    }

    // 5. Shape Intersection Test
    final shapePos = Vector3(math.sin(_queryAngle * 1.5) * 5, -4, 2.0);
    _shapeIntersectEntity.position = shapePos;
    final isIntersect = world.intersectionWithShape(shapePos, Quaternion.identity(), ColliderDesc.ball(1.2));
    if (isIntersect != null) {
      _shapeIntersectEntity.color = Colors.red;
      _shapeIntersectInfo = 'Shape Intersect: Hit Target';
    } else {
      _shapeIntersectEntity.color = Colors.gray;
      _shapeIntersectInfo = 'Shape Intersect: None';
    }
    _shapeIntersectEntity.color.a = 0.5;
  }

  @override
  void render2D() {
    super.render2D();

    Matrix4 mat2D = Matrix4.translation(Vector3(10.0, 40.0, 0.0));
    mat2D.scaleByVector3(Vector3.all(0.45));
    String queryInfo = '$_raycastInfo\n';
    queryInfo += '$_pointProjInfo\n';
    queryInfo += '$_pointIntersectInfo\n';
    queryInfo += '$_shapeSweepInfo\n';
    queryInfo += _shapeIntersectInfo;
    M3Resources.text2D.drawText(queryInfo, mat2D);
  }

  @override
  void drawHelper(M3HelperType helperType) {
    super.drawHelper(helperType);

    // draw line
    M3Material mtr = M3Material();

    final prog = M3Resources.programSimple!;
    prog.setMatrices(camera, Matrix4.identity());
    prog.setMaterial(mtr, Colors.yellow);

    final rayHit = _rayHitEntity.position;
    _line.drawLine(prog, rayOrigin, rayHit);

    // Draw sweep trajectory line in cyan
    prog.setMaterial(mtr, Colors.cyan);
    _sweepLine.drawLine(prog, sweepOrigin, _sweepEntity.position);
  }
}
