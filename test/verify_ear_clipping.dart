// ignore_for_file: avoid_print, avoid_relative_lib_imports

import 'package:vector_math/vector_math.dart';
import '../lib/src/geom/text/ear_clipping.dart';

void main() {
  // Define a square (CCW)
  List<Vector2> outer = [Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)];

  // Define a second hole square (CW)
  List<Vector2> hole2 = [Vector2(2, 5), Vector2(2, 7), Vector2(4, 7), Vector2(4, 5)];

  // Update first hole to be in a different position
  List<Vector2> hole1 = [Vector2(6, 5), Vector2(6, 7), Vector2(8, 7), Vector2(8, 5)];

  print("Testing triangulation with two holes...");
  var result = M3EarClipping.triangulate(outer, holes: [hole1, hole2]);

  print("Original outer vertices: ${outer.length}");
  print("Hole 1 vertices: ${hole1.length}");
  print("Hole 2 vertices: ${hole2.length}");
  print("Processed vertices: ${result.vertices.length}");
  print("Indices count: ${result.indices.length}");

  // Check if indices are within range
  int maxIndex = -1;
  for (var idx in result.indices) {
    if (idx > maxIndex) maxIndex = idx;
  }

  print("Max index referenced: $maxIndex");

  if (result.indices.isEmpty) {
    print("FAILURE: No triangles generated!");
  } else if (maxIndex < result.vertices.length) {
    print("SUCCESS: All indices are within valid vertex range.");
  } else {
    print("FAILURE: Index $maxIndex is out of range (vertices count: ${result.vertices.length})");
  }

  // With bridge edges, we expect:
  // outer (4) + hole (4) + bridge back (1) + bridge to hole (1) ?
  // Let's see the logic in _eliminateHoles:
  // newOuter.addAll(outer.sublist(0, bestIdx + 1)); // ... p[bestIdx] (1 to bestIdx+1)
  // newOuter.addAll(rotatedHole); // 4
  // newOuter.add(rotatedHole[0]); // 1 (close hole)
  // newOuter.add(outer[bestIdx]); // 1 (bridge back)
  // newOuter.addAll(outer.sublist(bestIdx + 1));

  // Total should be around 4 + 4 + 2 = 10?
}
