part of '../program.dart';

/// fog shader in program
mixin M3FogShader {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  late UniformLocation uniformFogPlane;
  late UniformLocation uniformFogDepth;
  late UniformLocation uniformFogColor;

  M3Fog? _fog;

  void initFogLocation(Program prog) {
    uniformFogPlane = gl.getUniformLocation(prog, "FogPlane");
    uniformFogDepth = gl.getUniformLocation(prog, "FogDepth");
    uniformFogColor = gl.getUniformLocation(prog, "FogColor");
  }

  void applyFog(M3Fog fog) {
    bool fogEnabled = false;

    if (M3Program.isLocationValid(uniformFogColor) && M3Program.isLocationValid(uniformFogDepth)) {
      gl.uniform3fv(uniformFogColor, fog.color.storage);
      gl.uniform1f(uniformFogDepth, fog.depth);
      fogEnabled = true;
    }
    _fog = fogEnabled ? fog : null;
  }

  void setFogPlane(M3Camera camera, Matrix4 worldMatrix) {
    final fog = _fog;
    if (fog == null) return;

    if (!M3Program.isLocationValid(uniformFogPlane)) {
      debugPrint('*** M3FogShader: fog uniformFogPlane not found');
      return;
    }

    Vector4 worldPlane;
    final p = fog.customPlane;
    if (p != null) {
      // custom water plane, use opposite plane normal for refraction fog pass inside water
      worldPlane = -Vector4(p.normal.x, p.normal.y, p.normal.z, p.constant);
    } else {
      // Default to camera-facing plane (standard depth fog).
      final forward = camera.getForward();
      final eye = camera.position;

      // The plane equation is: dot(N, X) + D = 0.
      final N = forward;
      final D = -N.dot(eye) - (camera.farClip - fog.depth);
      worldPlane = Vector4(N.x, N.y, N.z, D);
    }

    // Transform world space plane to object space:
    final worldMatrixTransposed = Matrix4.copy(worldMatrix)..transpose();
    final objectPlane = worldMatrixTransposed * worldPlane;

    gl.uniform4fv(uniformFogPlane, objectPlane.storage);
  }
}
