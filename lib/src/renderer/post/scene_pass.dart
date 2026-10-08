// Macbear3D engine
import '../../m3_internal.dart';

class M3ScenePass {
  final renderEngine = M3AppEngine.instance.renderEngine;

  /// FBO render target
  late M3RenderTarget _target;
  M3Texture get texture => _target.texture;

  /// renderTarget from manager by key.
  M3ScenePass(String keyRt) {
    _target = renderEngine.renderTargets.get(keyRt);
  }
}
