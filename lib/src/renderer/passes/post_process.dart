// Macbear3D engine
import '../../m3_internal.dart';

import '../../shaders_gen/post/Blur.es3.frag.g.dart';
import '../../shaders_gen/post/BrightPass.es3.frag.g.dart';
import '../../shaders_gen/post/Composite.es3.frag.g.dart';
import '../../shaders_gen/post/Fullscreen.es3.frag.g.dart';
import '../../shaders_gen/post/Fullscreen.es3.vert.g.dart';

class M3PostProcess {
  static RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;
  // dummy VAO for ES3; otherwise WebGL errors if no VAO is bound when drawing
  static VertexArrayObject emptyVao = gl.createVertexArray();

  // post processing programs
  static M3Program programFullscreen = M3Program(Fullscreen_vert, Fullscreen_frag)..name = 'Fullscreen';
  static M3Program programBrightPass = M3Program(Fullscreen_vert, BrightPass_frag)..name = 'BrightPass';
  static M3Program programBlur = M3Program(Fullscreen_vert, Blur_frag)..name = 'Blur';
  static M3Program programComposite = M3Program(Fullscreen_vert, Composite_frag)..name = 'Composite';

  // Uniform locations: BrightPass
  static late UniformLocation _uBrightThreshold;
  static late UniformLocation _uBrightSoftKnee;

  // Uniform locations: Blur
  static late UniformLocation _uBlurTexelSize;
  static late UniformLocation _uBlurDirection;

  // Uniform locations: Composite
  static late UniformLocation _uCompositeBloomIntensity;
  static late UniformLocation _uCompositeSamplerBloom;

  static void init() {
    emptyVao;
    programFullscreen;

    // Cache BrightPass uniforms
    _uBrightThreshold = gl.getUniformLocation(programBrightPass.program, 'uThreshold');
    _uBrightSoftKnee = gl.getUniformLocation(programBrightPass.program, 'uSoftKnee');

    // Cache Blur uniforms
    _uBlurTexelSize = gl.getUniformLocation(programBlur.program, 'uTexelSize');
    _uBlurDirection = gl.getUniformLocation(programBlur.program, 'uDirection');

    // Cache Composite uniforms
    _uCompositeBloomIntensity = gl.getUniformLocation(programComposite.program, 'uBloomIntensity');
    _uCompositeSamplerBloom = gl.getUniformLocation(programComposite.program, 'SamplerBloom');

    // Explicitly configure SamplerDiffuse = 0 for programs
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
    programBrightPass.dispose();
    programBlur.dispose();
    programComposite.dispose();
  }

  /// Draw a fullscreen pass with a given program and primary texture
  static void drawFullscreen(M3Texture tex, {M3Program? program}) {
    final prog = program ?? programFullscreen;
    gl.useProgram(prog.program);

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
  static void drawComposite(M3Texture sceneTex, M3Texture bloomTex, {double bloomIntensity = 0.8}) {
    gl.useProgram(programComposite.program);

    gl.uniform1f(_uCompositeBloomIntensity, bloomIntensity);

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
}
