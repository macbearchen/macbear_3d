// Macbear3D engine
import '../../m3_internal.dart';

/// FXAA anti-aliasing pass
class M3FxaaPass {
  final renderEngine = M3AppEngine.instance.renderEngine;

  /// FBO render target
  late M3RenderTarget _target;
  M3Texture get texture => _target.texture;

  /// renderTarget from manager by key.
  M3FxaaPass([String keyRt = 'fxaa']) {
    _target = renderEngine.renderTargets.get(keyRt);
  }

  /// Run FXAA pass reading [srcTex] into target FBO or default FBO
  void render(M3Texture srcTex, {bool toDefaultFramebuffer = false}) {
    final gl = renderEngine.gl;

    gl.disable(WebGL.DEPTH_TEST);
    gl.disable(WebGL.CULL_FACE);
    gl.disable(WebGL.BLEND);

    if (toDefaultFramebuffer) {
      renderEngine.bindDefaultFramebuffer();
    } else {
      _target.bind();
    }

    M3PostProcess.drawFxaa(srcTex);
  }
}
