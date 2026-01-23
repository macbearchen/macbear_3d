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

  // render up axis is always Z, physics up axis is Y or Z
  // if physicsUpAxis is Y, then rotate -90 degree on X-axis
  M3Axis physicsUpAxis = M3Axis.z;

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

      final matWorldMesh = matrix * mesh!.initMatrix;

      final v = Vector3.zero();
      for (int i = 0; i < 8; i++) {
        v.setValues(
          (i & 1) == 0 ? localAabb.min.x : localAabb.max.x,
          (i & 2) == 0 ? localAabb.min.y : localAabb.max.y,
          (i & 4) == 0 ? localAabb.min.z : localAabb.max.z,
        );
        matWorldMesh.transform3(v);
        worldAabb.hullPoint(v);
      }

      // If skin exists, also hull all bone world positions
      if (mesh!.skin != null) {
        for (int i = 0; i < mesh!.skin!.boneCount; i++) {
          final jointNode = mesh!.skin!.jointNodes![i];
          v.setFrom(jointNode.worldMatrix.getTranslation());
          matrix.transform3(v); // Bring joint world to entity world
          worldAabb.hullPoint(v);
        }
      }

      final worldPosition = localBounding.sphere.center.clone();
      matWorldMesh.transform3(worldPosition);
      worldBounding.sphere.center.setFrom(worldPosition);

      // radius: max scale * local radius
      final maxScale = max(_transform.scale.x, max(_transform.scale.y, _transform.scale.z));
      worldBounding.sphere.radius = localBounding.sphere.radius * maxScale;
      _boundsDirty = false;
    }
  }

  static final Quaternion _qRotX90 = Quaternion.fromRotation(M3Constants.rotXPos90);
  static final Quaternion _qRotXNeg90 = Quaternion.fromRotation(M3Constants.rotXNeg90);

  final Vector3 _prevPos = Vector3.zero();
  final Quaternion _prevRot = Quaternion.identity();

  void savePhysicsState() {
    if (rigidBody == null) return;
    _prevPos.setFrom(rigidBody!.position);
    _prevRot.setFrom(rigidBody!.orientation);
  }

  void syncFromPhysics() {
    if (rigidBody == null) return;

    final alpha = M3AppEngine.instance.physicsEngine.interpolationAlpha;
    final rbPos = rigidBody!.position;
    final rbRot = rigidBody!.orientation;

    // 1. Manual Lerp Position
    _transform.position.setValues(
      _prevPos.x + (rbPos.x - _prevPos.x) * alpha,
      _prevPos.y + (rbPos.y - _prevPos.y) * alpha,
      _prevPos.z + (rbPos.z - _prevPos.z) * alpha,
    );

    // 2. Manual Slerp Rotation
    double dot = _prevRot.x * rbRot.x + _prevRot.y * rbRot.y + _prevRot.z * rbRot.z + _prevRot.w * rbRot.w;

    final q2 = rbRot.clone();
    if (dot < 0.0) {
      q2.scale(-1.0);
      dot = -dot;
    }

    final lerpRot = Quaternion.identity();
    if (dot > 0.9995) {
      // NLerp
      lerpRot.setValues(
        _prevRot.x + (q2.x - _prevRot.x) * alpha,
        _prevRot.y + (q2.y - _prevRot.y) * alpha,
        _prevRot.z + (q2.z - _prevRot.z) * alpha,
        _prevRot.w + (q2.w - _prevRot.w) * alpha,
      );
    } else {
      double angle = acos(dot);
      double sinTotal = sin(angle);
      double ratioA = sin((1 - alpha) * angle) / sinTotal;
      double ratioB = sin(alpha * angle) / sinTotal;
      lerpRot.setValues(
        _prevRot.x * ratioA + q2.x * ratioB,
        _prevRot.y * ratioA + q2.y * ratioB,
        _prevRot.z * ratioA + q2.z * ratioB,
        _prevRot.w * ratioA + q2.w * ratioB,
      );
    }
    lerpRot.normalize();

    if (physicsUpAxis == M3Axis.y) {
      _transform.rotation = lerpRot * _qRotXNeg90;
    } else {
      _transform.rotation = lerpRot;
    }
    _transform.markDirty();
    _boundsDirty = true;
  }

  void syncToPhysics() {
    if (rigidBody == null) return;
    rigidBody!.position = _transform.position;
    if (physicsUpAxis == M3Axis.y) {
      rigidBody!.orientation = _transform.rotation * _qRotX90;
    } else {
      rigidBody!.orientation = _transform.rotation;
    }
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

  void update(double dt) {
    if (mesh == null) return;

    // 1. Update Animator
    if (mesh!.animator != null) {
      mesh!.animator!.update(dt);
      _boundsDirty = true; // Animation moves joints, dirty the bounds
    }

    // 2. Update Skin
    if (mesh!.skin != null) {
      // In the current architecture, M3Entity represents the local space
      // for the mesh. We pass Identity as the MeshWorldMatrix because the
      // entity's matrix is applied later in the shader.
      mesh!.skin!.update(null);
    }
  }

  Matrix4 get matrix => _transform.worldMatrix;
}
