// ignore_for_file: unused_import
// Macbear3D engine
import '../m3_internal.dart';

import '../shaders_gen/Mirror.es3.frag.g.dart';
import '../shaders_gen/Mirror.es3.vert.g.dart';
import '../shaders_gen/Rect.es3.frag.g.dart';
import '../shaders_gen/Rect.es3.vert.g.dart';
import '../shaders_gen/Simple.es3.frag.g.dart';
import '../shaders_gen/Simple.es3.vert.g.dart';
import '../shaders_gen/SimpleLighting.es3.vert.g.dart';
import '../shaders_gen/Skybox.es3.frag.g.dart';
import '../shaders_gen/Skybox.es3.vert.g.dart';
import '../shaders_gen/SkyboxReflect.es3.vert.g.dart';
import '../shaders_gen/TexturedLighting.es3.frag.g.dart';
import '../shaders_gen/TexturedLighting.es3.vert.g.dart';
import '../shaders_gen/Unlit.es3.frag.g.dart';
import '../shaders_gen/Unlit.es3.vert.g.dart';
import '../shaders_gen/Water.es3.frag.g.dart';
import '../shaders_gen/Water.es3.vert.g.dart';
// GLSL functions
import '../shaders_gen/glsl/PCF.es3.frag.g.dart';
import '../shaders_gen/glsl/Pixel.es3.frag.g.dart';
import '../shaders_gen/glsl/Skinning.es3.vert.g.dart';

class M3Resources {
  // ------------------------------
  // Textures
  // ------------------------------
  static final texWhite = M3Texture.createSolidColor(Vector4(1, 1, 1, 1));
  static final texNormal = M3Texture.createSolidColor(Vector4(0.5, 0.5, 1, 1));
  static final texDefaultCube = M3Texture.createDefaultIBLCube();

  // axis gizmo mesh
  static M3Mesh? _axisGizmoMesh;
  static M3Mesh get axisGizmoMesh {
    if (_axisGizmoMesh == null) {
      List<M3SubMesh> subMeshes = [];
      final mtrRed = M3Material()
        ..diffuse = Vector4(1, 0, 0, 1)
        ..setMatte();
      final mtrGreen = mtrRed.clone()..diffuse = Vector4(0, 1, 0, 1);
      final mtrBlue = mtrRed.clone()..diffuse = Vector4(0, 0, 1, 1);
      final mtrWhite = mtrRed.clone()..diffuse = Vector4(1, 1, 1, 1);

      // alpha blend
      final base = 0.8;
      final alpha = 0.5;
      final mtrRedAlpha = mtrRed.clone()
        ..diffuse = Vector4(base, 0, 0, alpha)
        ..alphaMode = M3AlphaMode.blend;
      final mtrGreenAlpha = mtrRed.clone()
        ..diffuse = Vector4(0, base, 0, alpha)
        ..alphaMode = M3AlphaMode.blend;
      final mtrBlueAlpha = mtrRed.clone()
        ..diffuse = Vector4(0, 0, base, alpha)
        ..alphaMode = M3AlphaMode.blend;

      // 3 axes: positive
      final axisX = M3SubMesh(unitCube, material: mtrRed);
      final axisScale = 5.0;
      axisX.localMatrix
        ..translateByVector3(Vector3(axisScale * 0.5, 0, 0))
        ..scaleByVector3(Vector3(axisScale, 0.1, 0.1));
      subMeshes.add(axisX);
      final axisY = M3SubMesh(unitCube, material: mtrGreen);
      axisY.localMatrix
        ..translateByVector3(Vector3(0, axisScale * 0.5, 0))
        ..scaleByVector3(Vector3(0.1, axisScale, 0.1));
      subMeshes.add(axisY);
      final axisZ = M3SubMesh(unitCube, material: mtrBlue);
      axisZ.localMatrix
        ..translateByVector3(Vector3(0, 0, axisScale * 0.5))
        ..scaleByVector3(Vector3(0.1, 0.1, axisScale));
      subMeshes.add(axisZ);

      // 3 axes: negative
      final axisXAlpha = M3SubMesh(unitCube, material: mtrRedAlpha);
      axisXAlpha.localMatrix
        ..translateByVector3(Vector3(-axisScale * 0.5, 0, 0))
        ..scaleByVector3(Vector3(axisScale, 0.1, 0.1));
      subMeshes.add(axisXAlpha);
      final axisYAlpha = M3SubMesh(unitCube, material: mtrGreenAlpha);
      axisYAlpha.localMatrix
        ..translateByVector3(Vector3(0, -axisScale * 0.5, 0))
        ..scaleByVector3(Vector3(0.1, axisScale, 0.1));
      subMeshes.add(axisYAlpha);
      final axisZAlpha = M3SubMesh(unitCube, material: mtrBlueAlpha);
      axisZAlpha.localMatrix
        ..translateByVector3(Vector3(0, 0, -axisScale * 0.5))
        ..scaleByVector3(Vector3(0.1, 0.1, axisScale));
      subMeshes.add(axisZAlpha);

      // 3 arrows
      final arrowScale = Vector3(0.4, 0.4, 0.4);
      final arrowX = M3SubMesh(M3PyramidGeom(1, 1, 1, axis: M3Axis.x), material: mtrRed);
      arrowX.localMatrix
        ..translateByVector3(Vector3(axisScale, 0, 0))
        ..scaleByVector3(arrowScale);
      subMeshes.add(arrowX);
      final arrowY = M3SubMesh(M3PyramidGeom(1, 1, 1, axis: M3Axis.y), material: mtrGreen);
      arrowY.localMatrix
        ..translateByVector3(Vector3(0, axisScale, 0))
        ..scaleByVector3(arrowScale);
      subMeshes.add(arrowY);
      final arrowZ = M3SubMesh(M3PyramidGeom(1, 1, 1, axis: M3Axis.z), material: mtrBlue);
      arrowZ.localMatrix
        ..translateByVector3(Vector3(0, 0, axisScale))
        ..scaleByVector3(arrowScale);
      subMeshes.add(arrowZ);

      final origin = M3SubMesh(debugDot, material: mtrWhite);
      subMeshes.add(origin);

      _axisGizmoMesh = M3Mesh(null);
      _axisGizmoMesh!.subMeshes = subMeshes;
    }
    return _axisGizmoMesh!;
  }

  // ------------------------------
  // Geometries: debug
  // ------------------------------
  static final debugAxis = M3DebugAxisGeom(size: 0.5);
  static final debugSphere = M3DebugSphereGeom(radius: 1.0);
  static final debugFrustum = M3BoxGeom(2.0, 2.0, 2.0);
  static final debugDot = M3OctahedralGeom(0.25);
  static final debugView = M3PlaneGeom(1.6, 1.6, widthSegments: 5, heightSegments: 4);

  // ------------------------------
  // Unit geometries
  // ------------------------------
  static final unitCube = M3BoxGeom(1.0, 1.0, 1.0);
  static final unitBone = M3OctahedralGeom(0.5, bias: Vector3(-0.6, 0, 0));
  static final unitOctahedral = M3OctahedralGeom(0.5);
  static final unitSphere = M3SphereGeom(0.5);

  // ------------------------------
  // 2D shapes
  // ------------------------------
  // for dynamic draw: line, triangle
  static M3Shape2D? _line;
  static M3Shape2D? _triangle;

  // text2D from sprite, rectUnit for image
  static M3Text2D? _text2D;
  static M3Rectangle2D? _rectUnit;

  static M3Text2D get text2D {
    return _text2D!;
  }

  static M3Shape2D get line {
    _line ??= M3Shape2D(WebGL.LINES, 2)..createVBO(WebGL.DYNAMIC_DRAW);
    return _line!;
  }

  static M3Shape2D get triangle {
    _triangle ??= M3Shape2D(WebGL.TRIANGLES, 3)..createVBO(WebGL.DYNAMIC_DRAW);
    return _triangle!;
  }

  static M3Rectangle2D get rectUnit {
    _rectUnit ??= M3Rectangle2D()
      ..setRectangle(0, 0, 1, 1)
      ..createVBO(WebGL.STATIC_DRAW);
    return _rectUnit!;
  }

  // ------------------------------
  // Programs
  // ------------------------------
  static M3Program? programSimple;
  static M3Program? programSkybox;
  static M3Program? programRectangle;
  static M3Program? programMirror; // plane reflection (mirror / water)
  static M3Program? programWater; // water shader program
  static M3ProgramEye? programSkyboxReflect;
  static M3Program? programExternalOES; // external texture: video streaming
  // with lighting
  static M3ProgramLighting? programSimpleLighting;
  static M3ProgramLighting? programTexture;
  static M3ProgramShadowmap? programShadowmap;
  static M3ProgramShadowCSM? programShadowCSM;

  // ignore: non_constant_identifier_names
  static final _SkinNormal_vert = "#define ENABLE_NORMAL \n$Skinning_vert";

  static Future<void> init() async {
    debugPrint('M3Resources: init starting...');
    // Textures
    texWhite;
    texNormal;
    texDefaultCube;
    debugPrint('M3Resources: basic textures initialized');

    // Mesh
    axisGizmoMesh;

    // Geometries
    debugAxis;
    debugSphere;
    debugFrustum;
    debugDot;
    debugView;

    unitCube;
    unitBone;
    unitOctahedral;
    unitSphere;
    debugPrint('M3Resources: unit geometries initialized');

    // 2D
    line;
    triangle;
    rectUnit;
    _text2D = await M3Text2D.createText2D(fontSize: 30);
    debugPrint('M3Resources: text2D initialized');

    // Programs
    debugPrint('M3Resources: initializing shader programs...');
    programSimple = M3Program(Skinning_vert + Simple_vert, Simple_frag);
    programSkybox = M3Program(Skybox_vert, Skybox_frag);
    programRectangle = M3Program(Rect_vert, Rect_frag);
    programSkyboxReflect = M3ProgramEye(_SkinNormal_vert + SkyboxReflect_vert, Skybox_frag);
    programSimpleLighting = M3ProgramLighting(_SkinNormal_vert + SimpleLighting_vert, Simple_frag);

    // plane reflection (mirror / water)
    // programMirror = M3Program(Mirror_vert, Mirror_frag);
    programMirror = M3Program(Skinning_vert + Simple_vert, Mirror_frag);
    programWater = M3Program(Water_vert, Water_frag);

    // external texture: video streaming
    String fsUnlit = Unlit_frag;
    if (PlatformInfo.isIOS || PlatformInfo.isMacOS) {
      // iOS, macOS: format BGRA
      // fsUnlit = '#define ENABLE_TEXTURE0_BGRA \n$fsUnlit';

      // Android: external OES unable to use SurfaceTexture
      // ANGLE use libEGL_angle.so, Android use libEGL.so
      // so discard to use external OES
      /* String fsExternalOES = '''
#extension GL_OES_EGL_image_external_essl3 : require
#define ENABLE_EXTERNAL_OES
'''; */
    }
    programExternalOES = M3Program(Unlit_vert, fsUnlit);

    // lighting related programs
    setLightingProgram(M3ShaderOptions());

    debugPrint('+++ M3Resources init done+++');
  }

  static void setLightingProgram(M3ShaderOptions options) {
    programTexture?.dispose();
    programShadowmap?.dispose();
    programShadowCSM?.dispose();

    // texture lighting program
    String strVert = _SkinNormal_vert + TexturedLighting_vert;
    String strFrag = TexturedLighting_frag;

    // pixel lighting: phong shading, cartoon, PBR
    if (options.perPixel) {
      if (options.pbr) {
        // ES3 PBR: Use modern ES3 shaders
        strVert = Skinning_vert + TexturedLighting_vert;
        strFrag = Pixel_frag + TexturedLighting_frag;

        strVert = "#define ENABLE_PIXEL_LIGHTING \n#define ENABLE_PBR \n#define ENABLE_NORMAL \n$strVert";
        strFrag = "#define ENABLE_PIXEL_LIGHTING \n#define ENABLE_PBR \n$strFrag";
        if (options.ibl) {
          strFrag = "#define ENABLE_IBL \n$strFrag";
        }
      } else {
        // ES2 Lighting
        strVert = "#define ENABLE_PIXEL_LIGHTING \n$strVert";
        strFrag = Pixel_frag + strFrag;
        if (options.cartoon) {
          strFrag = "#define ENABLE_CARTOON \n$strFrag";
        }
      }
    }
    programTexture = M3ProgramLighting(strVert, strFrag);

    // PCF function only for shadow programs (append at end)
    strFrag += PCF_frag;

    // PCF - 0:none, 1:default(4-tap), 2:3x3, 3:5x5
    if (options.pcf == 1) {
      strFrag = "#define ENABLE_PCF \n$strFrag";
    } else if (options.pcf == 2) {
      strFrag = "#define ENABLE_PCF_3x3 \n$strFrag";
    } else if (options.pcf == 3) {
      strFrag = "#define ENABLE_PCF_5x5 \n$strFrag";
    }

    // shadow map program
    String vsShadow = "#define ENABLE_SHADOW_MAP \n$strVert";
    String fsShadow = "#define ENABLE_SHADOW_MAP \n$strFrag";
    programShadowmap = M3ProgramShadowmap(vsShadow, fsShadow);

    // shadow CSM program
    vsShadow = "#define ENABLE_SHADOW_CSM \n$strVert";
    fsShadow = "#define ENABLE_SHADOW_CSM \n$strFrag";
    programShadowCSM = M3ProgramShadowCSM(vsShadow, fsShadow);
  }

  static void checkUpdate(M3ShaderOptions options) {
    if (options.isDirty) {
      setLightingProgram(options);
      options.isDirty = false;
    }
  }

  static void dispose() {
    // Textures
    texWhite.dispose();
    texNormal.dispose();
    texDefaultCube.dispose();

    // Geometries
    debugAxis.dispose();
    debugSphere.dispose();
    debugFrustum.dispose();
    debugDot.dispose();
    debugView.dispose();

    unitCube.dispose();
    unitBone.dispose();
    unitOctahedral.dispose();
    unitSphere.dispose();

    // 2D
    _line?.dispose();
    _triangle?.dispose();
    _rectUnit?.dispose();
    _text2D?.dispose();

    // Programs
    programSimple?.dispose();
    programSkybox?.dispose();
    programRectangle?.dispose();
    programMirror?.dispose();
    programWater?.dispose();
    programSkyboxReflect?.dispose();
    programExternalOES?.dispose();
    programSimpleLighting?.dispose();

    programTexture?.dispose();
    programShadowmap?.dispose();
    programShadowCSM?.dispose();
  }
}
