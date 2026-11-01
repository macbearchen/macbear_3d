part of '../program.dart';

/// water shader in program
mixin M3WaterShader {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  late UniformLocation uniformBumpTranslateScale0; // bump translation, scale
  late UniformLocation uniformBumpTranslateScale1; // bump translation, scale
  late UniformLocation uniformWaveDistortion; // wave distortion

  // Foam and depth uniforms
  late UniformLocation uniformCameraNearFar; // x: near, y: far
  late UniformLocation uniformFoamParams; // x: distance, y: falloff, z: intensity, w: edgeDistortionDistance
  late UniformLocation uniformFoamColor; // rgba foam color

  // tangent-space: tangent, binormal, normal
  late UniformLocation uniformAxisTangent;
  late UniformLocation uniformAxisBinormal;
  late UniformLocation uniformAxisNormal;

  void initWaterLocation(Program prog) {
    uniformBumpTranslateScale0 = gl.getUniformLocation(prog, "BumpTranslateScale0");
    uniformBumpTranslateScale1 = gl.getUniformLocation(prog, "BumpTranslateScale1");
    uniformWaveDistortion = gl.getUniformLocation(prog, "WaveDistortion");

    uniformCameraNearFar = gl.getUniformLocation(prog, "CameraNearFar");
    uniformFoamParams = gl.getUniformLocation(prog, "FoamParams");
    uniformFoamColor = gl.getUniformLocation(prog, "FoamColor");

    uniformAxisTangent = gl.getUniformLocation(prog, "AxisTangent");
    uniformAxisBinormal = gl.getUniformLocation(prog, "AxisBinormal");
    uniformAxisNormal = gl.getUniformLocation(prog, "AxisNormal");

    // Set the sampler2D variables
    gl.uniform1i(gl.getUniformLocation(prog, "NormalTex"), 1); // GL_TEXTURE1
    gl.uniform1i(gl.getUniformLocation(prog, "RefractionTex"), 2); // GL_TEXTURE2
    final depthLoc = gl.getUniformLocation(prog, "SceneDepthTex");
    if (M3Program.isLocationValid(depthLoc)) {
      gl.uniform1i(depthLoc, 7); // GL_TEXTURE7
    }
  }

  /// bind water reflection, refraction, bump, etc.
  void bindWater(M3Water water) {
    // Bind texture
    gl.activeTexture(WebGL.TEXTURE1);
    water.normalMap.bind();

    gl.activeTexture(WebGL.TEXTURE2);
    if (water.refractionPass.enable) {
      water.refractionPass.texture.bind();
    } else {
      M3Resources.texWhite.bind();
    }

    // Bind scene depth texture (GL_TEXTURE7)
    gl.activeTexture(WebGL.TEXTURE7);
    final sceneDepthRt = M3AppEngine.instance.renderEngine.renderTargets.get('sceneDepth'); // scene
    sceneDepthRt.texture.bind();

    // diffuse by reflection
    gl.activeTexture(WebGL.TEXTURE0);
    if (water.reflectionPass.enable) {
      water.reflectionPass.texture.bind();
    } else {
      M3Resources.texWhite.bind();
    }

    // uniform param for bump of water (per GLSL)
    final bump0 = water.flow0;
    final bump1 = water.flow1;
    gl.uniform4f(uniformBumpTranslateScale0, bump0.offset.x, bump0.offset.y, bump0.scale.x, bump0.scale.y);
    gl.uniform4f(uniformBumpTranslateScale1, bump1.offset.x, bump1.offset.y, bump1.scale.x, bump1.scale.y);
    gl.uniform1f(uniformWaveDistortion, water.waveDistortion);

    // Camera near/far
    if (M3Program.isLocationValid(uniformCameraNearFar)) {
      final cam = water.scene.camera;
      gl.uniform2f(uniformCameraNearFar, cam.nearClip, cam.farClip);
    }

    // Foam parameters
    if (M3Program.isLocationValid(uniformFoamParams)) {
      final foamDist = water.enableFoam ? water.foamDistance : 0.0;
      gl.uniform4f(uniformFoamParams, foamDist, water.foamFalloff, water.foamIntensity, water.edgeDistortionDistance);
    }

    // Foam color
    if (M3Program.isLocationValid(uniformFoamColor)) {
      final fc = water.foamColor;
      gl.uniform4f(uniformFoamColor, fc.x, fc.y, fc.z, fc.w);
    }
  }

  void _setTBN(Vector3 tangent, Vector3 binormal, Vector3 normal) {
    // tangent-space: tangent, binormal, normal
    gl.uniform3fv(uniformAxisTangent, tangent.storage);
    gl.uniform3fv(uniformAxisBinormal, binormal.storage);
    gl.uniform3fv(uniformAxisNormal, normal.storage);
  }
}
