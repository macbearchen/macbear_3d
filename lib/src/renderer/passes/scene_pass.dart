// Macbear3D engine
import '../../m3_internal.dart';

/// scene render pass
class M3ScenePass {
  final renderEngine = M3AppEngine.instance.renderEngine;

  /// FBO render target
  late M3RenderTarget _target;
  M3Texture get texture => _target.texture;

  /// renderTarget from manager by key.
  M3ScenePass(String keyRt) {
    _target = renderEngine.renderTargets.get(keyRt);
  }

  /// main scene render
  void render(M3Scene scene) {
    _target.bind();

    final gl = renderEngine.gl;
    final bg = M3AppEngine.backgroundColor;
    renderEngine.clearBackground(bg);

    // draw skybox
    if (scene.skybox != null) {
      scene.skybox!.drawSkybox(scene.camera);
    }

    // set default GL state
    gl.frontFace(WebGL.CCW);
    gl.enable(WebGL.CULL_FACE);
    gl.enable(WebGL.DEPTH_TEST);
    gl.depthMask(true);
    gl.depthFunc(WebGL.LEQUAL);

    gl.disable(WebGL.BLEND);
    gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA); // WebGL.ONE

    if (!renderEngine.options.debug.wireframe) {
      // get scene program
      final prog = renderEngine.getSceneProgram(scene);

      // main context render pass
      renderEngine.mainContext.renderColorPass(prog);

      // reflection pass:
      // 1. cubemap reflection (only if not using single-pass IBL)
      // 2. planar reflection
      renderEngine.mainContext.renderReflectionPass();

      // post render water
      scene.water?.render();
    } else {
      // wireframe
      renderEngine.mainContext.renderWireframePass();
      // water wireframe
      scene.water?.render(fillMode: .wireframe);
    }

    // helper
    _renderHelper(scene);

    // bind default framebuffer
    renderEngine.bindDefaultFramebuffer();

    // draw fullscreen
    M3PostProcess.drawFullscreen(_target.texture);
  }

  void _renderHelper(M3Scene scene) {
    final progSimple = renderEngine.programs.programSimple;

    // draw debug: only implement when needed
    scene.debugDraw();

    final debugOptions = renderEngine.options.debug;

    // draw Helper
    if (debugOptions.showHelpers != M3HelperType.none) {
      scene.drawHelper(debugOptions.showHelpers);
    }

    // draw camera frustums
    if (debugOptions.showCamera) {
      scene.drawCameraHelper();
      // for debug camera frustum only
      M3Resources.debugCamera?.drawHelper(progSimple, scene.camera);

      if (renderEngine.mainContext.needsPlanarReflectionPass()) {
        // renderEngine.planarReflection.drawReflectionCamera(scene.camera); // remark for ignore
      }
    }

    // draw light helper
    if (debugOptions.showLight) {
      if (M3Resources.debugCamera != null) {
        // for debug directional light frustum only
        scene.dirLight.updateShadowCascades(M3Resources.debugCamera!);
      }
      scene.dirLight.drawHelper(progSimple, scene.camera);
      scene.drawLightHelper(drawBulb: false);
    }
    if (debugOptions.lightBulb) {
      scene.drawLightHelper();
    }
  }
}
