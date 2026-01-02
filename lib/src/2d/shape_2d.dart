import 'package:vector_math/vector_math_lists.dart';

// Macbear3D engine
import '../../macbear_3d.dart';

// part for shape2D
part 'rectangle_2d.dart';

/// Base class for 2D shapes with dynamic vertex buffers for lines, triangles, and images.
class M3Shape2D {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;
  static M3Program get prog2D => M3AppEngine.instance.renderEngine.programRectangle!;

  // always GL_TRIANGLES, GL_TRIANGLE_STRIP, GL_LINES, GL_LINE_STRIP
  // not supported: GL_TRIANGLE_FAN, GL_LINE_LOOP
  final int _primitiveType;
  final int _vertexCount;

  late int _usage; // usage for VBO: dynamic is slower, be careful to use it
  late Vector2List _vertices; // vertex positions
  late Vector2List _uvs; // vertex texture coordinates(u,v)

  // VBO: vertex buffer object
  late Buffer _vertexBuffer;
  late Buffer _uvBuffer;

  static M3Material mtrWhite = M3Material();
  static M3Material mtrImage = M3Material();

  // for dynamic draw: line, triangle, rectangle
  static M3Shape2D? _line;
  static M3Shape2D? _triangle;
  static M3Rectangle2D? _rectangle;

  static M3Shape2D get line {
    _line ??= M3Shape2D(WebGL.LINES, 2)..createVBO(WebGL.DYNAMIC_DRAW);
    return _line!;
  }

  static M3Shape2D get triangle {
    _triangle ??= M3Shape2D(WebGL.TRIANGLES, 3)..createVBO(WebGL.DYNAMIC_DRAW);
    return _triangle!;
  }

  static M3Rectangle2D get rectangle {
    _rectangle ??= M3Rectangle2D()..createVBO(WebGL.DYNAMIC_DRAW);
    return _rectangle!;
  }

  M3Shape2D(this._primitiveType, this._vertexCount) {
    // call init with vertex count
    _vertices = Vector2List(_vertexCount);
    _uvs = Vector2List(_vertexCount);

    // createVBO();
  }

  @override
  String toString() {
    final drawUsage = _usage == WebGL.STATIC_DRAW ? 'STATIC_DRAW' : 'DYNAMIC_DRAW';
    return 'M3Shape2D{Count: $_vertexCount, $drawUsage}';
  }

  // create vertex buffer object: static or dynamic
  // dynamic is slower, be careful to use it
  void createVBO(int usage) {
    _usage = usage;
    // buffers for vertices, normals after init
    _vertexBuffer = gl.createBuffer();
    gl.bindBuffer(WebGL.ARRAY_BUFFER, _vertexBuffer);
    gl.bufferData(WebGL.ARRAY_BUFFER, Float32Array.fromList(_vertices.buffer), usage);

    _uvBuffer = gl.createBuffer();
    gl.bindBuffer(WebGL.ARRAY_BUFFER, _uvBuffer);
    gl.bufferData(WebGL.ARRAY_BUFFER, Float32Array.fromList(_uvs.buffer), usage);
  }

  void draw() {
    // bind vertex buffer
    gl.bindBuffer(WebGL.ARRAY_BUFFER, _vertexBuffer);
    if (_usage != WebGL.STATIC_DRAW) {
      gl.bufferSubData(WebGL.ARRAY_BUFFER, 0, Float32Array.fromList(_vertices.buffer));
    }
    gl.vertexAttribPointer(prog2D.attribVertex.id, 2, WebGL.FLOAT, false, 0, 0);

    gl.bindBuffer(WebGL.ARRAY_BUFFER, _uvBuffer);
    if (_usage != WebGL.STATIC_DRAW) {
      gl.bufferSubData(WebGL.ARRAY_BUFFER, 0, Float32Array.fromList(_uvs.buffer));
    }
    gl.vertexAttribPointer(prog2D.attribUV.id, 2, WebGL.FLOAT, false, 0, 0);

    // draw call
    gl.drawArrays(_primitiveType, 0, _vertices.length);

    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
  }

  // dynamic draw line
  static void drawLine(Vector2 pt0, Vector2 pt1, Vector4 color) {
    // set line vertices
    line._vertices[0] = pt0;
    line._vertices[1] = pt1;

    prog2D.setMaterial(M3Shape2D.mtrWhite, color);

    // draw shape2D
    line.draw();
  }

  // dynamic draw triangle
  static void drawTriangle(Vector2 pt0, Vector2 pt1, Vector2 pt2, Vector4 color) {
    // set triangle vertices
    triangle._vertices[0] = pt0;
    triangle._vertices[1] = pt1;
    triangle._vertices[2] = pt2;

    prog2D.setMaterial(M3Shape2D.mtrWhite, color);

    // draw shape2D
    triangle.draw();
  }

  static void drawImage(M3Texture tex, Matrix4 mvMatrix, {Vector4? color}) {
    rectangle.setRectangle(0, 0, tex.texW.toDouble(), tex.texH.toDouble());

    Vector4 colorImage = Colors.white;
    if (color != null) {
      colorImage = color;
    }
    M3Shape2D.mtrImage.texDiffuse = tex;

    M3Shape2D.prog2D.setMaterial(M3Shape2D.mtrImage, colorImage);
    M3Shape2D.prog2D.setModelViewMatrix(mvMatrix);

    // draw shape2D
    rectangle.draw();
  }

  static void drawTouches(M3TouchManager manager) {
    final colors = [
      Vector4(1, 0, 0, 1), // left: 0x01
      Vector4(0, 1, 0, 1), // right: 0x02
      Vector4(1, 1, 0, 1), // left + right: 0x03
      Vector4(0, 0, 1, 1), // middle: 0x04
      Vector4(1, 0, 1, 1), // left + middle: 0x05
      Vector4(0, 1, 1, 1), // right + middle: 0x06
      Vector4(1, 1, 1, 1), // left + middle + right: 0x07
    ];
    manager.touches.forEach((id, touch) {
      if (touch.path.length < 2) return;
      Vector2 pt0, pt1;

      pt0 = touch.path[0].position;
      drawTriangle(pt0, pt0 + Vector2(0, -20), pt0 + Vector2(-9, -15), Vector4(0.7, 0.3, 0.7, 1));

      for (int i = 0; i < touch.path.length - 1; i++) {
        pt0 = touch.path[i].position;
        pt1 = touch.path[i + 1].position;
        final index = (touch.path[i].buttons - 1) % 7;
        drawLine(pt0, pt1, colors[index]);
      }

      pt1 = touch.path[touch.path.length - 1].position;
      drawTriangle(pt1, pt1 + Vector2(0, -20), pt1 + Vector2(-9, -15), Vector4(0.7, 0.7, 0.3, 1));
    });
  }
}
