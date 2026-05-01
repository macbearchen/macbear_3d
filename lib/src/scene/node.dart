import 'package:vector_math/vector_math.dart';
import 'transform.dart';

/// A hierarchical node with parent/child relationships.
///
/// Lazily recomputes the world matrix when marked dirty.
class M3Node {
  M3Transform transform = M3Transform();

  Vector3 get position => transform.position;
  set position(Vector3 v) {
    transform.position = v;
    markDirty();
  }

  Quaternion get rotation => transform.rotation;
  set rotation(Quaternion q) {
    transform.rotation = q;
    markDirty();
  }

  Vector3 get scale => transform.scale;
  set scale(Vector3 v) {
    transform.scale = v;
    markDirty();
  }

  M3Node? _parent;
  M3Node? get parent => _parent;
  set parent(M3Node? p) {
    if (_parent == p) return;
    _parent?.children.remove(this);
    _parent = p;
    _parent?.children.add(this);
    markDirty();
  }

  final List<M3Node> children = [];

  bool _dirty = true;
  bool get isDirty => _dirty;

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
    final local = transform.matrix;
    _worldMatrix = parent != null ? parent!.worldMatrix * local : local;
    _dirty = false;
  }
}
