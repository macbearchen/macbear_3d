// Macbear3D engine
import '../../m3_internal.dart';

/// scene -> bloom -> composite -> final
class M3CompositePass {
  final renderEngine = M3AppEngine.instance.renderEngine;

  /// FBO render target
  late M3RenderTarget _target;
  M3Texture get texture => _target.texture;

  /// renderTarget from manager by key.
  M3CompositePass(String keyRt) {
    _target = renderEngine.renderTargets.get(keyRt);
  }
}
