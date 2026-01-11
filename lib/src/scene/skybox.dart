// Macbear3D engine
import '../../macbear_3d.dart';

/// A skybox rendered using a cubemap texture.
///
/// Renders a background environment that follows the camera position.
class M3Skybox {
  static RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  final M3Material mtr = M3Material();
  final M3Texture _texCubemap;

  M3Skybox(this._texCubemap) {
    mtr.texDiffuse = _texCubemap;
  }

  static Future<M3Skybox> createCubemap(
    String urlPosX,
    String urlNegX,
    String urlPosY,
    String urlNegY,
    String urlPosZ,
    String urlNegZ,
  ) async {
    final tex = await M3Texture.loadCubemap(urlPosX, urlNegX, urlPosY, urlNegY, urlPosZ, urlNegZ);
    return M3Skybox(tex);
  }

  void dispose() {
    _texCubemap.dispose();
  }

  bool drawSkybox(M3Camera camEye) {
    final prog = M3AppEngine.instance.renderEngine.programSkybox!;

    gl.depthMask(false);
    gl.disable(WebGL.DEPTH_TEST);
    gl.disable(WebGL.CULL_FACE);
    gl.disable(WebGL.BLEND);
    // pre-draw
    gl.useProgram(prog.program);

    final scale = camEye.farClip / 4;
    Matrix4 boxMatrix = Matrix4.identity();
    boxMatrix.setRotation(M3Constants.rotXNeg90.scaled(-scale));
    boxMatrix.setTranslation(camEye.position);

    prog.setMatrices(camEye, boxMatrix);
    prog.setMaterial(mtr, Vector4(1, 1, 1, 1));
    M3Resources.debugFrustum.draw(prog, bSolid: true);

    _texCubemap.unbind();
    return true;
  }
}
