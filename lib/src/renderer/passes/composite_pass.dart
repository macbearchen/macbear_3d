// Macbear3D engine
import '../../m3_internal.dart';

/// scene -> bloom -> composite -> final
class M3CompositePass {
  final renderEngine = M3AppEngine.instance.renderEngine;

  /// FBO render target
  late M3RenderTarget _target;
  M3Texture get texture => _target.texture;

  /// Bloom additive intensity
  double bloomIntensity = 0.8;

  /// renderTarget from manager by key.
  M3CompositePass(String keyRt) {
    _target = renderEngine.renderTargets.get(keyRt);
  }

  /// Composite scene and bloom textures directly to current target FBO or default FBO
  void render(M3Texture sceneTex, M3Texture bloomTex, {bool toDefaultFramebuffer = false}) {
    final gl = renderEngine.gl;

    gl.disable(WebGL.DEPTH_TEST);
    gl.disable(WebGL.CULL_FACE);
    gl.disable(WebGL.BLEND);

    if (toDefaultFramebuffer) {
      renderEngine.bindDefaultFramebuffer();
    } else {
      _target.bind();
    }

    M3PostProcess.drawComposite(
      sceneTex,
      bloomTex,
      bloomIntensity: bloomIntensity,
    );
  }
}
