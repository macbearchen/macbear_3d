import 'package:oimo_physics/oimo_physics.dart' as oimo;

// Macbear3D engine
import '../../macbear_3d.dart';
import 'transform.dart';

/// A scene entity representing a renderable object with transform and physics.
///
/// Combines a mesh, transform, color, and optional rigid body for physics simulation.
class M3Entity {
  final M3Transform _transform = M3Transform();
  oimo.RigidBody? rigidBody;
  M3Mesh? mesh;
  Vector4 color = Vector4(1.0, 1.0, 1.0, 1.0); // RGBA

  // visibility culling
  M3Bounding worldBounding = M3Bounding();
  bool _boundsDirty = true;

  void updateBounds() {
    if (_boundsDirty && mesh != null) {
      final localBounding = mesh!.geom.localBounding;
      final localAabb = localBounding.aabb;
      final worldAabb = worldBounding.aabb;

      // Transform 8 corners of local AABB to world space
      worldAabb.min.setValues(double.infinity, double.infinity, double.infinity);
      worldAabb.max.setValues(double.negativeInfinity, double.negativeInfinity, double.negativeInfinity);

      final v = Vector3.zero();
      for (int i = 0; i < 8; i++) {
        v.setValues(
          (i & 1) == 0 ? localAabb.min.x : localAabb.max.x,
          (i & 2) == 0 ? localAabb.min.y : localAabb.max.y,
          (i & 4) == 0 ? localAabb.min.z : localAabb.max.z,
        );
        matrix.transform3(v);
        worldAabb.hullPoint(v);
      }

      final maxScale = max(_transform.scale.x, max(_transform.scale.y, _transform.scale.z));
      final worldPosition = localBounding.sphere.center.clone();
      matrix.transform3(worldPosition);
      worldBounding.sphere.center.setFrom(worldPosition);
      worldBounding.sphere.radius = localBounding.sphere.radius * maxScale;
      _boundsDirty = false;
    }
  }

  void syncFromPhysics() {
    if (rigidBody == null) return;
    _transform.position = rigidBody!.position;
    _transform.rotation = rigidBody!.orientation;
    _transform.markDirty();
    _boundsDirty = true;
  }

  void syncToPhysics() {
    if (rigidBody == null) return;
    rigidBody!.position = _transform.position;
    rigidBody!.orientation = _transform.rotation;
  }

  // convenience getters/setters
  Vector3 get position => _transform.position;
  set position(Vector3 v) {
    _transform.position = v;
    _transform.markDirty();
    _boundsDirty = true;
  }

  Quaternion get rotation => _transform.rotation;
  set rotation(Quaternion q) {
    _transform.rotation = q;
    _transform.markDirty();
    _boundsDirty = true;
  }

  Vector3 get scale => _transform.scale;
  set scale(Vector3 v) {
    _transform.scale = v;
    _transform.markDirty();
    _boundsDirty = true;
  }

  Matrix4 get matrix => _transform.worldMatrix;
}
