part of '../geom.dart';

/// A line geometry.
class M3LineGeom extends M3Geom {
  M3LineGeom(Vector3 pt0, Vector3 pt1) {
    _init(vertexCount: 2, withNormals: false, withUV: false);
    name = "Line";

    setLine(pt0, pt1);
    _vertexBuffer = gl.createBuffer();
    gl.bindBuffer(WebGL.ARRAY_BUFFER, _vertexBuffer);
    gl.bufferData(WebGL.ARRAY_BUFFER, toF32List(_vertices!.buffer), WebGL.DYNAMIC_DRAW);
  }

  void setLine(Vector3 pt0, Vector3 pt1) {
    final vertices = _vertices!;
    vertices[0] = pt0;
    vertices[1] = pt1;
  }

  void drawLine(M3Program prog, Vector3 pt0, Vector3 pt1) {
    setLine(pt0, pt1);

    // bind vertex buffer
    gl.bindBuffer(WebGL.ARRAY_BUFFER, _vertexBuffer);
    gl.bufferSubData(WebGL.ARRAY_BUFFER, 0, toF32List(_vertices!.buffer));
    gl.enableVertexAttribArray(prog.attribVertex.id);
    gl.vertexAttribPointer(prog.attribVertex.id, 3, WebGL.FLOAT, false, 0, 0);

    // draw call
    gl.drawArrays(WebGL.LINES, 0, 2);
    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
  }
}
