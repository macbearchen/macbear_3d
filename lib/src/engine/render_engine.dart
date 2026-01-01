// Macbear3D engine
import '../../macbear_3d.dart';
import '../shaders_gen/Rect.es2.frag.g.dart';
import '../shaders_gen/Rect.es2.vert.g.dart';
import '../shaders_gen/Simple.es2.frag.g.dart';
import '../shaders_gen/Simple.es2.vert.g.dart';
import '../shaders_gen/SimpleLighting.es2.vert.g.dart';
import '../shaders_gen/Skinning.es2.vert.g.dart';
import '../shaders_gen/Skybox.es2.frag.g.dart';
import '../shaders_gen/Skybox.es2.vert.g.dart';
import '../shaders_gen/TexturedLighting.es2.frag.g.dart';
import '../shaders_gen/TexturedLighting.es2.vert.g.dart';

import 'shadow_map.dart';

class M3RenderOptions {
  bool wireframe = false;
  bool helpers = false;
  bool shadows = true;
  bool showFPS = true;
}

class M3RenderEngine {
  late RenderingContext gl;
  final Framebuffer defaultFBO = Framebuffer(0); // default framebuffer

  M3Program? programSimple;
  M3Program? programRectangle;
  M3ProgramLighting? programSimpleLighting;
  M3ProgramLighting? programTexture;
  M3ProgramLighting? programShadowmap;
  M3Program? programSkybox;

  // shadow map
  M3ShadowMap? _shadowMap;

  // helper for 2D rendering
  late M3Text2D text2D;

  // for ortho-matrix to project to 2D screen
  final _projection2D = M3Projection();

  // render flags
  M3RenderOptions options = M3RenderOptions();

  // constructor
  M3RenderEngine() {
    debugPrint("--- M3RenderEngine constructor ---");
  }

  void dispose() {
    programSimple?.dispose();
    programRectangle?.dispose();
    programSimpleLighting?.dispose();
    programTexture?.dispose();
    programShadowmap?.dispose();

    _shadowMap?.dispose();
    text2D.dispose();
  }

  void getExtensions() {
    // 取得 WebGL context
    // final a = WebGLParameter(WebGL.RENDERER);
    // final b = WebGLParameter(WebGL.VENDOR);
    // final c = WebGLParameter(WebGL.VERSION);
    // 取出基本資訊
    // final renderer = gl.getParameter(WebGL.RENDERER);
    // final vendor = gl.getParameter(WebGL.VENDOR);
    // final version = gl.getParameter(WebGL.VERSION);
    // final shadingLang = gl.getParameter(WebGL.SHADING_LANGUAGE_VERSION);
    // print('GL_VENDOR: $vendor');
    // print('GL_RENDERER: $renderer');
    // print('GL_VERSION: $version');
    // print('GL_SHADING_LANGUAGE_VERSION: $shadingLang');

    List<int> paramKeys = [
      WebGL.MAX_TEXTURE_IMAGE_UNITS,
      WebGL.MAX_VERTEX_TEXTURE_IMAGE_UNITS,
      WebGL.MAX_TEXTURE_SIZE,
      WebGL.MAX_CUBE_MAP_TEXTURE_SIZE,
      WebGL.MAX_VERTEX_ATTRIBS,
      WebGL.MAX_VERTEX_UNIFORM_VECTORS,
      WebGL.MAX_VARYING_VECTORS,
      WebGL.MAX_FRAGMENT_UNIFORM_VECTORS,
      WebGL.MAX_SAMPLES,
      WebGL.MAX_COMBINED_TEXTURE_IMAGE_UNITS,
      WebGL.SCISSOR_BOX,
      WebGL.VIEWPORT,
      WebGL.MAX_TEXTURE_MAX_ANISOTROPY_EXT,
      WebGL.MAX_UNIFORM_BUFFER_BINDINGS,
    ];
    for (final key in paramKeys) {
      int val = gl.getParameter(key);
      debugPrint("GL Int[$key] = $val");
    }
    for (int i = 0; i < 150; i++) {
      final s0 = gl.getStringi(WebGL.EXTENSIONS, i);
      debugPrint("GL [$i] = $s0");
      if (s0 == 'unnamed') {
        break;
      }
    }
  }

  Future<void> initProgram() async {
    // getExtensions();

    // simple program
    programSimple = M3Program(Simple_es2_vert, Simple_es2_frag);

    // skybox program
    programSkybox = M3Program(Skybox_es2_vert, Skybox_es2_frag);

    // simple lighting program
    programSimpleLighting = M3ProgramLighting(SimpleLighting_es2_vert, Simple_es2_frag);

    // rectangle program
    programRectangle = M3Program(Rect_es2_vert, Rect_es2_frag);

    final String strSkin = Skinning_es2_vert;
    // texture lighting program
    String strVert = TexturedLighting_es2_vert;
    strVert = strSkin + strVert;
    String strFrag = TexturedLighting_es2_frag;
    // pixel lighting: phong shading, cartoon
    bool bPerPixel = false;
    bool bCartoon = false;
    if (bPerPixel) {
      strVert = "#define ENABLE_PIXEL_LIGHTING \n$strVert";
      strFrag = "#define ENABLE_PIXEL_LIGHTING \n$strFrag";
      if (bCartoon) {
        strFrag = "#define ENABLE_CARTOON \n$strFrag";
      }
    }
    programTexture = M3ProgramLighting(strVert, strFrag);

    // shadow map program
    strVert = "#define ENABLE_SHADOW_MAP \n$strVert";
    strFrag = "#define ENABLE_SHADOW_MAP \n$strFrag";
    strFrag = "#define ENABLE_PCF \n$strFrag";
    programShadowmap = M3ProgramLighting(strVert, strFrag);

    // init text2D
    text2D = await M3Text2D.createText2D(fontSize: 30);

    gl.lineWidth(2.0);
  }

  void createShadowMap({int width = 1024, int height = 1024}) {
    _shadowMap ??= M3ShadowMap(width, height);
  }

  void bindDefaultFramebuffer() {
    final engine = M3AppEngine.instance;
    final pixelW = (engine.appWidth * engine.devicePixelRatio).toInt();
    final pixelH = (engine.appHeight * engine.devicePixelRatio).toInt();
    gl.bindFramebuffer(WebGL.FRAMEBUFFER, defaultFBO);
    gl.viewport(0, 0, pixelW, pixelH);
  }

  void setViewport(int width, int height, double dpr) {
    debugPrint("=== Viewport ($width x $height) dpr: $dpr ===");

    final pixelW = (width * dpr).toInt();
    final pixelH = (height * dpr).toInt();
    gl.viewport(0, 0, pixelW, pixelH);
    // camera viewport by pixel size
    M3AppEngine.instance.activeScene?.camera.setViewport(0, 0, pixelW, pixelH);

    // projection 2D viewport by screen size
    _projection2D.setViewport(0, height, width, -height, fovy: 0, near: -1.0, far: 1.0);
    gl.lineWidth(dpr * 2.0);
  }

  void renderScene(M3Scene scene) {
    // draw skybox
    if (scene.skybox != null) {
      scene.skybox!.drawSkybox(scene.camera);
    }

    // set default GL state
    gl.frontFace(WebGL.CCW);
    gl.enable(WebGL.DEPTH_TEST);
    gl.enable(WebGL.CULL_FACE);
    gl.depthMask(true);
    gl.depthFunc(WebGL.LEQUAL);

    gl.enable(WebGL.BLEND);
    gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA); // WebGL.ONE

    M3ProgramLighting progLight = programTexture!; // texture shader

    if (!options.wireframe) {
      // Render Shadow Map
      if (options.shadows && _shadowMap != null) {
        _shadowMap!.renderDepthPass(scene, scene.light);

        progLight = programShadowmap!;

        // active shadowmap
        gl.activeTexture(WebGL.TEXTURE1);
        gl.bindTexture(WebGL.TEXTURE_2D, _shadowMap!.depthTexture);
        gl.uniform1i(progLight.uniformSamplerShadowmap, 1);

        gl.activeTexture(WebGL.TEXTURE0);
      }

      progLight.useLight(scene.light);
      scene.render(progLight, scene.camera, bSolid: true);
    } else {
      scene.renderWireframe();
    }

    // draw Helper
    if (options.helpers) {
      scene.renderHelper();
    }
  }

  void render2D() {
    // ortho-param: left, right, top, bottom, near, far (flip Y-axis by swap top/bottom)
    gl.disable(WebGL.DEPTH_TEST);
    gl.disable(WebGL.CULL_FACE);
    gl.enable(WebGL.BLEND);
    gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA);

    final prog2D = programRectangle!;
    gl.useProgram(prog2D.program);
    prog2D.setProjectionMatrix(_projection2D.projectionMatrix);

    gl.enableVertexAttribArray(prog2D.attribVertex.id);
    gl.enableVertexAttribArray(prog2D.attribUV.id);

    // draw rectangle full-screen
    final engine = M3AppEngine.instance;
    if (engine.activeScene != null) {
      engine.activeScene!.render2D();
    }

    // 2D helper
    Matrix4 matIdentity = Matrix4.identity();
    if (options.helpers) {
      if (options.shadows && _shadowMap != null) {
        _shadowMap!.drawDebugDepth(10, engine.appHeight - 210, 200, 200);
      }

      prog2D.setModelViewMatrix(matIdentity);

      // draw test: triangle, line, touches
      M3Shape2D.drawTouches(engine.touchManager);
    }
    // Draw FPS counter
    if (options.showFPS) {
      Matrix4 matFps = Matrix4.identity();
      matFps.setTranslation(Vector3(M3AppEngine.instance.appWidth - 50, 40, 0));
      matFps.scaleByVector3(Vector3.all(0.5));
      final fpsText = engine.fps.toStringAsFixed(1);
      text2D.drawText(fpsText, matFps, color: Vector4(0, 1, 0, 1));
    }

    prog2D.disableAttribute();
  }
}
