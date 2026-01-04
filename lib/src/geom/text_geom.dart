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
      // We calculate signed area to determine winding.
      double getSignedArea(List<Vector2> contour) {
        double area = 0.0;
        for (int k = 0; k < contour.length; k++) {
          Vector2 p1 = contour[k];
          Vector2 p2 = contour[(k + 1) % contour.length];
          area += (p1.x * p2.y - p2.x * p1.y);
        }
        return area / 2.0;
      }

      var contourData = contours.where((c) => c.length >= 3).map((c) {
        double area = getSignedArea(c);
        return {'points': c, 'area': area};
      }).toList();

      if (contourData.isEmpty) {
        cursorX += _fontParser!.getAdvanceWidth(glyphIndex) * size;
        continue;
      }

      // Robust classification: The largest contour is always an outer.
      // Other contours are outers if they have the same sign, holes if opposite.
      contourData.sort((a, b) => (b['area'] as double).abs().compareTo((a['area'] as double).abs()));
      double primarySign = (contourData[0]['area'] as double).sign;

      List<List<Vector2>> normalizedOuters = [];
      List<List<Vector2>> normalizedHoles = [];

      for (var data in contourData) {
        List<Vector2> pts = List.from(data['points'] as List<Vector2>);
        double area = data['area'] as double;

        if (area.sign == primarySign) {
          // It's an outer. Normalize to CCW (area > 0).
          if (area < 0) pts = pts.reversed.toList();
          normalizedOuters.add(pts);
        } else {
          // It's a hole. Normalize to CW (area < 0).
          if (area > 0) pts = pts.reversed.toList();
          normalizedHoles.add(pts);
        }
      }

      // Process each outer island separately for triangulation
      // For simplicity in this engine, we'll associate all holes with all outers.
      // M3EarClipping.triangulate handles this if holes are inside.

      for (var outer in normalizedOuters) {
        List<Vector2> triangulationInput = List.from(outer);
        List<List<Vector2>> triangulationHoles = normalizedHoles.map((e) => List<Vector2>.from(e)).toList();

        List<int> localIndices = M3EarClipping.triangulate(triangulationInput, holes: triangulationHoles);

        int indexOffset = allVertices.length;

        // Front Face (z = depth/2)
        for (var v in triangulationInput) {
          allVertices.add(Vector3(cursorX + v.x * size, v.y * size, depth / 2));
          allNormals.add(Vector3(0, 0, 1));
        }
        for (int k = 0; k < localIndices.length; k += 3) {
          triIndices.add(indexOffset + localIndices[k]);
          triIndices.add(indexOffset + localIndices[k + 1]);
          triIndices.add(indexOffset + localIndices[k + 2]);
        }

        // Back Face (z = -depth/2)
        int backIndexOffset = allVertices.length;
        for (var v in triangulationInput) {
          allVertices.add(Vector3(cursorX + v.x * size, v.y * size, -depth / 2));
          allNormals.add(Vector3(0, 0, -1));
        }
        // CW winding for back face results in CCW from the back
        for (int k = 0; k < localIndices.length; k += 3) {
          triIndices.add(backIndexOffset + localIndices[k]);
          triIndices.add(backIndexOffset + localIndices[k + 2]);
          triIndices.add(backIndexOffset + localIndices[k + 1]);
        }
      }

      // Extrusion (Sides)
      List<List<Vector2>> allContours = [...normalizedOuters, ...normalizedHoles];
      for (var contour in allContours) {
        for (int k = 0; k < contour.length; k++) {
          Vector2 curr = contour[k];
          Vector2 next = contour[(k + 1) % contour.length];

          Vector3 p1 = Vector3(cursorX + curr.x * size, curr.y * size, depth / 2); // Front curr
          Vector3 p2 = Vector3(cursorX + next.x * size, next.y * size, depth / 2); // Front next
          Vector3 p3 = Vector3(cursorX + next.x * size, next.y * size, -depth / 2); // Back next
          Vector3 p4 = Vector3(cursorX + curr.x * size, curr.y * size, -depth / 2); // Back curr

          // Normal points outward for solids (CCW loop), inward for holes (CW loop)
          Vector3 edge = p2 - p1;
          Vector3 toBack = Vector3(0, 0, 1);
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

          // Correct CCW winding for side face seen from outside:
          // Triangle 1
          triIndices.add(sideOffset);
          triIndices.add(sideOffset + 3); // p4
          triIndices.add(sideOffset + 2); // p3

          // Triangle 2
          triIndices.add(sideOffset);
          triIndices.add(sideOffset + 2); // p3
          triIndices.add(sideOffset + 1); // p2

          // Lines for wireframe
          lineIndices.add(sideOffset);
          lineIndices.add(sideOffset + 1);
          lineIndices.add(sideOffset + 1);
          lineIndices.add(sideOffset + 2);
          lineIndices.add(sideOffset + 2);
          lineIndices.add(sideOffset + 3);
          lineIndices.add(sideOffset + 3);
          lineIndices.add(sideOffset);
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
