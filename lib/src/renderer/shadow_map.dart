// Macbear3D engine
import '../m3_internal.dart';

/// Shadow map renderer for real-time shadows from directional lights.
///
/// Renders the scene from the light's perspective to generate a depth texture.
class M3ShadowMap {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;
  final M3RenderContext _context = M3RenderContext();

  final M3Framebuffer _framebuffer;
  int get mapW => _framebuffer.frameW;
  int get mapH => _framebuffer.frameH;
  M3Texture get depthTex => _framebuffer.depthTexture;

  M3ShadowMap(int width, int height) : _framebuffer = M3Framebuffer(width, height)..createDepthTexture() {
    M3Log.i('M3ShadowMap', 'create FBO: $width x $height');
  }

  @override
  String toString() {
    return '$mapW*$mapH';
  }

  void dispose() {
    _framebuffer.dispose();
  }

  // ---------------------------------------------------------------------------
  // Private GL state helpers
  // ---------------------------------------------------------------------------

  /// Bind FBO and configure GL state for depth-only rendering.
  void _beginShadowPass() {
    _framebuffer.bind();
    gl.frontFace(WebGL.CCW);
    gl.enable(WebGL.CULL_FACE);
    gl.enable(WebGL.DEPTH_TEST);
    gl.depthMask(true);
    gl.depthFunc(WebGL.LEQUAL);
    gl.disable(WebGL.BLEND);
    gl.enable(WebGL.POLYGON_OFFSET_FILL);
    // positive offset to avoid shadow acne
    gl.polygonOffset(1.1, 4.0);
    gl.clear(WebGL.DEPTH_BUFFER_BIT);
  }

  /// Restore default GL state and rebind the default framebuffer.
  void _endShadowPass() {
    final renderEngine = M3AppEngine.instance.renderEngine;

    gl.polygonOffset(0, 0);
    gl.disable(WebGL.POLYGON_OFFSET_FILL);
    gl.enable(WebGL.BLEND);
    renderEngine.bindDefaultFramebuffer();
  }

  // ---------------------------------------------------------------------------
  // Public rendering API
  // ---------------------------------------------------------------------------

  /// Render depth map from directional light's perspective.
  void renderDepth(M3Scene scene, M3DirectionalLight light) {
    final prog = M3Resources.programSimple!;

    _beginShadowPass();

    light.updateShadowCascades(scene.cameras[0]);
    final lightViewer = light.lightViewer;

    // check if use cascaded shadow map
    if (light.cascades.isNotEmpty) {
      // cascaded shadow mapping
      final backupMatrix = lightViewer.projectionMatrix;
      for (final cascade in light.cascades) {
        // viewport for the cascaded-shadow
        final int y = (cascade.atlasBiasV * mapH).toInt();
        final int height = (cascade.atlasScaleV * mapH).toInt();
        gl.viewport(0, y, mapW, height);
        lightViewer.projectionMatrix = cascade.projectionMatrix;
        // frustum matrix for culling
        lightViewer.updateFrustum();
        // shadowmap render scene only opaque
        _context.prepareRenderQueue(scene, lightViewer, bOnlyOpaque: true);
        _context.render(prog);
      }
      lightViewer.projectionMatrix = backupMatrix;
      lightViewer.updateFrustum();
    } else {
      // directional light without shadow cascades
      lightViewer.updateFrustum();
      _context.prepareRenderQueue(scene, lightViewer, bOnlyOpaque: true);
      _context.render(prog);
    }

    _endShadowPass();
  }

  /// Render depth map for multiple spotlights into atlas.
  void renderSpotDepths(M3Scene scene, List<M3SpotLight> lights) {
    final active = lights.take(8).toList();
    if (!active.any((l) => l.castShadow)) return;

    final prog = M3Resources.programSimple!;

    _beginShadowPass();

    final int tileSize = mapH ~/ 8;

    for (int i = 0; i < active.length; i++) {
      final light = active[i];
      if (!light.castShadow) continue;

      gl.viewport(0, i * tileSize, mapW, tileSize);
      light.updateLightViewer();
      final lightViewer = light.lightViewer;
      lightViewer.updateFrustum();

      _context.prepareRenderQueue(scene, lightViewer, bOnlyOpaque: true);
      _context.render(prog);
    }

    _endShadowPass();
  }

  /// Draw shadow depth map for debugging
  void debugDrawDepth(double x, double y, double width, double height) {
    M3Texture depthTex = _framebuffer.depthTexture;
    // size 200x200
    final scale = Vector3(width / depthTex.texW, height / depthTex.texH, 1.0);
    depthTex.debugDraw(x, y, scale.x, scale.y);
  }
}
