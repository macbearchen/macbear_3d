part of '../program.dart';

/// shadow shader in program
mixin M3ShadowShader {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  // texture sampler for shadowmap
  late UniformLocation uniformSamplerShadowmap;
  late UniformLocation uniformShadowmapSize;
  late UniformLocation uniformNormalBias;

  void initShadowLocation(Program prog) {
    uniformSamplerShadowmap = gl.getUniformLocation(prog, "SamplerShadowmap");
    uniformShadowmapSize = gl.getUniformLocation(prog, "ShadowmapSize");
    uniformNormalBias = gl.getUniformLocation(prog, "NormalBias");

    if (M3Program.isLocationValid(uniformSamplerShadowmap)) {
      gl.uniform1i(uniformSamplerShadowmap, 3);
    }
  }

  /// Apply shadowmap related uniform variables.
  void applyShadow(M3Light sceneLight) {
    if (M3Program.isLocationValid(uniformShadowmapSize)) {
      final shadowMap = M3AppEngine.instance.renderEngine.shadowMap!;
      gl.uniform2f(uniformShadowmapSize, shadowMap.mapW.toDouble(), shadowMap.mapH.toDouble());
    }
    if (M3Program.isLocationValid(uniformNormalBias)) {
      gl.uniform1f(uniformNormalBias, sceneLight.shadowNormalBias);
    }
  }

  void bindShadow(WebGLTexture texture) {
    gl.activeTexture(WebGL.TEXTURE3);
    gl.bindTexture(WebGL.TEXTURE_2D, texture);
    gl.uniform1i(uniformSamplerShadowmap, 3);

    gl.activeTexture(WebGL.TEXTURE0);
  }
}
