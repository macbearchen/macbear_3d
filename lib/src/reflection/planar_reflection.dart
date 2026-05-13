// Macbear3D engine
import '../m3_internal.dart';

class M3PlanarReflection {
  late M3Texture texReflection;
  late M3Framebuffer _fbo;

  Vector4 clipPlane = Vector4(0, 0, 1, 0);

  /// get reflection pixel size
  int get width => texReflection.texW;
  int get height => texReflection.texH;

  M3PlanarReflection(int width, int height) {
    _fbo = M3Framebuffer(width, height, useDepthTexture: false);
    texReflection = M3Texture.createEmpty2D(width, height);
  }

  void resize(int width, int height) {
    if (width == this.width && height == this.height) return;

    dispose();
    _fbo = M3Framebuffer(width, height, useDepthTexture: false);
    texReflection = M3Texture.createEmpty2D(width, height);
  }

  void dispose() {
    texReflection.dispose();
    _fbo.dispose();
  }

  /// Capture the scene by planar reflection.
  void capture(M3Scene scene) {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final gl = renderEngine.gl;

    final camReflect = scene.camera.clone();
    camReflect.reflectViewMatrix(clipPlane);
    // camReflect.setObliqueClipPlane(clipPlane);

    camReflect.setViewport(
      camReflect.viewportX,
      camReflect.viewportY,
      camReflect.viewportW,
      camReflect.viewportH,
      fovy: camReflect.degreeFovY,
      near: camReflect.nearClip,
      far: camReflect.farClip,
    );

    _fbo.bindFace(WebGL.TEXTURE_2D, texReflection.glTexture);
    // Clear
    final bg = M3AppEngine.backgroundColor;
    gl.clearColor(bg.r, bg.g, bg.b, 1.0);
    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);

    if (scene.skybox != null) {
      scene.skybox!.drawSkybox(camReflect);
    }

    // GL state
    gl.frontFace(WebGL.CW); // Reversed winding order for reflection
    gl.enable(WebGL.CULL_FACE);
    gl.enable(WebGL.DEPTH_TEST);

    gl.depthMask(true);
    gl.depthFunc(WebGL.LEQUAL);

    gl.enable(WebGL.BLEND);
    gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA); // WebGL.ONE

    final prog = M3Resources.programTexture!;
    prog.applyLight(scene.light);

    scene.render(prog, camReflect);

    texReflection.generateMipmap();

    gl.frontFace(WebGL.CCW); // Restore
    renderEngine.bindDefaultFramebuffer();
  }

  /// Draw reflection map for debugging
  void drawDebugReflection(double x, double y, double width, double height) {
    Matrix4 matRect = Matrix4.identity();
    matRect.setTranslation(Vector3(x, y, 0.0));
    final scale = Vector3(width / this.width, height / this.height, 1.0);
    matRect.scaleByVector3(scale);
    // use depth texture from shadow buffer
    M3Shape2D.drawImage(texReflection, matRect);
  }
}
