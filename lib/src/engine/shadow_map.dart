// Macbear3D engine
import '../../macbear_3d.dart';
import 'framebuffer.dart';

/// Shadow map renderer for real-time shadows from directional lights.
///
/// Renders the scene from the light's perspective to generate a depth texture.
class M3ShadowMap {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;
  static final _prog = M3AppEngine.instance.renderEngine.programSimple!;

  late M3Framebuffer shadowBuffer;
  Matrix4 matShadow = Matrix4.identity();
  WebGLTexture get depthTexture => shadowBuffer.depthTexture;
  M3Sprite2D? _sprite;

  // depth image for debug
  M3Sprite2D get depthImage {
    if (_sprite == null) {
      M3Texture texDepth = M3Texture.fromWebGLTexture(
        depthTexture,
        texW: shadowBuffer.frameW,
        texH: shadowBuffer.frameH,
      );
      _sprite = M3Sprite2D(texDepth);
    }
    return _sprite!;
  }

  M3ShadowMap(int width, int height) {
    debugPrint('create M3ShadowMap: $width x $height');
    shadowBuffer = M3Framebuffer(width, height);
  }

  void dispose() {
    shadowBuffer.dispose();
  }

  void renderDepthPass(M3Scene scene, M3Light light) {
    shadowBuffer.bind();
    gl.clear(WebGL.DEPTH_BUFFER_BIT);
    gl.disable(WebGL.BLEND);
    gl.enable(WebGL.POLYGON_OFFSET_FILL);
    // render back-face to avoid shadow acne
    gl.frontFace(WebGL.CW);
    gl.polygonOffset(.3, .2);

    scene.render(_prog, light);

    gl.frontFace(WebGL.CCW);
    gl.polygonOffset(0, 0);
    gl.disable(WebGL.POLYGON_OFFSET_FILL);
    gl.enable(WebGL.BLEND);

    // recover to default FBO
    M3AppEngine.instance.renderEngine.bindDefaultFramebuffer();
  }

  void drawDebugDepth(double x, double y, double width, double height) {
    // use depth texture from shadow buffer
    final M3Texture texDepth = depthImage.mtr.texDiffuse;

    // draw small quad at bottom-left
    Matrix4 matRect = Matrix4.identity();
    matRect.setTranslation(Vector3(x, y, 0.0));
    // size 200x200
    final scale = Vector3(width / texDepth.texW, height / texDepth.texH, 1.0);
    matRect.scaleByVector3(scale);
    depthImage.draw(matRect);
    // M3Shape2D.drawImage(texDepth, matRect);
  }
}
