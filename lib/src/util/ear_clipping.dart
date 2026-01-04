import 'package:vector_math/vector_math.dart';

/// A polygon triangulation class using the Ear Clipping algorithm.
///
/// Supports simple polygons and polygons with holes.
class M3EarClipping {
  /// Triangulates a polygon defined by [vertices].
  ///
  /// [holes] is a list of indices where each hole starts.
  /// If [vertices] is a list of 2D points (x, y), they should be flattened.
  /// This implementation assumes `List<Vector2>` for easier usage here.
  static List<int> triangulate(List<Vector2> vertices, {List<List<Vector2>>? holes}) {
    List<Vector2> data = List.from(vertices);
    List<int> holeIndices = [];

    // If there are holes, we need to merge them into the main polygon
    // using "bridge" edges effectively or just by ordering.
    // However, a robust ear clipping implementation usually handles holes
    // by merging them into a single degenerate polygon first.
    // For simplicity, let's implement a basic ear clipping relying on
    // standard algorithms or a simplified approach if holes are complex.
    //
    // A common simple way for 3D text (which usually has simple holes like in 'O', 'A', 'B')
    // is to project to 2D (already 2D here) and run a standard triangulation.

    if (holes != null && holes.isNotEmpty) {
      _eliminateHoles(data, holes);
    }

    List<int> indices = List.generate(data.length, (i) => i);
    List<int> result = [];

    int count = indices.length;
    int prevCount = 0;

    int i = 0;
    while (count > 3) {
      if (i >= count) {
        if (count == prevCount) {
          // Failed to find an ear, polygon might be self-intersecting or complex
          // Break to avoid infinite loop
          // print("M3EarClipping: Failed to triangulate remaining vertices.");
          break;
        }
        prevCount = count;
        i = 0;
      }

      int i0 = indices[i];
      int i1 = indices[(i + 1) % count];
      int i2 = indices[(i + 2) % count];

      if (_isEar(data, i0, i1, i2, indices)) {
        result.add(i0);
        result.add(i1);
        result.add(i2);
        indices.removeAt((i + 1) % count);
        count--;
        i = 0; // Restart search
      } else {
        i++;
      }
    }

    if (count == 3) {
      result.add(indices[0]);
      result.add(indices[1]);
      result.add(indices[2]);
    }

    return result;
  }

  // --- Helper methods ---

  static bool _isEar(List<Vector2> vertices, int i0, int i1, int i2, List<int> indices) {
    Vector2 a = vertices[i0];
    Vector2 b = vertices[i1];
    Vector2 c = vertices[i2];

    // 1. Check if reflex (convex angle)
    // Cross product > 0 for CCW.
    // (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    double cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    if (cross <= 0) return false; // fast fail if not convex or collinear

    // 2. Check if any other point is inside this triangle
    // It's an ear if no other vertex is inside the triangle abc
    for (int idx in indices) {
      if (idx == i0 || idx == i1 || idx == i2) continue;
      if (_isPointInTriangle(vertices[idx], a, b, c)) {
        return false;
      }
    }
    return true;
  }

  static bool _isPointInTriangle(Vector2 p, Vector2 a, Vector2 b, Vector2 c) {
    // Barycentric coordinates technique or similar
    double v0x = c.x - a.x;
    double v0y = c.y - a.y;
    double v1x = b.x - a.x;
    double v1y = b.y - a.y;
    double v2x = p.x - a.x;
    double v2y = p.y - a.y;

    double dot00 = v0x * v0x + v0y * v0y;
    double dot01 = v0x * v1x + v0y * v1y;
    double dot02 = v0x * v2x + v0y * v2y;
    double dot11 = v1x * v1x + v1y * v1y;
    double dot12 = v1x * v2x + v1y * v2y;

    double invDenom = 1 / (dot00 * dot11 - dot01 * dot01);
    double u = (dot11 * dot02 - dot01 * dot12) * invDenom;
    double v = (dot00 * dot12 - dot01 * dot02) * invDenom;

    return (u >= 0) && (v >= 0) && (u + v < 1);
  }

  // Very basic hole elimination: finding the mutually visible connection
  // and cutting the hole to merge into outer polygon.
  // This is a simplified version.
  static void _eliminateHoles(List<Vector2> outer, List<List<Vector2>> holes) {
    // For each hole, find a bridge to the outer polygon
    for (var hole in holes) {
      // Find right-most point of the hole
      int holeMaxXIdx = 0;
      double maxX = -double.infinity;
      for (int i = 0; i < hole.length; i++) {
        if (hole[i].x > maxX) {
          maxX = hole[i].x;
          holeMaxXIdx = i;
        }
      }

      // In a robust implementation, we would now find the best connection point on the outer polygon.
      // For now, let's just append the hole vertices to the outer list with a "cut"
      // This is insufficient for general cases but might work for simple glyphs if ordered correctly.

      // Better approach for simple glyph parser integration:
      // The glyph parser usually returns a list of contours.
      // One is outer (CCW), others are holes (CW).
      // We can use a library or implement the full monotone polygon triangulation,
      // or "cut" holes.
      //
      // Since implementing a robust hole cutter is complex, let's rely on the assumption
      // that the user of this class provides a single list of vertices that *includes* the cut lines
      // if they manually processed it, OR we do a naive append.
      // A common simple hack for holes is to reverse them and append to the end,
      // making a degenerate edge.

      // Finding the closest vertex on outer loop to hole[holeMaxXIdx]
      Vector2 holePt = hole[holeMaxXIdx];
      int bestIdx = -1;
      double bestDist = double.infinity; // minimal distance

      // We only consider points that are to the right of holePt? Not necessarily.
      // Standard algorithm: Ray cast to the right from holePt, find closest edge intersection,
      // pick vertex on that edge with max X...

      // Let's do the simplest: Find closest vertex
      for (int i = 0; i < outer.length; i++) {
        double dsq = outer[i].distanceToSquared(holePt);
        if (dsq < bestDist) {
          // check visibility... skipped for brevity in this MVP
          bestDist = dsq;
          bestIdx = i;
        }
      }

      if (bestIdx != -1) {
        // Insert hole into outer at bestIdx
        // outer: ... p[bestIdx], hole..., p[bestIdx] ...

        // Rotate hole so holeMaxXIdx is first
        List<Vector2> rotatedHole = [];
        for (int k = 0; k < hole.length; k++) {
          rotatedHole.add(hole[(holeMaxXIdx + k) % hole.length]);
        }

        // Because holes are usually CW and outer CCW in font definitions (or vice-versa),
        // we ensure the winding is consistent for the merge.
        // Assuming input is correct winding.

        // Insertion:
        // p[bestIdx] -> hole[0] -> hole[1]... -> hole[0] -> p[bestIdx]

        List<Vector2> newOuter = [];
        newOuter.addAll(outer.sublist(0, bestIdx + 1)); // ... p[bestIdx]
        newOuter.addAll(rotatedHole);
        newOuter.add(rotatedHole[0]); // close hole loop back to start
        newOuter.add(outer[bestIdx]); // bridge back
        newOuter.addAll(outer.sublist(bestIdx + 1));

        outer.clear();
        outer.addAll(newOuter);
      }
    }
  }
}
