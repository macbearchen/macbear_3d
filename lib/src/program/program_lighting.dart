part of 'program.dart';

///
mixin M3LightingShader {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  late UniformLocation uniformAmbient; // "ColorAmbient" = inColor * LightAmbient * MaterialDiffuse
  late UniformLocation uniformDiffuse; // "ColorDiffuse" = inColor * LightDiffuse * MaterialDiffuse
  late UniformLocation uniformSpecular; // "ColorSpecular" = inColor * LightDiffuse * MaterialSpecular (w: Shininess)

  late UniformLocation uniformLightPosition; // light position "LightPosition" (per object-space)

  M3Light? _light; // active light

  void initLightingLocation(Program prog) {
    uniformAmbient = gl.getUniformLocation(prog, "ColorAmbient");
    uniformDiffuse = gl.getUniformLocation(prog, "ColorDiffuse");
    uniformSpecular = gl.getUniformLocation(prog, "ColorSpecular");

    uniformLightPosition = gl.getUniformLocation(prog, "LightPosition");
  }

  void attachLight(M3Light sceneLight) {
    _light = sceneLight;
  }

  void setLightPosition(Matrix4 mMatrix) {
    if (_light == null) return;

    if (M3Program.isLocationValid(uniformLightPosition)) {
      Vector4 lightDirection = Matrix4.inverted(mMatrix) * _light!.getDirection();
      lightDirection.normalize();
      gl.uniform3fv(uniformLightPosition, lightDirection.xyz.storage);
    }
  }
}

mixin M3FogShader {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  UniformLocation? uniformFogPlane;
  UniformLocation? uniformFogDepth;
  UniformLocation? uniformFogColor;

  M3Fog? _fog;

  void initFogLocation(Program prog) {
    uniformFogPlane = gl.getUniformLocation(prog, "FogPlane");
    uniformFogDepth = gl.getUniformLocation(prog, "FogDepth");
    uniformFogColor = gl.getUniformLocation(prog, "FogColor");
  }

  void applyFog(M3Fog fog) {
    _fog = fog;

    if (M3Program.isLocationValid(uniformFogColor)) {
      gl.uniform3fv(uniformFogColor!, fog.color.storage);
    }
    if (M3Program.isLocationValid(uniformFogDepth)) {
      gl.uniform1f(uniformFogDepth!, fog.depth);
    }
  }

  void setFogPlane(M3Camera camera, Matrix4 worldMatrix) {
    final fog = _fog;
    if (fog == null) return;

    if (!M3Program.isLocationValid(uniformFogPlane)) return;

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

    gl.uniform4fv(uniformFogPlane!, objectPlane.storage);
  }
}

class M3ProgramLighting extends M3ProgramEye with M3LightingShader, M3FogShader {
  M3ProgramLighting(super.strVert, super.strFrag, {super.reflectionType});

  @override
  void initLocation() {
    super.initLocation();

    initLightingLocation(program);
    initFogLocation(program);
  }

  @override
  void setMatrices(M3Camera cam, Matrix4 mMatrix) {
    super.setMatrices(cam, mMatrix);

    setLightPosition(mMatrix);
    setFogPlane(cam, mMatrix);
  }

  @override
  void setMaterial(M3Material mtr, Vector4 color) {
    super.setMaterial(mtr, color);

    Vector4 outDiffuse = M3Light.blendRGBA(mtr.diffuse, color);

    // ambient: RGB
    if (M3Program.isLocationValid(uniformAmbient)) {
      Vector3 outAmbient = M3Light.blendRGB(M3Light.ambient, outDiffuse.rgb);
      gl.uniform3fv(uniformAmbient, outAmbient.storage);
    }

    // diffuse: RGBA
    if (M3Program.isLocationValid(uniformDiffuse)) {
      outDiffuse.xyz = M3Light.blendRGB(_light!.color, outDiffuse.rgb);
      gl.uniform4fv(uniformDiffuse, outDiffuse.storage);
    }

    // specular: RGB
    if (M3Program.isLocationValid(uniformSpecular)) {
      Vector3 outSpecular = M3Light.blendRGB(mtr.specular, color.rgb);
      outSpecular = M3Light.blendRGB(_light!.color, outSpecular);

      // Pass as vec4: RGB, w = Shininess
      gl.uniform4f(uniformSpecular, outSpecular.x, outSpecular.y, outSpecular.z, mtr.shininess);
    }
  }
}
