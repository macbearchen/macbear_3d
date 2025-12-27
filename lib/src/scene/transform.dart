import 'package:vector_math/vector_math.dart';

class M3Transform {
  Vector3 position = Vector3.zero();
  Quaternion rotation = Quaternion.identity();
  Vector3 scale = Vector3.all(1);

  M3Transform? parent;
  final List<M3Transform> children = [];

  bool _dirty = true;
  Matrix4 _worldMatrix = Matrix4.identity();

  void markDirty() {
    _dirty = true;
    for (final c in children) {
      c.markDirty();
    }
  }

  Matrix4 get worldMatrix {
    if (_dirty) {
      _rebuild();
    }
    return _worldMatrix;
  }

  void _rebuild() {
    final local = Matrix4.compose(position, rotation, scale);
    _worldMatrix = parent != null ? parent!.worldMatrix * local : local;
    _dirty = false;
  }
}
