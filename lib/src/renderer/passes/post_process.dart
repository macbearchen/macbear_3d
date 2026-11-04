// Macbear3D engine
import '../../m3_internal.dart';

import '../../shaders_gen/post/Blur.es3.frag.g.dart';
import '../../shaders_gen/post/BrightPass.es3.frag.g.dart';
import '../../shaders_gen/post/Composite.es3.frag.g.dart';
import '../../shaders_gen/post/Dof.es3.frag.g.dart';
import '../../shaders_gen/post/FXAA.es3.frag.g.dart';
import '../../shaders_gen/post/Fullscreen.es3.frag.g.dart';
import '../../shaders_gen/post/Fullscreen.es3.vert.g.dart';
import '../../shaders_gen/post/SceneDepth.es3.frag.g.dart';
import '../../shaders_gen/post/glsl/Tonemap.es3.glsl.g.dart';

class M3PostProcess {
  static RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;
  // dummy VAO for ES3; otherwise WebGL errors if no VAO is bound when drawing
  static VertexArrayObject emptyVao = gl.createVertexArray();

  // post processing programs
  static M3Program programFullscreen = M3Program(Fullscreen_vert, Fullscreen_frag + Tonemap_glsl)..name = 'Fullscreen';
  static M3Program programSceneDepth = M3Program(Fullscreen_vert, SceneDepth_frag)..name = 'SceneDepth';
  static M3Program programBrightPass = M3Program(Fullscreen_vert, BrightPass_frag)..name = 'BrightPass';
  static M3Program programBlur = M3Program(Fullscreen_vert, Blur_frag)..name = 'Blur';
  static M3Program programComposite = M3Program(Fullscreen_vert, Composite_frag + Tonemap_glsl)..name = 'Composite';
  static M3Program programFxaa = M3Program(Fullscreen_vert, FXAA_frag)..name = 'FXAA';
  static M3Program programDof = M3Program(Fullscreen_vert, Dof_frag)..name = 'DOF';

  // Uniform locations: Fullscreen
  static late UniformLocation _uFullscreenTonemapMode;
  static late UniformLocation _uFullscreenExposure;

  // Uniform locations: FXAA
  static late UniformLocation _uFxaaTexelSize;

  // Uniform locations: BrightPass
  static late UniformLocation _uBrightThreshold;
  static late UniformLocation _uBrightSoftKnee;

  // Uniform locations: Blur
  static late UniformLocation _uBlurTexelSize;
  static late UniformLocation _uBlurDirection;

  // Uniform locations: Composite
  static late UniformLocation _uCompositeBloomIntensity;
  static late UniformLocation _uCompositeSamplerBloom;
  static late UniformLocation _uCompositeTonemapMode;
  static late UniformLocation _uCompositeExposure;

  // Uniform locations: DOF
  static late UniformLocation _uDofSamplerDepth;
  static late UniformLocation _uDofCameraNearFar;
  static late UniformLocation _uDofParams;
  static late UniformLocation _uDofTexelSize;

  static void init() {
    emptyVao;
    programFullscreen;

    // Cache Fullscreen uniforms
    _uFullscreenTonemapMode = gl.getUniformLocation(programFullscreen.program, 'uTonemapMode');
    _uFullscreenExposure = gl.getUniformLocation(programFullscreen.program, 'uExposure');

    // Cache BrightPass uniforms
    _uBrightThreshold = gl.getUniformLocation(programBrightPass.program, 'uThreshold');
    _uBrightSoftKnee = gl.getUniformLocation(programBrightPass.program, 'uSoftKnee');

    // Cache Blur uniforms
    _uBlurTexelSize = gl.getUniformLocation(programBlur.program, 'uTexelSize');
    _uBlurDirection = gl.getUniformLocation(programBlur.program, 'uDirection');

    // Cache Composite uniforms
    _uCompositeBloomIntensity = gl.getUniformLocation(programComposite.program, 'uBloomIntensity');
    _uCompositeSamplerBloom = gl.getUniformLocation(programComposite.program, 'SamplerBloom');
    _uCompositeTonemapMode = gl.getUniformLocation(programComposite.program, 'uTonemapMode');
    _uCompositeExposure = gl.getUniformLocation(programComposite.program, 'uExposure');

    // Cache FXAA uniforms
    _uFxaaTexelSize = gl.getUniformLocation(programFxaa.program, 'uTexelSize');

    // Cache DOF uniforms
    _uDofSamplerDepth = gl.getUniformLocation(programDof.program, 'SamplerDepth');
    _uDofCameraNearFar = gl.getUniformLocation(programDof.program, 'uCameraNearFar');
    _uDofParams = gl.getUniformLocation(programDof.program, 'uDofParams');
    _uDofTexelSize = gl.getUniformLocation(programDof.program, 'uTexelSize');

    // Explicitly configure SamplerDiffuse = 0 for programs
    final uFullSampler = gl.getUniformLocation(programFullscreen.program, 'SamplerDiffuse');
    if (M3Program.isLocationValid(uFullSampler)) {
      gl.useProgram(programFullscreen.program);
      gl.uniform1i(uFullSampler, 0);
    }

    final uDofSampler = gl.getUniformLocation(programDof.program, 'SamplerDiffuse');
    gl.useProgram(programDof.program);
    if (M3Program.isLocationValid(uDofSampler)) {
      gl.uniform1i(uDofSampler, 0);
    }
    if (M3Program.isLocationValid(_uDofSamplerDepth)) {
      gl.uniform1i(_uDofSamplerDepth, 1); // Depth texture on unit 1
    }

    final uFxaaSampler = gl.getUniformLocation(programFxaa.program, 'SamplerDiffuse');
    if (M3Program.isLocationValid(uFxaaSampler)) {
      gl.useProgram(programFxaa.program);
      gl.uniform1i(uFxaaSampler, 0);
    }

    final uBrightSampler = gl.getUniformLocation(programBrightPass.program, 'SamplerDiffuse');
    if (M3Program.isLocationValid(uBrightSampler)) {
      gl.useProgram(programBrightPass.program);
      gl.uniform1i(uBrightSampler, 0);
    }

    final uBlurSampler = gl.getUniformLocation(programBlur.program, 'SamplerDiffuse');
    if (M3Program.isLocationValid(uBlurSampler)) {
      gl.useProgram(programBlur.program);
      gl.uniform1i(uBlurSampler, 0);
    }

    final uCompDiffuse = gl.getUniformLocation(programComposite.program, 'SamplerDiffuse');
    gl.useProgram(programComposite.program);
    if (M3Program.isLocationValid(uCompDiffuse)) {
      gl.uniform1i(uCompDiffuse, 0);
    }
    // Set texture unit 1 for SamplerBloom in Composite program
    gl.uniform1i(_uCompositeSamplerBloom, 1);

    M3Log.i('M3PostProcess', 'init done');
  }

  static void dispose() {
    gl.deleteVertexArray(emptyVao);

    // post processing programs
    programFullscreen.dispose();
    programSceneDepth.dispose();
    programBrightPass.dispose();
    programBlur.dispose();
    programComposite.dispose();
    programFxaa.dispose();
    programDof.dispose();
  }

  /// Draw a fullscreen pass with a given program and primary texture
  static void drawFullscreen(
    M3Texture tex, {
    M3Program? program,
    M3TonemapMode tonemapMode = M3TonemapMode.aces,
    double exposure = 1.0,
  }) {
    final prog = program ?? programFullscreen;
    gl.useProgram(prog.program);

    if (prog == programFullscreen) {
      if (M3Program.isLocationValid(_uFullscreenTonemapMode)) {
        gl.uniform1i(_uFullscreenTonemapMode, tonemapMode.id);
      }
      if (M3Program.isLocationValid(_uFullscreenExposure)) {
        gl.uniform1f(_uFullscreenExposure, exposure);
      }
    }

    gl.activeTexture(WebGL.TEXTURE0);
    tex.bind();
    gl.bindVertexArray(emptyVao); // ES3 needs a VAO bound, no attribs
    gl.drawArrays(WebGL.TRIANGLES, 0, 3);

    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
  }

  /// Run Bright-pass filter to extract highlights from [srcTex] into current FBO
  static void drawBrightPass(M3Texture srcTex, {double threshold = 1.0, double softKnee = 0.5}) {
    gl.useProgram(programBrightPass.program);

    gl.uniform1f(_uBrightThreshold, threshold);
    gl.uniform1f(_uBrightSoftKnee, softKnee);

    gl.activeTexture(WebGL.TEXTURE0);
    srcTex.bind();
    gl.bindVertexArray(emptyVao);
    gl.drawArrays(WebGL.TRIANGLES, 0, 3);

    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
  }

  /// Run single separable blur step in [dirX], [dirY] direction
  static void drawBlur(M3Texture srcTex, double dirX, double dirY) {
    gl.useProgram(programBlur.program);

    final texW = srcTex.texW > 0 ? srcTex.texW : 1;
    final texH = srcTex.texH > 0 ? srcTex.texH : 1;
    gl.uniform2f(_uBlurTexelSize, 1.0 / texW, 1.0 / texH);
    gl.uniform2f(_uBlurDirection, dirX, dirY);

    gl.activeTexture(WebGL.TEXTURE0);
    srcTex.bind();
    gl.bindVertexArray(emptyVao);
    gl.drawArrays(WebGL.TRIANGLES, 0, 3);

    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
  }

  /// Composite [sceneTex] with [bloomTex] and apply tonemapping/gamma to current FBO / default FBO
  static void drawComposite(
    M3Texture sceneTex,
    M3Texture bloomTex, {
    double bloomIntensity = 0.8,
    M3TonemapMode tonemapMode = M3TonemapMode.aces,
    double exposure = 1.0,
  }) {
    gl.useProgram(programComposite.program);

    gl.uniform1f(_uCompositeBloomIntensity, bloomIntensity);
    if (M3Program.isLocationValid(_uCompositeTonemapMode)) {
      gl.uniform1i(_uCompositeTonemapMode, tonemapMode.id);
    }
    if (M3Program.isLocationValid(_uCompositeExposure)) {
      gl.uniform1f(_uCompositeExposure, exposure);
    }

    // Texture Unit 0: Scene HDR texture
    gl.activeTexture(WebGL.TEXTURE0);
    sceneTex.bind();

    // Texture Unit 1: Bloom blurred texture
    gl.activeTexture(WebGL.TEXTURE1);
    bloomTex.bind();

    gl.bindVertexArray(emptyVao);
    gl.drawArrays(WebGL.TRIANGLES, 0, 3);

    gl.activeTexture(WebGL.TEXTURE1);
    gl.bindTexture(WebGL.TEXTURE_2D, null);

    gl.activeTexture(WebGL.TEXTURE0);
    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
  }

  /// Run FXAA antialiasing pass from [srcTex] into current FBO / default FBO
  static void drawFxaa(M3Texture srcTex) {
    gl.useProgram(programFxaa.program);

    final texW = srcTex.texW > 0 ? srcTex.texW : 1;
    final texH = srcTex.texH > 0 ? srcTex.texH : 1;
    if (M3Program.isLocationValid(_uFxaaTexelSize)) {
      gl.uniform2f(_uFxaaTexelSize, 1.0 / texW, 1.0 / texH);
    }

    gl.activeTexture(WebGL.TEXTURE0);
    srcTex.bind();
    gl.bindVertexArray(emptyVao);
    gl.drawArrays(WebGL.TRIANGLES, 0, 3);

    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
  }

  /// Run Depth of Field (DOF) pass reading [colorTex] and [depthTex]
  static void drawDof(
    M3Texture colorTex,
    M3Texture depthTex, {
    required double near,
    required double far,
    double focusDistance = 15.0,
    double focusRange = 5.0,
    double bokehRadius = 8.0,
  }) {
    gl.useProgram(programDof.program);

    final texW = colorTex.texW > 0 ? colorTex.texW : 1;
    final texH = colorTex.texH > 0 ? colorTex.texH : 1;
    if (M3Program.isLocationValid(_uDofTexelSize)) {
      gl.uniform2f(_uDofTexelSize, 1.0 / texW, 1.0 / texH);
    }
    if (M3Program.isLocationValid(_uDofCameraNearFar)) {
      gl.uniform2f(_uDofCameraNearFar, near, far);
    }
    if (M3Program.isLocationValid(_uDofParams)) {
      gl.uniform4f(_uDofParams, focusDistance, focusRange, bokehRadius, 0.0);
    }

    // Texture Unit 0: Color Texture
    gl.activeTexture(WebGL.TEXTURE0);
    colorTex.bind();

    // Texture Unit 1: Depth Texture
    gl.activeTexture(WebGL.TEXTURE1);
    depthTex.bind();

    gl.bindVertexArray(emptyVao);
    gl.drawArrays(WebGL.TRIANGLES, 0, 3);

    gl.activeTexture(WebGL.TEXTURE1);
    gl.bindTexture(WebGL.TEXTURE_2D, null);

    gl.activeTexture(WebGL.TEXTURE0);
    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
  }
}
