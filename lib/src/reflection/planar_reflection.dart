// Macbear3D engine
import '../m3_internal.dart';

enum M3PlanarPass { reflection, refraction }

class M3PlanarReflection {
  final renderEngine = M3AppEngine.instance.renderEngine;
  final M3RenderContext _context = M3RenderContext();

  /// FBO render target
  late M3RenderTarget _target;
  M3Texture get texture => _target.texture;

  final Plane clipPlane = Plane.components(0, 0, 1, 0);
  final M3Camera _camera = M3Camera(); // reflection camera to render reflection
  final double farClipRatio = 2.0 / 3.0;

  bool enable = true;
  bool visible = true;

  /// renderTarget from manager by key.
  M3PlanarReflection(String keyRt) {
    _target = renderEngine.renderTargets.get(keyRt);
  }

  void dispose() {}

  /// Capture the scene by planar:
  /// - reflection: render above the plane
  /// - refraction: render below the plane
  void capture(M3Scene scene, M3PlanarPass pass) {
    if (!enable) return;
    // visible only when camera is above the plane
    final dist = clipPlane.distanceToVector3(scene.camera.position);
    visible = dist > 0.01;
    if (!visible) return;

    _camera.setFrom(scene.camera);

    // shrink far clip for culling shadow casters
    _camera.farClip *= farClipRatio;
    _camera.refreshProjectionMatrix();
    _camera.updateSplitDistances();

    if (pass == M3PlanarPass.reflection) {
      // reversed winding for mirrored view
      _camera.reflectViewMatrix(clipPlane);
    } else {
      // normal winding — no view flip
    }

    _renderToTexture(scene, pass);
  }

  // Render the scene to [_texture]
  // reflection pass: render above water (mirror)
  // refraction pass: render below water (inside water)
  void _renderToTexture(M3Scene scene, M3PlanarPass pass) {
    final gl = renderEngine.gl;

    // Bind FBO, then attach texture face
    _target.bind();

    // Clear
    final bg = Vector3(1, 1, 1);
    renderEngine.clearBackground(bg);

    // draw skybox
    if (scene.skybox != null && pass == .reflection) {
      scene.skybox!.drawSkybox(_camera);
    }

    // oblique clip:
    // reflection: clip geometry below the water, use original plane
    // refraction: clip geometry above the water, use negated plane
    final bool isReflection = pass == M3PlanarPass.reflection;
    final n = clipPlane.normal;
    final bias = -0.1;
    final d = clipPlane.constant - bias;
    final p = isReflection ? Plane.normalconstant(n, d) : Plane.normalconstant(-n, -d);
    _camera.setObliqueClipPlane(p);
    _camera.updateFrustum();
    _context.prepareRenderQueue(scene, _camera, excludeReflection: this);

    final int frontFace = isReflection ? WebGL.CW : WebGL.CCW;

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

    // get scene program
    final prog = renderEngine.getSceneProgram(scene);

    // render scene for planar reflection/refraction
    _context.renderColorPass(prog);

    _target.texture.generateMipmap();

    gl.frontFace(WebGL.CCW); // Restore
    gl.polygonOffset(0, 0);
    gl.disable(WebGL.POLYGON_OFFSET_FILL);
    renderEngine.bindDefaultFramebuffer();
  }

  /// draw reflection camera
  void drawReflectionCamera(M3Camera viewer) {
    if (!enable || !visible) return;

    M3Camera mirrorCamera = _camera;
    if (M3Resources.debugCamera != null) {
      mirrorCamera = M3Resources.debugCamera!.clone();
      // shrink far clip for culling shadow casters
      mirrorCamera.farClip *= farClipRatio;
      mirrorCamera.refreshProjectionMatrix();
      mirrorCamera.updateSplitDistances();

      // reversed winding for mirrored view
      mirrorCamera.reflectViewMatrix(clipPlane);
      mirrorCamera.setObliqueClipPlane(clipPlane);
      mirrorCamera.updateFrustum();
    }
    mirrorCamera.drawHelper(renderEngine.programs.programSimple, viewer);
  }

  /// Draw reflection map for debugging
  void debugDrawReflection(double x, double y, double scale) {
    if (!enable || !visible) return;

    _target.texture.debugDraw(x, y, scale, scale);
  }
}
