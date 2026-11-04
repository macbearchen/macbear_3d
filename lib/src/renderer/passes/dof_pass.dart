// Macbear3D engine
import '../../m3_internal.dart';

/// Depth of Field (DOF) post-processing pass
class M3DofPass {
  final renderEngine = M3AppEngine.instance.renderEngine;

  /// FBO render target
  late M3RenderTarget _target;
  M3Texture get texture => _target.texture;

  /// DOF settings
  double focusDistance = 15.0;
  double focusRange = 5.0;
  double bokehRadius = 8.0;

  /// Initialize with render target key
  M3DofPass([String keyRt = 'dof']) {
    _target = renderEngine.renderTargets.get(keyRt);
  }

  /// Run DOF pass reading [srcColorTex] and [depthTex]
  void render(
    M3Texture srcColorTex,
    M3Texture depthTex, {
    required double near,
    required double far,
    double? focusDistance,
    double? focusRange,
    double? bokehRadius,
    bool toDefaultFramebuffer = false,
  }) {
    final gl = renderEngine.gl;

    gl.disable(WebGL.DEPTH_TEST);
    gl.disable(WebGL.CULL_FACE);
    gl.disable(WebGL.BLEND);

    if (toDefaultFramebuffer) {
      renderEngine.bindDefaultFramebuffer();
    } else {
      _target.bind();
    }

    M3PostProcess.drawDof(
      srcColorTex,
      depthTex,
      near: near,
      far: far,
      focusDistance: focusDistance ?? this.focusDistance,
      focusRange: focusRange ?? this.focusRange,
      bokehRadius: bokehRadius ?? this.bokehRadius,
    );
  }
}

