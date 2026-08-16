import 'dart:typed_data';

/// ============================================================
/// M3TerrainLodConfig — LOD distance thresholds / segment count table / hysteresis settings
/// ============================================================
///
/// Distance progression: 64, 128, 256, 512 (m) — geometric x2
/// Segment progression: 32, 16, 8, 4 — matches tile 32x32 segments, minimum 4x4
///
/// Both lists must have the same length (lodCount). Index 0 = highest detail (closest).
class M3TerrainLodConfig {
  M3TerrainLodConfig._();

  /// Number of LOD levels (LOD0: 32x32, LOD1: 16x16, LOD2: 8x8, LOD3: 4x4).
  static const int lodCount = 4;

  /// Base distance (meters) for LOD 0 — the highest-detail level.
  /// The full threshold list is generated from this value using a
  /// geometric x2 progression: base, base*2, base*4, base*8, ...
  static const double baseDistance = 64.0;

  /// Segment count per tile for LOD 0 — the highest-detail level.
  static const int baseSegmentCount = 32;

  /// Segment count per tile for each LOD level (32, 16, 8, 4).
  /// Generated from [baseSegmentCount] with a geometric /2 progression:
  /// segmentCounts[i] = baseSegmentCount >> i
  static final List<int> segmentCounts = List.generate(lodCount, (i) {
    final count = baseSegmentCount >> i;
    assert(
      count >= 4,
      'baseSegmentCount ($baseSegmentCount) is too small for '
      'lodCount ($lodCount) — LOD $i segment count ($count) is less than 4.',
    );
    return count;
  });

  /// Trigger distance (meters) for each LOD level, index 0 = highest detail.
  /// Generated from [baseDistance] with a geometric x2 progression:
  /// distances[i] = baseDistance * 2^i
  /// distance < distances[0] -> LOD 0 (baseSegmentCount segments)
  /// distances[0] <= distance < distances[1] -> LOD 1 (baseSegmentCount/2 segments)
  /// ...
  static final List<double> distances = List.generate(lodCount, (i) => baseDistance * (1 << i));

  /// Hysteresis buffer ratio (±10% of the threshold value).
  /// The buffer width scales automatically with distance (the 320m band is
  /// wider than the 20m band), which matches the intuition that farther
  /// tiles are less sensitive to LOD switching — no extra constant table needed.
  static const double hysteresisRatio = 0.10;

  /// Squared distance thresholds (cached so we never redo the multiplication).
  /// All comparisons use distanceSquared — never take a sqrt on tile coordinates.
  static final List<double> distancesSquared = distances.map((d) => d * d).toList(growable: false);

  static int segmentCountForLod(int lod) {
    assert(lod >= 0 && lod < lodCount, 'LOD $lod out of range [0, $lodCount)');
    return segmentCounts[lod];
  }
}

/// ============================================================
/// M3TerrainLodResolver — pure logic layer: distance -> desired LOD -> LOD after hysteresis
/// No GL / renderer dependency, so it can be unit tested in isolation.
/// ============================================================
class M3TerrainLodResolver {
  /// Calculates the "ideal" LOD from squared distance (hysteresis not yet applied).
  static int calculateDesiredLod(double distanceSquared) {
    final thresholds = M3TerrainLodConfig.distancesSquared;
    for (var i = 0; i < thresholds.length; i++) {
      if (distanceSquared < thresholds[i]) {
        return i;
      }
    }
    // Beyond the last threshold — stay at the lowest detail level.
    return thresholds.length - 1;
  }

  /// Resolves the actual LOD after applying hysteresis.
  ///
  /// - currentLod < 0 means uninitialized: adopt desiredLod directly, no hysteresis.
  /// - Switching to lower detail (desired > current): use currentLod's threshold;
  ///   must exceed threshold + band before actually switching.
  /// - Switching to higher detail (desired < current): use desiredLod's threshold;
  ///   must drop below threshold - band before actually switching.
  static int resolveLod({required int currentLod, required double distanceSquared}) {
    final desired = calculateDesiredLod(distanceSquared);

    if (currentLod < 0) return desired;
    if (desired == currentLod) return currentLod;

    final thresholds = M3TerrainLodConfig.distancesSquared;

    if (desired > currentLod) {
      // Moving farther away — consider dropping to lower detail.
      final thresholdIndex = currentLod.clamp(0, thresholds.length - 1);
      final threshold = thresholds[thresholdIndex];
      final band = threshold * M3TerrainLodConfig.hysteresisRatio;
      if (distanceSquared < threshold + band) {
        return currentLod; // Still within the buffer band — don't switch.
      }
      return desired;
    } else {
      // Moving closer — consider switching to higher detail.
      final thresholdIndex = (currentLod - 1).clamp(0, thresholds.length - 1);
      final threshold = thresholds[thresholdIndex];
      final band = threshold * M3TerrainLodConfig.hysteresisRatio;
      if (distanceSquared > threshold - band) {
        return currentLod; // Still within the buffer band — don't switch.
      }
      return desired;
    }
  }
}

/// Helper class to generate stitched face (TRIANGLES) and wireframe (LINES) indices
/// for a tile of any LOD given the current LOD level and neighbor stitch flags.
///
/// Stitching responsibility belongs to the **lower-precision side**:
/// a tile stitches an edge only when its own LOD number is greater than the
/// neighbor's (self has fewer segments, i.e. lower precision).
///
/// LOD0 (32×32 segments, highest detail) never stitches and never calls this
/// builder with a non-zero mask — it always uses the plain uniform grid (mask = 0).
///
/// Neighbor bitmask (only meaningful for LOD1..3):
/// - Bit 0 (1): North neighbor is higher precision (self must stitch North edge)
/// - Bit 1 (2): East neighbor is higher precision (self must stitch East edge)
/// - Bit 2 (4): South neighbor is higher precision (self must stitch South edge)
/// - Bit 3 (8): West neighbor is higher precision (self must stitch West edge)
class M3TerrainStitchBuilder {
  static const int maskNorth = 1;
  static const int maskEast = 2;
  static const int maskSouth = 4;
  static const int maskWest = 8;

  /// Builds stitched face indices (GL_TRIANGLES) for a tile at [lod].
  ///
  /// The tile's own vertex grid is always 33×33 (row stride = 33).
  /// At LOD N the coarse step is `step = 1 << lod`, so the tile covers
  /// `gridSegs = 32 / step` logical segments.
  ///
  /// **Stitching direction (per spec)**: the *lower-precision* tile inserts
  /// extra boundary vertices to align with a *higher-precision* neighbour.
  /// Each stitched edge segment `vi → vi+1` gains a half-step mid-point
  /// `vi + step/2` (which exists in the shared 33×33 vertex buffer at the
  /// finer sampling position used by the higher-LOD neighbour).
  ///
  /// LOD0 is always called with [stitchMask] == 0 and produces a single
  /// uniform grid — no border-strip split, no half-step insertion.
  static Uint16List buildStitchedFaceIndices(int lod, int stitchMask) {
    assert(lod == 0 ? stitchMask == 0 : true, 'LOD0 must always have stitchMask == 0');

    final step = 1 << lod; // 1→LOD0(32×32), 2→LOD1(16×16), 4→LOD2(8×8), 8→LOD3(4×4)
    final half = step >> 1; // Half-step used for stitch mid-points (0 for LOD0)
    final gridSegs = 32 ~/ step; // Logical segments: 32, 16, 8, 4
    const rowStride = 33; // Tile vertex row stride is always 33

    final stitchN = (stitchMask & maskNorth) != 0;
    final stitchE = (stitchMask & maskEast) != 0;
    final stitchS = (stitchMask & maskSouth) != 0;
    final stitchW = (stitchMask & maskWest) != 0;

    final indices = <int>[];

    // Vertex index helpers
    // vCoarse(r, c): coarse grid vertex (0..gridSegs in each axis)
    int vCoarse(int r, int c) => r * step * rowStride + c * step;
    // vMidRow(r, c): half-step mid-point between vCoarse(r,c) and vCoarse(r,c+1) on the same row
    int vMidCol(int r, int c) => r * step * rowStride + c * step + half;
    // vMidCol(r, c): half-step mid-point between vCoarse(r,c) and vCoarse(r+1,c) on the same col
    int vMidRow(int r, int c) => r * step * rowStride + half * rowStride + c * step;

    // -------------------------------------------------------------------------
    // 1. Inner region: rows [1..gridSegs-2], cols [1..gridSegs-2]
    //    (border strip is handled separately below)
    // For LOD0 (no border strip), this covers the full [0..gridSegs-1] range.
    // -------------------------------------------------------------------------
    final rInnerStart = (stitchN || stitchS || stitchE || stitchW) ? 1 : 0;
    final rInnerEnd = gridSegs - rInnerStart;
    final cInnerStart = rInnerStart;
    final cInnerEnd = gridSegs - rInnerStart;

    for (int r = rInnerStart; r < rInnerEnd; r++) {
      for (int c = cInnerStart; c < cInnerEnd; c++) {
        final v00 = vCoarse(r, c);
        final v10 = vCoarse(r + 1, c);
        final v01 = vCoarse(r, c + 1);
        final v11 = vCoarse(r + 1, c + 1);
        indices.addAll([v00, v10, v01]);
        indices.addAll([v01, v10, v11]);
      }
    }

    if (rInnerStart == 0) {
      return Uint16List.fromList(indices);
    }
    // indices.clear(); // debug to hide inner

    // -------------------------------------------------------------------------
    // 2. North edge strip (r = 0, c in [1..gridSegs-2])
    //    Middle N-2 segments only; excludes corners at c=0 and c=gridSegs-1.
    // -------------------------------------------------------------------------
    for (int c = 1; c < gridSegs - 1; c++) {
      final vI0 = vCoarse(1, c);
      final vI1 = vCoarse(1, c + 1);
      final vE0 = vCoarse(0, c);
      final vE1 = vCoarse(0, c + 1);

      if (!stitchN) {
        indices.addAll([vE0, vI0, vE1]);
        indices.addAll([vE1, vI0, vI1]);
      } else {
        final vM = vMidCol(0, c);
        indices.addAll([vE0, vI0, vM]);
        indices.addAll([vM, vI0, vI1]);
        indices.addAll([vM, vI1, vE1]);
      }
    }

    // -------------------------------------------------------------------------
    // 3. South edge strip (r = gridSegs, c in [1..gridSegs-2])
    //    Middle N-2 segments only; excludes corners at c=0 and c=gridSegs-1.
    // -------------------------------------------------------------------------
    for (int c = 1; c < gridSegs - 1; c++) {
      final vI0 = vCoarse(gridSegs - 1, c);
      final vI1 = vCoarse(gridSegs - 1, c + 1);
      final vE0 = vCoarse(gridSegs, c);
      final vE1 = vCoarse(gridSegs, c + 1);

      if (!stitchS) {
        indices.addAll([vI0, vE0, vI1]);
        indices.addAll([vI1, vE0, vE1]);
      } else {
        final vM = vMidCol(gridSegs, c);
        indices.addAll([vI0, vE0, vM]);
        indices.addAll([vI0, vM, vI1]);
        indices.addAll([vI1, vM, vE1]);
      }
    }

    // -------------------------------------------------------------------------
    // 4. West edge strip (c = 0, r in [1..gridSegs-2])
    //    Middle N-2 segments only; excludes corners at r=0 and r=gridSegs-1.
    // -------------------------------------------------------------------------
    for (int r = 1; r < gridSegs - 1; r++) {
      final vI0 = vCoarse(r, 1);
      final vI1 = vCoarse(r + 1, 1);
      final vE0 = vCoarse(r, 0);
      final vE1 = vCoarse(r + 1, 0);

      if (!stitchW) {
        indices.addAll([vE0, vE1, vI0]);
        indices.addAll([vI0, vE1, vI1]);
      } else {
        final vM = vMidRow(r, 0);
        indices.addAll([vE0, vM, vI0]);
        indices.addAll([vM, vI1, vI0]);
        indices.addAll([vM, vE1, vI1]);
      }
    }

    // -------------------------------------------------------------------------
    // 5. East edge strip (c = gridSegs, r in [1..gridSegs-2])
    //    Middle N-2 segments only; excludes corners at r=0 and r=gridSegs-1.
    // -------------------------------------------------------------------------
    for (int r = 1; r < gridSegs - 1; r++) {
      final vI0 = vCoarse(r, gridSegs - 1);
      final vI1 = vCoarse(r + 1, gridSegs - 1);
      final vE0 = vCoarse(r, gridSegs);
      final vE1 = vCoarse(r + 1, gridSegs);

      if (!stitchE) {
        indices.addAll([vI0, vI1, vE0]);
        indices.addAll([vE0, vI1, vE1]);
      } else {
        final vM = vMidRow(r, gridSegs);
        indices.addAll([vI0, vI1, vM]);
        indices.addAll([vE0, vI0, vM]);
        indices.addAll([vI1, vE1, vM]);
      }
    }
    // indices.clear(); // debug to hide edges

    // -------------------------------------------------------------------------
    // 6. Corners — Exclusively handles the 2×2 vertex block at each corner per diagram
    // -------------------------------------------------------------------------
    // NW Corner: rows 0-1, cols 0-1 (c00=top-left outer corner, c11=bottom-right inner corner)
    {
      final c00 = vCoarse(0, 0); // outer corner (0,0)
      final c01 = vCoarse(0, 1); // (0,1)
      final c10 = vCoarse(1, 0); // (1,0)
      final c11 = vCoarse(1, 1); // inner corner (1,1)
      final mN = vMidCol(0, 0); // mid-point on North edge
      final mW = vMidRow(0, 0); // mid-point on West edge

      if (!stitchN && !stitchW) {
        indices.addAll([c00, c10, c01]);
        indices.addAll([c01, c10, c11]);
      } else if (stitchN && !stitchW) {
        // 1-stitch North (same as North edge strip): vE0=c00, vE1=c01, vI0=c10, vI1=c11, vM=mN
        indices.addAll([c00, c10, mN]);
        indices.addAll([mN, c10, c11]);
        indices.addAll([mN, c11, c01]);
      } else if (!stitchN && stitchW) {
        // 1-stitch West (same as West edge strip): vE0=c00, vE1=c10, vI0=c01, vI1=c11, vM=mW
        indices.addAll([c00, mW, c01]);
        indices.addAll([mW, c11, c01]);
        indices.addAll([mW, c10, c11]);
      } else {
        // 2-stitch: c00->c11 diagonal line, c11 connects to mN and mW, triangle (c11, mW, mN)
        indices.addAll([c00, mW, mN]);
        indices.addAll([mN, mW, c11]);
        indices.addAll([mN, c11, c01]);
        indices.addAll([mW, c10, c11]);
      }
    }

    // NE Corner: rows 0-1, cols (gridSegs-1..gridSegs) (c01=top-right outer corner, c10=bottom-left inner corner)
    {
      final g = gridSegs;
      final c00 = vCoarse(0, g - 1); // (0, g-1)
      final c01 = vCoarse(0, g); // outer corner (0, g)
      final c10 = vCoarse(1, g - 1); // inner corner (1, g-1)
      final c11 = vCoarse(1, g); // (1, g)
      final mN = vMidCol(0, g - 1); // mid-point on North edge
      final mE = vMidRow(0, g); // mid-point on East edge

      if (!stitchN && !stitchE) {
        indices.addAll([c00, c10, c01]);
        indices.addAll([c01, c10, c11]);
      } else if (stitchN && !stitchE) {
        // 1-stitch North: vE0=c00, vE1=c01, vI0=c10, vI1=c11, vM=mN
        indices.addAll([c00, c10, mN]);
        indices.addAll([mN, c10, c11]);
        indices.addAll([mN, c11, c01]);
      } else if (!stitchN && stitchE) {
        // 1-stitch East: vE0=c01, vE1=c11, vI0=c00, vI1=c10, vM=mE
        indices.addAll([c00, c10, mE]);
        indices.addAll([c01, c00, mE]);
        indices.addAll([c10, c11, mE]);
      } else {
        // 2-stitch
        indices.addAll([c01, mN, mE]);
        indices.addAll([mN, c10, mE]);
        indices.addAll([mN, c00, c10]);
        indices.addAll([mE, c10, c11]);
      }
    }

    // SW Corner: rows (gridSegs-1..gridSegs), cols 0-1 (c10=bottom-left outer corner, c01=top-right inner corner)
    {
      final g = gridSegs;
      final c00 = vCoarse(g - 1, 0); // (g-1, 0)
      final c01 = vCoarse(g - 1, 1); // inner corner (g-1, 1)
      final c10 = vCoarse(g, 0); // outer corner (g, 0)
      final c11 = vCoarse(g, 1); // (g, 1)
      final mS = vMidCol(g, 0); // mid-point on South edge
      final mW = vMidRow(g - 1, 0); // mid-point on West edge

      if (!stitchS && !stitchW) {
        indices.addAll([c00, c10, c01]);
        indices.addAll([c01, c10, c11]);
      } else if (stitchS && !stitchW) {
        // 1-stitch South: vE0=c10, vE1=c11, vI0=c00, vI1=c01, vM=mS
        indices.addAll([c00, c10, mS]);
        indices.addAll([c00, mS, c01]);
        indices.addAll([c01, mS, c11]);
      } else if (!stitchS && stitchW) {
        // 1-stitch West: vE0=c00, vE1=c10, vI0=c01, vI1=c11, vM=mW
        indices.addAll([c00, mW, c01]);
        indices.addAll([mW, c11, c01]);
        indices.addAll([mW, c10, c11]);
      } else {
        // 2-stitch: mirror of NW (vertically reflected → winding reversed)
        // NW: [c00,mW,mN], [mN,mW,c11], [mN,c11,c01], [mW,c10,c11]
        indices.addAll([mS, mW, c10]); // outer triangle
        indices.addAll([c01, mW, mS]); // center
        indices.addAll([c11, c01, mS]); // S arm
        indices.addAll([c01, c00, mW]); // W arm
      }
    }

    // SE Corner: rows (gridSegs-1..gridSegs), cols (gridSegs-1..gridSegs) (c11=bottom-right outer corner, c00=top-left inner corner)
    {
      final g = gridSegs;
      final c00 = vCoarse(g - 1, g - 1); // inner corner (g-1, g-1)
      final c01 = vCoarse(g - 1, g); // (g-1, g)
      final c10 = vCoarse(g, g - 1); // (g, g-1)
      final c11 = vCoarse(g, g); // outer corner (g, g)
      final mS = vMidCol(g, g - 1); // mid-point on South edge
      final mE = vMidRow(g - 1, g); // mid-point on East edge

      if (!stitchS && !stitchE) {
        indices.addAll([c00, c10, c01]);
        indices.addAll([c01, c10, c11]);
      } else if (stitchS && !stitchE) {
        // 1-stitch South: vE0=c10, vE1=c11, vI0=c00, vI1=c01, vM=mS
        indices.addAll([c00, c10, mS]);
        indices.addAll([c00, mS, c01]);
        indices.addAll([c01, mS, c11]);
      } else if (!stitchS && stitchE) {
        // 1-stitch East: vE0=c01, vE1=c11, vI0=c00, vI1=c10, vM=mE
        indices.addAll([c00, c10, mE]);
        indices.addAll([c01, c00, mE]);
        indices.addAll([c10, c11, mE]);
      } else {
        // 2-stitch: mirror of NE (vertically reflected → winding reversed)
        // NE: [c01,mN,mE], [mN,c10,mE], [mN,c00,c10], [mE,c10,c11]
        indices.addAll([mE, mS, c11]); // outer triangle
        indices.addAll([mE, c00, mS]); // center
        indices.addAll([c00, c10, mS]); // S arm
        indices.addAll([c01, c00, mE]); // E arm
      }
    }

    return Uint16List.fromList(indices);
  }

  /// Builds wireframe line indices for a tile at [lod] with the given [stitchMask].
  ///
  /// Extracts all unique triangle edges from [buildStitchedFaceIndices] to ensure
  /// all quad edges, diagonals, and stitched boundary fan edges are drawn without
  /// duplicate lines for shared edges.
  static Uint16List buildStitchedWireIndices(int lod, int stitchMask) {
    final faces = buildStitchedFaceIndices(lod, stitchMask);
    final edgeSet = <int>{};
    final lines = <int>[];

    for (int i = 0; i < faces.length; i += 3) {
      final v0 = faces[i];
      final v1 = faces[i + 1];
      final v2 = faces[i + 2];

      void addEdge(int a, int b) {
        final key = a < b ? (a << 16) | b : (b << 16) | a;
        if (edgeSet.add(key)) {
          lines.add(a);
          lines.add(b);
        }
      }

      addEdge(v0, v1);
      addEdge(v1, v2);
      addEdge(v2, v0);
    }

    return Uint16List.fromList(lines);
  }
}
