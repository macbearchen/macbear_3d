part of '../program.dart';

/// shadow shader in program
mixin M3ShadowShader {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  // texture sampler for shadowmap
  late UniformLocation uniformSamplerShadowmap;
  late UniformLocation uniformShadowmapTexelSize;
  late UniformLocation uniformNormalBias;

  void initShadowLocation(Program prog) {
    uniformSamplerShadowmap = gl.getUniformLocation(prog, "SamplerShadowmap");
    uniformShadowmapTexelSize = gl.getUniformLocation(prog, "ShadowmapTexelSize");
    uniformNormalBias = gl.getUniformLocation(prog, "NormalBias");

    if (M3Program.isLocationValid(uniformSamplerShadowmap)) {
      gl.uniform1i(uniformSamplerShadowmap, 3);
    }
  }

  /// Apply shadowmap related uniform variables.
  void _applyShadow(M3DirectionalLight light) {
    final shadowMap = light.shadowMap;
    if (shadowMap == null) return;

    // shadowmap texture
    if (M3Program.isLocationValid(uniformSamplerShadowmap)) {
      gl.activeTexture(WebGL.TEXTURE3);
      shadowMap.depthTex.bind();
      gl.uniform1i(uniformSamplerShadowmap, 3);

      gl.activeTexture(WebGL.TEXTURE0);
    }

    // shadowmap texel size (pre-computed on CPU: 1/resolution)
    if (M3Program.isLocationValid(uniformShadowmapTexelSize)) {
      final texelW = 1.0 / shadowMap.mapW;
      final csmCount = light.cascades.length;
      final texelH = 1.0 / (shadowMap.mapH * (csmCount > 0 ? csmCount : 1.0));
      gl.uniform2f(uniformShadowmapTexelSize, texelW, texelH);
    }

    // shadowmap normal bias
    if (M3Program.isLocationValid(uniformNormalBias)) {
      gl.uniform1f(uniformNormalBias, light.shadowNormalBias);
    }
  }
}
