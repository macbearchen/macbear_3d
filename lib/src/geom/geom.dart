import 'dart:math';
import 'dart:typed_data';

import 'package:vector_math/vector_math_lists.dart';

// Macbear3D engine
import '../../macbear_3d.dart';
import '../gltf/gltf_parser.dart';

// part for geom
part 'axis_geom.dart';
part 'box_geom.dart';
part 'cylinder_geom.dart';
part 'ellipsoid_geom.dart';
part 'gltf_geom.dart';
part 'obj_geom.dart';
part 'plane_geom.dart';
part 'pyramid_geom.dart';
part 'sphere_geom.dart';
part 'torus_geom.dart';

// indices for geom faces and edges to draw elements
class _M3Indices {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  // always GL_TRIANGLES, GL_TRIANGLE_STRIP, GL_LINES, GL_LINE_STRIP
  // not supported: GL_TRIANGLE_FAN, GL_LINE_LOOP
  final int _primitiveType;
  int _count = 0; // element count

  late Buffer _indexBuffer;

  _M3Indices(this._primitiveType, Uint16Array indices) {
    // buffers for indices
    _indexBuffer = gl.createBuffer();
    gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, _indexBuffer);
    gl.bufferData(WebGL.ELEMENT_ARRAY_BUFFER, indices, WebGL.STATIC_DRAW);
    _count = indices.length;
  }

  void draw() {
    gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, _indexBuffer);
    gl.drawElements(_primitiveType, _count, WebGL.UNSIGNED_SHORT, 0);
  }

  void dispose() {
    gl.deleteBuffer(_indexBuffer);
  }
}

abstract class M3Geom {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;
  static const int radialSegments = 16;

  String name = "Noname";
  int _vertexCount = 0;
  Vector3List? _vertices; // vertex positions
  Vector3List? _normals; // vertex normals
  Vector2List? _uvs; // vertex texture coordinates(u,v)
  Vector3List? _colors; // vertex colors
  Uint16List? _joints; // vertex bone indices (4 per vertex)
  Float32List? _weights; // vertex bone weights (4 per vertex)

  // VBO: vertex buffer object
  Buffer? _vertexBuffer;
  Buffer? _normalBuffer;
  Buffer? _uvBuffer;
  Buffer? _colorBuffer;
  Buffer? _jointBuffer;
  Buffer? _weightBuffer;

  // list of indices for faces and edges
  final List<_M3Indices> _faceIndices = []; // solid faces
  List<_M3Indices> _edgeIndices = []; // wireframe edges

  @override
  String toString() {
    return 'M3Geom{vertexCount: $_vertexCount, name: $name}';
  }

  void _init({required int vertexCount, bool withNormals = false, bool withUV = false, bool withColors = false}) {
    assert(vertexCount >= 0, 'indexCount must be non-negative');
    _vertexCount = vertexCount;
    _vertices = Vector3List(vertexCount);
    if (withNormals) {
      _normals = Vector3List(vertexCount);
    }
    if (withUV) {
      _uvs = Vector2List(vertexCount);
    }
    if (withColors) {
      _colors = Vector3List(vertexCount);
    }
    if (vertexCount > 0) {
      // Joint and weights are usually 4 per vertex
      _joints = Uint16List(vertexCount * 4);
      _weights = Float32List(vertexCount * 4);
    }
  }

  // buffers for vertices, normals after init
  void _createVBO() {
    if (_vertices == null) {
      return;
    }
    _vertexBuffer = gl.createBuffer();
    gl.bindBuffer(WebGL.ARRAY_BUFFER, _vertexBuffer);
    gl.bufferData(WebGL.ARRAY_BUFFER, Float32Array.fromList(_vertices!.buffer), WebGL.STATIC_DRAW);
    _vertices = null;

    if (_normals != null) {
      _normalBuffer = gl.createBuffer();
      gl.bindBuffer(WebGL.ARRAY_BUFFER, _normalBuffer);
      gl.bufferData(WebGL.ARRAY_BUFFER, Float32Array.fromList(_normals!.buffer), WebGL.STATIC_DRAW);
      _normals = null;
    }

    if (_uvs != null) {
      _uvBuffer = gl.createBuffer();
      gl.bindBuffer(WebGL.ARRAY_BUFFER, _uvBuffer);
      gl.bufferData(WebGL.ARRAY_BUFFER, Float32Array.fromList(_uvs!.buffer), WebGL.STATIC_DRAW);
      _uvs = null;
    }

    if (_joints != null) {
      _jointBuffer = gl.createBuffer();
      gl.bindBuffer(WebGL.ARRAY_BUFFER, _jointBuffer);
      gl.bufferData(WebGL.ARRAY_BUFFER, Uint16Array.fromList(_joints!), WebGL.STATIC_DRAW);
      _joints = null;
    }

    if (_weights != null) {
      _weightBuffer = gl.createBuffer();
      gl.bindBuffer(WebGL.ARRAY_BUFFER, _weightBuffer);
      gl.bufferData(WebGL.ARRAY_BUFFER, Float32Array.fromList(_weights!), WebGL.STATIC_DRAW);
      _weights = null;
    }
  }

  void dispose() {
    if (_vertexBuffer != null) {
      gl.deleteBuffer(_vertexBuffer!);
      _vertexBuffer = null;
    }
    if (_normalBuffer != null) {
      gl.deleteBuffer(_normalBuffer!);
      _normalBuffer = null;
    }
    if (_uvBuffer != null) {
      gl.deleteBuffer(_uvBuffer!);
      _uvBuffer = null;
    }
    if (_colorBuffer != null) {
      gl.deleteBuffer(_colorBuffer!);
      _colorBuffer = null;
    }
    if (_jointBuffer != null) {
      gl.deleteBuffer(_jointBuffer!);
      _jointBuffer = null;
    }
    if (_weightBuffer != null) {
      gl.deleteBuffer(_weightBuffer!);
      _weightBuffer = null;
    }
    _vertices = null;
    _normals = null;
    _uvs = null;
    _colors = null;

    // dispose indices
    for (var surface in _faceIndices) {
      surface.dispose();
    }
    for (var wireframe in _edgeIndices) {
      wireframe.dispose();
    }
    _faceIndices.clear();
    _edgeIndices.clear();
  }

  void draw(M3Program prog, {bool bSolid = true}) {
    if (_vertexBuffer != null) {
      gl.bindBuffer(WebGL.ARRAY_BUFFER, _vertexBuffer);
      gl.enableVertexAttribArray(prog.attribVertex.id);
      gl.vertexAttribPointer(prog.attribVertex.id, 3, WebGL.FLOAT, false, 0, 0);
    }
    if (_normalBuffer != null && prog.attribNormal.id >= 0) {
      gl.bindBuffer(WebGL.ARRAY_BUFFER, _normalBuffer);
      gl.enableVertexAttribArray(prog.attribNormal.id);
      gl.vertexAttribPointer(prog.attribNormal.id, 3, WebGL.FLOAT, false, 0, 0);
    }
    if (_uvBuffer != null && prog.attribUV.id >= 0) {
      gl.bindBuffer(WebGL.ARRAY_BUFFER, _uvBuffer);
      gl.enableVertexAttribArray(prog.attribUV.id);
      gl.vertexAttribPointer(prog.attribUV.id, 2, WebGL.FLOAT, false, 0, 0);
    }
    if (_colorBuffer != null && prog.attribColor.id >= 0) {
      gl.bindBuffer(WebGL.ARRAY_BUFFER, _colorBuffer);
      gl.enableVertexAttribArray(prog.attribColor.id);
      gl.vertexAttribPointer(prog.attribColor.id, 3, WebGL.FLOAT, false, 0, 0);
    }
    if (_jointBuffer != null && prog.attribBoneIndex.id >= 0) {
      gl.bindBuffer(WebGL.ARRAY_BUFFER, _jointBuffer);
      gl.enableVertexAttribArray(prog.attribBoneIndex.id);
      gl.vertexAttribPointer(prog.attribBoneIndex.id, 4, WebGL.UNSIGNED_SHORT, false, 0, 0);
    }
    if (_weightBuffer != null && prog.attribBoneWeight.id >= 0) {
      gl.bindBuffer(WebGL.ARRAY_BUFFER, _weightBuffer);
      gl.enableVertexAttribArray(prog.attribBoneWeight.id);
      gl.vertexAttribPointer(prog.attribBoneWeight.id, 4, WebGL.FLOAT, false, 0, 0);
    }

    List<_M3Indices> drawSurfaces = bSolid ? _faceIndices : _edgeIndices;
    for (var surface in drawSurfaces) {
      surface.draw();
    }

    if (_vertexBuffer != null) {
      gl.disableVertexAttribArray(prog.attribVertex.id);
    }
    if (_normalBuffer != null && prog.attribNormal.id >= 0) {
      gl.disableVertexAttribArray(prog.attribNormal.id);
    }
    if (_uvBuffer != null && prog.attribUV.id >= 0) {
      gl.disableVertexAttribArray(prog.attribUV.id);
    }
    if (_colorBuffer != null && prog.attribColor.id >= 0) {
      gl.disableVertexAttribArray(prog.attribColor.id);
    }
    if (_jointBuffer != null && prog.attribBoneIndex.id >= 0) {
      gl.disableVertexAttribArray(prog.attribBoneIndex.id);
    }
    if (_weightBuffer != null && prog.attribBoneWeight.id >= 0) {
      gl.disableVertexAttribArray(prog.attribBoneWeight.id);
    }
  }
}
