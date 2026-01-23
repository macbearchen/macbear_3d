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

/// Rendering options for the engine (wireframe, helpers, shadows, FPS display).
class M3RenderOptions {
  // debug options
  M3DebugOptions debug = M3DebugOptions();
  // shader options
  M3ShaderOptions shader = M3ShaderOptions();
  bool shadows = true;
}

class M3DebugOptions {
  bool wireframe = false;
  bool showHelpers = false;
  bool showStats = true;
  bool showPhysicsStats = false;
}

// GLSL options
class M3ShaderOptions {
  bool perPixel = false; // per-pixel lighting
  bool cartoon = false; // cartoon in per-pixel lighting
  bool pcf = true; // percentage-closer-fliter (PCF) for shadowmap
}

/// Rendering statistics
class M3RenderStats {
  int frames = 0;
  int vertices = 0;
  int triangles = 0;
  int entities = 0;
  int culling = 0;

  void reset() {
    vertices = 0;
    triangles = 0;
    entities = 0;
    culling = 0;
  }
}

/// The WebGL rendering engine that manages shaders, framebuffers, and scene rendering.
///
/// Handles shader program creation, shadow mapping, 2D overlay rendering, and viewport management.
class M3RenderEngine {
  late RenderingContext gl;
  final Framebuffer defaultFBO = Framebuffer(0); // default framebuffer

  M3Program? programSimple;
  M3Program? programRectangle;
  M3ProgramLighting? programSimpleLighting;
  M3ProgramLighting? programTexture;
  M3ProgramShadowmap? programShadowmap;
  M3ProgramShadowCSM? programShadowCSM;
  M3Program? programSkybox;

  // shadow map
  M3ShadowMap? _shadowMap;
  M3ShadowMap? get shadowMap => _shadowMap;

  // for ortho-matrix to project to 2D screen
  final _projection2D = M3Projection();

  // render options, statistics
  final M3RenderOptions options = M3RenderOptions();
  final M3RenderStats stats = M3RenderStats();

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
    programShadowCSM?.dispose();

    _shadowMap?.dispose();
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
    programSimple = M3Program(Skinning_es2_vert + Simple_es2_vert, Simple_es2_frag);

    // skybox program
    programSkybox = M3Program(Skybox_es2_vert, Skybox_es2_frag);

    // simple lighting program
    programSimpleLighting = M3ProgramLighting(SimpleLighting_es2_vert, Simple_es2_frag);

    // rectangle program
    programRectangle = M3Program(Rect_es2_vert, Rect_es2_frag);

    setLightingProgram();
  }

  void setLightingProgram() {
    programTexture?.dispose();
    programShadowmap?.dispose();
    programShadowCSM?.dispose();

    final String strSkin = "#define WITH_NORMAL \n$Skinning_es2_vert";
    // texture lighting program
    String strVert = TexturedLighting_es2_vert;
    strVert = strSkin + strVert;
    String strFrag = TexturedLighting_es2_frag;
    // pixel lighting: phong shading, cartoon
    if (options.shader.perPixel) {
      strVert = "#define ENABLE_PIXEL_LIGHTING \n$strVert";
      strFrag = "#define ENABLE_PIXEL_LIGHTING \n$strFrag";
      if (options.shader.cartoon) {
        strFrag = "#define ENABLE_CARTOON \n$strFrag";
      }
    }
    programTexture = M3ProgramLighting(strVert, strFrag);

    // shadow map program
    String vsShadow = "#define ENABLE_SHADOW_MAP \n$strVert";
    String fsShadow = "#define ENABLE_SHADOW_MAP \n$strFrag";
    if (options.shader.pcf) {
      fsShadow = "#define ENABLE_PCF \n$fsShadow";
    }
    programShadowmap = M3ProgramShadowmap(vsShadow, fsShadow);

    // shadow CSM program
    vsShadow = "#define ENABLE_SHADOW_CSM \n$strVert";
    fsShadow = "#define ENABLE_SHADOW_CSM \n$strFrag";
    if (options.shader.pcf) {
      fsShadow = "#define ENABLE_PCF \n$fsShadow";
    }
    programShadowCSM = M3ProgramShadowCSM(vsShadow, fsShadow);
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
    stats.reset();
    stats.frames++;

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

    if (!options.debug.wireframe) {
      M3ProgramLighting progLight = programTexture!; // texture shader
      // Render Shadow Map
      if (options.shadows && _shadowMap != null) {
        _shadowMap!.renderDepthPass(scene, scene.light);

        M3ProgramShadow progShadow = programShadowmap!;
        // cascaded shadow mapping
        if (scene.light.cascades.isNotEmpty) {
          progShadow = programShadowCSM!;
        }
        progLight = progShadow;
        // bind shadowmap texture
        gl.useProgram(progShadow.program);
        progShadow.bindShadow(_shadowMap!.depthTexture);
      }

      progLight.applyLight(scene.light);
      // solid
      scene.render(progLight, scene.camera, bSolid: true);
    } else {
      // wireframe
      scene.render(programSimple!, scene.camera, bSolid: false);
    }

    // draw Helper
    if (options.debug.showHelpers) {
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
    if (options.debug.showHelpers) {
      if (options.shadows && _shadowMap != null) {
        final width = 200 / _shadowMap!.mapH * _shadowMap!.mapW;
        _shadowMap!.drawDebugDepth(10, engine.appHeight - 210, width, 200);
      }

      prog2D.setModelViewMatrix(Matrix4.identity());

      // draw test: triangle, line, touches
      M3Shape2D.drawTouches(engine.touchManager);
    }
    // Render Statistics
    Matrix4 matStats = Matrix4.identity();
    if (options.debug.showStats) {
      matStats.setTranslation(Vector3(M3AppEngine.instance.appWidth - 50, 50, 0));
      matStats.scaleByVector3(Vector3.all(0.5));
      final fpsText = engine.fps.toStringAsFixed(2);
      M3Resources.text2D.drawText(fpsText, matStats, color: Vector4(0, 1, 0, 1));

      final statText =
          '''
${engine.frameCounter.toString().padLeft(6)}
mesh:${stats.entities}
cull:${stats.culling}
 tri:${stats.triangles}
vert:${stats.vertices}''';
      matStats.setTranslation(Vector3(M3AppEngine.instance.appWidth - 90, 66, 0));
      matStats.scaleByVector3(Vector3.all(0.9));
      // Render Stats
      M3Resources.text2D.drawText(statText, matStats, color: Vector4(1, 1, 1, 1));

      if (engine.activeScene != null) {
        final scene = engine.activeScene!;

        final shadowText =
            '''
shadow:${options.shadows ? 'Y' : 'N'}
$shadowMap
csm=${scene.camera.csmCount}''';
        matStats.setTranslation(Vector3(M3AppEngine.instance.appWidth - 90, 150, 0));
        // Shadow Info
        M3Resources.text2D.drawText(shadowText, matStats, color: Vector4(1, 1, 0, 1));
      }
    }

    // Physics Statistics
    final physicsWorld = M3AppEngine.instance.physicsEngine.world;
    if (physicsWorld != null) {
      physicsWorld.isStat = options.debug.showPhysicsStats;
      if (options.debug.showPhysicsStats) {
        final physicsInfo = physicsWorld.getInfo();
        matStats.setTranslation(Vector3(10, 300, 0));
        M3Resources.text2D.drawText(physicsInfo, matStats, color: Vector4(1, 0, 1, 1));
      }
    }

    gl.disableVertexAttribArray(prog2D.attribVertex.id);
    gl.disableVertexAttribArray(prog2D.attribUV.id);
  }
}
