// Macbear3D engine
import '../m3_internal.dart';

class M3ReflectionProbe {
  final _camCapture = M3Camera();
  M3Entity? excludeEntity; // ignore capture entity

  int texSize = 128;
  M3Texture? texCubemap;
  M3Framebuffer? _fbo;
  bool isMirror = true;

  M3ReflectionProbe({this.texSize = 128, this.isMirror = true, double near = 0.1, double far = 200.0}) {
    // Temporary camera with 90 degree FOV
    _camCapture.csmCount = 0;
    _camCapture.setViewport(0, 0, texSize, texSize, fovy: 90.0, near: near, far: far);
    _fbo ??= M3Framebuffer(texSize, texSize, useDepthTexture: false);
    texCubemap ??= M3Texture.createEmptyCubemap(texSize);
  }

  void dispose() {
    _fbo?.dispose();
    _fbo = null;
    texCubemap?.dispose();
    texCubemap = null;
  }

  /// Capture the scene from the probe's position into a cubemap texture.
  void capture(M3Scene scene, Vector3 position) {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final gl = renderEngine.gl;

    double mirrorX = isMirror ? -1 : 1;
    final targets = [
      Vector3(mirrorX, 0, 0),
      Vector3(-mirrorX, 0, 0),
      Vector3(0, 0, 1),
      Vector3(0, 0, -1),
      Vector3(0, -1, 0),
      Vector3(0, 1, 0),
    ];
    final ups = [
      Vector3(0, 0, -1),
      Vector3(0, 0, -1),
      Vector3(0, -1, 0),
      Vector3(0, 1, 0),
      Vector3(0, 0, -1),
      Vector3(0, 0, -1),
    ];
    final faces = [
      WebGL.TEXTURE_CUBE_MAP_POSITIVE_X,
      WebGL.TEXTURE_CUBE_MAP_NEGATIVE_X,
      WebGL.TEXTURE_CUBE_MAP_POSITIVE_Y,
      WebGL.TEXTURE_CUBE_MAP_NEGATIVE_Y,
      WebGL.TEXTURE_CUBE_MAP_POSITIVE_Z,
      WebGL.TEXTURE_CUBE_MAP_NEGATIVE_Z,
    ];

    final prog = M3Resources.programTexture!;
    prog.applyLight(scene.light);

    for (int i = 0; i < 6; i++) {
      // Bind face
      _fbo!.bindFace(faces[i], texCubemap!.glTexture);

      // Clear
      final bg = M3AppEngine.backgroundColor;
      gl.clearColor(bg.r, bg.g, bg.b, 1.0);
      gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);

      // Setup camera
      _camCapture.setLookat(position, position + targets[i], ups[i]);

      if (isMirror) {
        _camCapture.refreshProjectionMatrix();
        _camCapture.projectionMatrix.scaleByVector3(Vector3(-1, 1, 1));
      }

      // Render skybox
      if (scene.skybox != null) {
        scene.skybox!.drawSkybox(_camCapture);
      }
      // set default GL state
      gl.frontFace(isMirror ? WebGL.CW : WebGL.CCW);
      gl.enable(WebGL.CULL_FACE);
      gl.enable(WebGL.DEPTH_TEST);
      gl.depthMask(true);
      gl.depthFunc(WebGL.LEQUAL);

      gl.enable(WebGL.BLEND);
      gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA); // WebGL.ONE

      // ignore entity
      if (excludeEntity != null) {
        scene.entities.remove(excludeEntity!);
      }
      // Render scene
      scene.render(prog, _camCapture, bSolid: true);

      if (excludeEntity != null) {
        scene.entities.add(excludeEntity!);
      }
    }
    texCubemap!.generateMipmap();
    // Restore state
    renderEngine.bindDefaultFramebuffer();
  }
}
