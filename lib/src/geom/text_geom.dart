part of 'geom.dart';

class M3TextGeom extends M3Geom {
  M3TrueTypeParser? _fontParser;

  M3TextGeom() {
    name = "TextGeom";
  }

  Future<void> loadTtf(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    _fontParser = M3TrueTypeParser(bytes);
  }

  /// Builds the 3D text geometry.
  ///
  /// [text] is the string to render.
  /// [size] is the font size (scale factor).
  /// [depth] is the extrusion depth.
  Future<void> build(String text, {double size = 1.0, double depth = 0.2}) async {
    if (_fontParser == null) {
      throw Exception("Font not loaded. Call loadTtf() first.");
    }

    List<Vector3> allVertices = [];
    List<Vector3> allNormals = [];
    List<int> triIndices = []; // triangles
    List<int> lineIndices = []; // lines

    double cursorX = 0.0;

    for (int i = 0; i < text.length; i++) {
      int charCode = text.codeUnitAt(i);

      if (charCode == 32) {
        // Space
        // we need advance width logic
        int glyphIndex = _fontParser!.getGlyphIndex(charCode);
        cursorX += _fontParser!.getAdvanceWidth(glyphIndex) * size;
        continue;
      }

      int glyphIndex = _fontParser!.getGlyphIndex(charCode);

      // Get contours
      List<List<Vector2>> contours = _fontParser!.getGlyphContours(glyphIndex);
      if (contours.isEmpty) {
        cursorX += _fontParser!.getAdvanceWidth(glyphIndex) * size;
        continue;
      }

      // Identify holes vs outer.
      // M3TrueTypeParser returns raw contours.
      // Simple logic: Assume first is outer, rest are holes (this is often true for simple glyphs, but TTF spec says orientation determines it)
      // For this MVP, let's treat the largest contour as outer? Or just pass all to ear clipping if we had robust boolean ops.
      // But M3EarClipping expects outer + list of holes.

      // Let's assume contour[0] is outer.
      List<Vector2> outer = contours[0];
      List<List<Vector2>> holes = (contours.length > 1) ? contours.sublist(1) : [];

      // Triangulate Face (Front)
      // Vertices need to be scaled and offset by cursorX

      // Flatten for local processing indices
      List<Vector2> combinedPoly = [];
      combinedPoly.addAll(outer);
      for (var h in holes) {
        combinedPoly.addAll(h);
      }

      // Triangulate
      // Note: EarClipping merges holes into outer, so it returns indices relative to the merged polygon?
      // My EarClipping implementation currently MODIFIES the outer list if holes exist.
      // So let's pass copies.

      List<Vector2> triangulationInput = List.from(outer);
      List<List<Vector2>> triangulationHoles = holes.map((e) => List<Vector2>.from(e)).toList();

      List<int> localIndices = M3EarClipping.triangulate(triangulationInput, holes: triangulationHoles);

      // The triangulationInput now contains ALL vertices (including holes merged).
      // We use THIS as the source for mesh vertices.

      int indexOffset = allVertices.length;

      // Add Front Face Vertices
      for (var v in triangulationInput) {
        allVertices.add(Vector3(cursorX + v.x * size, v.y * size, depth / 2));
        allNormals.add(Vector3(0, 0, 1)); // Front normal
      }

      // Add Front Face Indices
      for (var idx in localIndices) {
        // allIndices.add(indexOffset + idx);
      }

      // Add Back Face
      // Back face is same vertices but z = -depth/2 and normal = -1
      // And winding order reversed
      int backIndexOffset = allVertices.length;
      for (var v in triangulationInput) {
        allVertices.add(Vector3(cursorX + v.x * size, v.y * size, -depth / 2));
        allNormals.add(Vector3(0, 0, -1)); // Back normal
      }

      // Add Back Face Indices (reverse winding)
      for (int k = 0; k < localIndices.length; k += 3) {
        // allIndices.add(backIndexOffset + localIndices[k]);
        // allIndices.add(backIndexOffset + localIndices[k + 2]);
        // allIndices.add(backIndexOffset + localIndices[k + 1]);
      }

      // Extrusion (Sides)
      // We need to stitch edges of the original contours (outer + holes)
      // Since triangulation merged them, iterating triangulationInput edges is tricky because of bridge edges.
      // Ideally we iterate the Original Contours.

      List<List<Vector2>> allContoursToExtrude = [outer, ...holes];

      for (var contour in allContoursToExtrude) {
        for (int k = 0; k < contour.length; k++) {
          Vector2 curr = contour[k];
          Vector2 next = contour[(k + 1) % contour.length];

          Vector3 p1 = Vector3(cursorX + curr.x * size, curr.y * size, depth / 2); // Front curr
          Vector3 p2 = Vector3(cursorX + next.x * size, next.y * size, depth / 2); // Front next
          Vector3 p3 = Vector3(cursorX + next.x * size, next.y * size, -depth / 2); // Back next
          Vector3 p4 = Vector3(cursorX + curr.x * size, curr.y * size, -depth / 2); // Back curr

          // Add 4 vertices for this quad to have flat shading normals
          // Normal is perpendicular to the side face
          Vector3 edge = p2 - p1;
          Vector3 toBack = p3 - p2; // or roughly z axis
          Vector3 normal = edge.cross(toBack)..normalize();

          int sideOffset = allVertices.length;
          allVertices.add(p1);
          allNormals.add(normal);
          allVertices.add(p2);
          allNormals.add(normal);
          allVertices.add(p3);
          allNormals.add(normal);
          allVertices.add(p4);
          allNormals.add(normal);

          // Triangle 1
          triIndices.add(sideOffset);
          triIndices.add(sideOffset + 1); // p2
          triIndices.add(sideOffset + 2); // p3

          // Triangle 2
          triIndices.add(sideOffset);
          triIndices.add(sideOffset + 2); // p3
          triIndices.add(sideOffset + 3); // p4

          // top face for glyph edges
          lineIndices.add(sideOffset);
          lineIndices.add(sideOffset + 1);

          // bottom face for glyph edges
          lineIndices.add(sideOffset + 2);
          lineIndices.add(sideOffset + 3);

          // Lines for side edges
          lineIndices.add(sideOffset);
          lineIndices.add(sideOffset + 3);

          lineIndices.add(sideOffset + 1);
          lineIndices.add(sideOffset + 2);
        }
      }

      // Advance cursor
      cursorX += _fontParser!.getAdvanceWidth(glyphIndex) * size;
    }

    // Convert to buffers
    _init(vertexCount: allVertices.length, withNormals: true);

    for (int i = 0; i < allVertices.length; i++) {
      _vertices![i] = allVertices[i];
      _normals![i] = allNormals[i];
    }

    _createVBO();

    // Indices
    // M3Indices requires Uint16 array
    // Check if indices fit in uint16. If not, we might need to split or use extension (OES_element_index_uint),
    // but M3Indices implementation says Uint16Array.
    // So if > 65535, this will break. For simple text it's fine.

    final indicesArray = Uint16Array.fromList(triIndices);
    _faceIndices.add(_M3Indices(WebGL.TRIANGLES, indicesArray));

    // wireframe edges
    _edgeIndices.add(_M3Indices(WebGL.LINES, Uint16Array.fromList(lineIndices)));
  }
}
