import 'package:oimo_physics/oimo_physics.dart' as oimo;

// Macbear3D engine
import '../../macbear_3d.dart';
import 'transform.dart';

class M3Entity {
  final M3Transform _transform = M3Transform();
  oimo.RigidBody? rigidBody;
  M3Mesh? mesh;
  Vector4 color = Vector4(1.0, 1.0, 1.0, 1.0); // RGBA

  // visibility culling
  double radius = 1.0;

  void syncFromPhysics() {
    if (rigidBody == null) return;
    _transform.position = rigidBody!.position;
    _transform.rotation = rigidBody!.orientation;
    _transform.markDirty();
  }

  void syncToPhysics() {
    if (rigidBody == null) return;
    rigidBody!.position = _transform.position;
    rigidBody!.orientation = _transform.rotation;
  }

  // convenience getters/setters
  Vector3 get position => _transform.position;
  set position(Vector3 v) => _transform.position = v;

  Quaternion get rotation => _transform.rotation;
  set rotation(Quaternion q) => _transform.rotation = q;

  Vector3 get scale => _transform.scale;
  set scale(Vector3 v) => _transform.scale = v;

  Matrix4 get matrix => _transform.worldMatrix;
}
