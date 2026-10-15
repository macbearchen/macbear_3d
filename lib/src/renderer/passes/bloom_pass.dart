// Macbear3D engine
import '../../m3_internal.dart';

class M3BloomPass {
  final renderEngine = M3AppEngine.instance.renderEngine;

  /// FBO render targets for ping-pong blur
  late M3RenderTarget _targetPing;
  late M3RenderTarget _targetPong;

  M3Texture get texture => _targetPing.texture;

  /// Bloom parameters
  double threshold = 0.9;
  double softKnee = 0.5;
  int blurIterations = 2; // Number of horizontal + vertical passes

  /// Initialize bloom pass with render targets
  M3BloomPass(String keyPing, [String keyPong = 'bloom_pong']) {
    _targetPing = renderEngine.renderTargets.get(keyPing);
    _targetPong = renderEngine.renderTargets.get(keyPong);
  }

  /// Execute bloom extraction and blur from [sceneTexture]
  void render(M3Texture sceneTexture) {
    final gl = renderEngine.gl;

    gl.disable(WebGL.DEPTH_TEST);
    gl.disable(WebGL.CULL_FACE);
    gl.disable(WebGL.BLEND);

    // 1. Bright Pass extraction into bloom_ping
    _targetPing.bind();
    M3PostProcess.drawBrightPass(
      sceneTexture,
      threshold: threshold,
      softKnee: softKnee,
    );

    // 2. Ping-pong Gaussian Blur (Horizontal & Vertical)
    for (int i = 0; i < blurIterations; i++) {
      // Horizontal blur: read ping, write to pong
      _targetPong.bind();
      M3PostProcess.drawBlur(_targetPing.texture, 1.0, 0.0);

      // Vertical blur: read pong, write to ping
      _targetPing.bind();
      M3PostProcess.drawBlur(_targetPong.texture, 0.0, 1.0);
    }
  }
}
