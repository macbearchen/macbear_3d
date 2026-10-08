// Generated file – do not edit.
// ignore: constant_identifier_names
const String Fullscreen_vert = r"""
#version 300 es
precision mediump float;
// Fullscreen vert-shader //////////

out vec2 vUV;

void main() {
    vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
    vUV = vec2(p.x, 1.0 - p.y);
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
""";
