// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:macbear_3d/macbear_3d.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('M3Node', () {
    test('local to world matrix recomputation', () {
      final transform = M3Node();
      transform.position = Vector3(1, 2, 3);

      final mat = transform.worldMatrix;
      expect(mat.getTranslation(), Vector3(1, 2, 3));
      expect(transform.isDirty, isFalse);
    });

    test('hierarchical dirty propagation', () {
      final parent = M3Node();
      final child = M3Node();
      child.parent = parent;
      parent.children.add(child);

      // Initially both might be dirty
      expect(parent.isDirty, isTrue);
      expect(child.isDirty, isTrue);

      // Access parent to clear its dirty flag
      parent.worldMatrix;
      expect(parent.isDirty, isFalse);
      expect(child.isDirty, isTrue);

      // Access child to clear its dirty flag
      child.worldMatrix;
      expect(child.isDirty, isFalse);

      // Mark parent dirty, child should also become dirty
      parent.markDirty();
      expect(parent.isDirty, isTrue);
      expect(child.isDirty, isTrue);
    });
  });

  group('M3Entity Bounds', () {
    test('dirty transform triggers bounds update', () {
      final geom = M3BoxGeom(1, 1, 1);
      final mesh = M3Mesh(geom);
      final entity = M3Entity(mesh: mesh);

      // Initial update
      entity.updateBounds();
      expect(entity.worldBounding.aabb.center, Vector3.zero());

      // Change position - entity position setter marks _boundsDirty = true
      entity.position = Vector3(10, 0, 0);
      entity.updateBounds();
      expect(entity.worldBounding.aabb.center, Vector3(10, 0, 0));

      // Change position via transform directly (simulating hierarchical change)
      final parent = M3Node();
      entity.parent = parent;
      parent.children.add(entity);

      parent.position = Vector3(5, 5, 5);
      entity.updateBounds();
      // center should be (10+5, 0+5, 0+5) = (15, 5, 5)
      expect(entity.worldBounding.aabb.center, Vector3(15, 5, 5));
    });
  });
}
