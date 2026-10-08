// Macbear3D engine
import '../../m3_internal.dart';

import '../../shaders_gen/post/Fullscreen.es3.frag.g.dart';
import '../../shaders_gen/post/Fullscreen.es3.vert.g.dart';

class M3PostProcess {
  static RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;
  // dummy VAO for ES3; otherwise WebGL errors if no VAO is bound when drawing
  static VertexArrayObject emptyVao = gl.createVertexArray();

  // post processing
  static M3Program programFullscreen = M3Program(Fullscreen_vert, Fullscreen_frag)..name = 'Fullscreen';
  static void init() {
    emptyVao;
    programFullscreen;

    M3Log.i('M3PostProcess', 'init done');
  }

  static void dispose() {
    gl.deleteVertexArray(emptyVao);

    // post processing programs
    programFullscreen.dispose();
  }

  static void drawFullscreen(M3Texture tex) {
    gl.useProgram(programFullscreen.program);

    gl.activeTexture(WebGL.TEXTURE0);
    tex.bind();
    gl.bindVertexArray(emptyVao); // ES3 needs a VAO bound, no attribs
    gl.drawArrays(WebGL.TRIANGLES, 0, 3);

    gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
  }
}
