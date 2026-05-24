// Macbear3D engine
import '../m3_internal.dart';

class M3PlanarReflection {
  final M3RenderContext _context = M3RenderContext();
  late M3Framebuffer _fbo;
  late M3Texture _texture;

  /// get reflection pixel size
  int get width => _texture.texW;
  int get height => _texture.texH;
  M3Texture get texture => _texture;

  final Plane clipPlane = Plane.components(0, 0, 1, 0);
  final M3Camera _camera = M3Camera(); // reflection camera to render reflection

  bool visible = true;

  /// Get the mathematically correct maximum mipmap level based on dimensions
  int get maxMipLevel => _texture.maxMipLevel;
  double _sizeScale;

  /// width / height: default size of reflection image
  /// resolutionScale: scale ratio of width and height
  M3PlanarReflection({int width = 16, int height = 16, double resolutionScale = 0.5}) : _sizeScale = resolutionScale {
    assert(resolutionScale > 0 && resolutionScale <= 1.0);
    _fbo = M3Framebuffer(width, height, useDepthTexture: false);
    _texture = M3Texture.createEmpty2D(width, height);
  }

  void setScale(double scale) {
    assert(scale > 0 && scale <= 1.0);
    _sizeScale = scale;
    resize(width, height);
  }

  /// Resize reflection image, size is based on display size
  void resize(int width, int height) {
    width = (width * _sizeScale).toInt();
    height = (height * _sizeScale).toInt();
    if (width == this.width && height == this.height) return;

    dispose();
    _fbo = M3Framebuffer(width, height, useDepthTexture: false);
    _texture = M3Texture.createEmpty2D(width, height);
  }

  void dispose() {
    _texture.dispose();
    _fbo.dispose();
  }

  /// Capture the scene by planar reflection (renders above the plane).
  void captureReflection(M3Scene scene) {
    // visible only when camera is above the plane
    final dist = clipPlane.distanceToVector3(scene.camera.position);
    visible = dist > 0.01;
    if (!visible) return;

    _camera.setFrom(scene.camera);
    _camera.reflectViewMatrix(clipPlane);

    _camera.updateClipSpace(clipPlane);
    _renderToTexture(scene, _camera, WebGL.CW); // reversed winding for mirrored view
  }

  /// Capture the scene by planar refraction (renders below the plane).
  void captureRefraction(M3Scene scene) {
    // visible only when camera is above the plane
    final dist = clipPlane.distanceToVector3(scene.camera.position);
    visible = dist > 0.01;
    if (!visible) return;

    _camera.setFrom(scene.camera);
    // negate the plane so the oblique clip removes geometry above the water
    final belowPlane = Plane.normalconstant(-clipPlane.normal, -clipPlane.constant);

    _camera.updateClipSpace(belowPlane);
    _renderToTexture(scene, _camera, WebGL.CCW); // normal winding — no view flip
  }

  /// Render the scene to [_texture] using [cam], with the given [frontFace] winding.
  void _renderToTexture(M3Scene scene, M3Camera cam, int frontFace) {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final gl = renderEngine.gl;

    _fbo.bindFace(WebGL.TEXTURE_2D, _texture.glTexture);
    // Clear
    final bg = Vector3(0, 0, 0);
    gl.clearColor(bg.r, bg.g, bg.b, 1.0);
    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);

    if (scene.skybox != null) {
      scene.skybox!.drawSkybox(cam);
    }

    // GL state
    gl.frontFace(frontFace);
    gl.enable(WebGL.CULL_FACE);
    gl.enable(WebGL.DEPTH_TEST);

    gl.depthMask(true);
    gl.depthFunc(WebGL.LEQUAL);

    gl.enable(WebGL.BLEND);
    gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA); // WebGL.ONE

    gl.enable(WebGL.POLYGON_OFFSET_FILL);
    gl.polygonOffset(1.1, 4.0);

    final prog = M3Resources.programTexture!;
    prog.applyLight(scene.light);

    // render scene for planar reflection/refraction
    _context.prepareRenderQueue(scene, cam);
    _context.excludePlane(this); // Exclude this plane during rendering.
    _context.render(prog);

    _texture.generateMipmap();

    gl.frontFace(WebGL.CCW); // Restore
    gl.polygonOffset(0, 0);
    gl.disable(WebGL.POLYGON_OFFSET_FILL);
    renderEngine.bindDefaultFramebuffer();
  }

  /// draw helper
  void drawHelper(M3Camera viewer) {
    if (visible) {
      _camera.drawHelper(M3Resources.programSimple!, viewer);
    }
  }

  /// Draw reflection map for debugging
  void drawDebugReflection(double x, double y, double width, double height) {
    Matrix4 matRect = Matrix4.identity();
    matRect.setTranslation(Vector3(x, y, 0.0));
    final scale = Vector3(width / this.width, height / this.height, 1.0);
    matRect.scaleByVector3(scale);
    // use depth texture from shadow buffer
    M3Shape2D.drawImage(_texture, matRect);
  }
}
