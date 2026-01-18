// Macbear3D engine
import '../../macbear_3d.dart';
import 'framebuffer.dart';

/// Shadow map renderer for real-time shadows from directional lights.
///
/// Renders the scene from the light's perspective to generate a depth texture.
class M3ShadowMap {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;
  static final _prog = M3AppEngine.instance.renderEngine.programSimple!;

  final M3Framebuffer _framebuffer;
  int get mapW => _framebuffer.frameW;
  int get mapH => _framebuffer.frameH;
  WebGLTexture get depthTexture => _framebuffer.depthTexture;
  M3Texture? _tex;
  M3Texture get texDepth {
    return _tex ??= M3Texture.fromWebGLTexture(depthTexture, texW: mapW, texH: mapH);
  }

  M3ShadowMap(int width, int height) : _framebuffer = M3Framebuffer(width, height) {
    debugPrint('create M3ShadowMap: $width x $height');
  }

  void dispose() {
    _tex?.dispose();
    _framebuffer.dispose();
  }

  void renderDepthPass(M3Scene scene, M3Light light) {
    _framebuffer.bind();
    gl.clear(WebGL.DEPTH_BUFFER_BIT);
    gl.disable(WebGL.BLEND);
    gl.enable(WebGL.POLYGON_OFFSET_FILL);
    // render front-face and positive offset to avoid shadow acne
    // gl.frontFace(WebGL.CCW);
    // gl.polygonOffset(.3, .2);
    gl.polygonOffset(1.1, 4.0);

    if (light.isDirectional) {
      light.updateShadowCascades(scene.cameras[0]);
    }
    // check if use cascaded shadow map
    if (light.cascades.isNotEmpty) {
      // cascaded shadow mapping
      final backupMatrix = light.projectionMatrix;
      for (final cascade in light.cascades) {
        // viewport for the cascaded-shadow
        final int y = (cascade.atlasBiasV * mapH).toInt();
        final int height = (cascade.atlasScaleV * mapH).toInt();
        gl.viewport(0, y, mapW, height);
        light.projectionMatrix = cascade.projectionMatrix;
        // frustum matrix for culling
        light.updateFrustum(light.projectionMatrix * light.viewMatrix);
        // render scene
        scene.render(_prog, light);
      }
      light.projectionMatrix = backupMatrix;
      light.updateFrustum(light.projectionMatrix * light.viewMatrix);
    } else {
      scene.render(_prog, light);
    }

    gl.polygonOffset(0, 0);
    gl.disable(WebGL.POLYGON_OFFSET_FILL);
    gl.enable(WebGL.BLEND);

    // recover to default FBO
    M3AppEngine.instance.renderEngine.bindDefaultFramebuffer();
  }

  void drawDebugDepth(double x, double y, double width, double height) {
    Matrix4 matRect = Matrix4.identity();
    matRect.setTranslation(Vector3(x, y, 0.0));
    // size 200x200
    final scale = Vector3(width / texDepth.texW, height / texDepth.texH, 1.0);
    matRect.scaleByVector3(scale);
    // use depth texture from shadow buffer
    M3Shape2D.drawImage(texDepth, matRect);
  }
}
