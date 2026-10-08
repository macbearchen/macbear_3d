// Macbear3D engine
import '../m3_internal.dart';

import '../shaders_gen/Mirror.es3.frag.g.dart';
// import '../shaders_gen/Mirror.es3.vert.g.dart';
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
// GLSL functions include
import '../shaders_gen/glsl/FogFS.es3.glsl.g.dart';
import '../shaders_gen/glsl/LightFS.es3.glsl.g.dart';
import '../shaders_gen/glsl/PixelFS.es3.glsl.g.dart';
import '../shaders_gen/glsl/ShadowFS.es3.glsl.g.dart';
import '../shaders_gen/glsl/ShadowVS.es3.glsl.g.dart';
import '../shaders_gen/glsl/SkinningVS.es3.glsl.g.dart';
import '../shaders_gen/glsl/SurfaceGeometry.glsl.g.dart';

class M3ProgramManager {
  // ignore: non_constant_identifier_names
  final _SkinNormalVS_glsl = "#define ENABLE_NORMAL \n$SkinningVS_glsl";

  // ------------------------------
  // Programs
  // ------------------------------
  late M3Program programSimple;
  late M3Program programSkybox;
  late M3Program programRectangle;
  late M3Program programMirror; // plane reflection (mirror / water)
  late M3ProgramWater programWater; // water no shadow
  late M3ProgramWaterCSM programWaterCSM; // water shadow CSM
  late M3ProgramEye programSkyboxReflect;
  late M3Program programExternalOES; // external texture: video streaming
  // depth-only masked: skinning + alpha test (for shadow depth pass)
  late M3Program programSimpleMasked;
  // with lighting
  late M3ProgramLighting programSimpleLighting;

  // with texture
  late M3ProgramLighting programTexture;
  late M3ProgramShadow programShadow;
  // with texture and normal map
  late M3ProgramLighting programTextureNormal;
  late M3ProgramShadow programShadowNormal;
  // with masked (alpha test)
  late M3ProgramLighting programTextureMasked;
  late M3ProgramShadow programShadowMasked;
  // with masked (alpha test) and normal map
  late M3ProgramLighting programTextureNormalMasked;
  late M3ProgramShadow programShadowNormalMasked;

  /// All currently initialized lighting programs
  Iterable<M3ProgramLighting> get lightingPrograms => [
    programTexture,
    programTextureNormal,
    programShadow,
    programShadowNormal,
    programTextureMasked,
    programTextureNormalMasked,
    programShadowMasked,
    programShadowNormalMasked,
  ];

  /// Get the lighting program corresponding to the 8 variant key combinations
  M3ProgramLighting getLightingProgramByVariant(int variantKey) {
    final bool hasAlpha = (variantKey & M3ShaderVariantBits.enableAlphaTest) != 0;
    final bool hasNormal = (variantKey & M3ShaderVariantBits.enableNormalMap) != 0;
    final bool hasShadow = (variantKey & M3ShaderVariantBits.enableShadowReceive) != 0;

    if (hasShadow) {
      if (hasNormal) {
        return hasAlpha ? programShadowNormalMasked : programShadowNormal;
      } else {
        return hasAlpha ? programShadowMasked : programShadow;
      }
    } else {
      if (hasNormal) {
        return hasAlpha ? programTextureNormalMasked : programTextureNormal;
      } else {
        return hasAlpha ? programTextureMasked : programTexture;
      }
    }
  }

  M3ProgramManager() {
    M3Log.i('M3ProgramManager', 'initializing shader programs...');
    programSimple = M3Program(SkinningVS_glsl + Simple_vert, Simple_frag);
    programSkybox = M3Program(Skybox_vert, Skybox_frag);
    programRectangle = M3Program(Rect_vert, Rect_frag);
    programSkyboxReflect = M3ProgramEye(
      _SkinNormalVS_glsl + SkyboxReflect_vert,
      Skybox_frag,
      reflectionType: M3ReflectionType.cubemap,
    );
    programSimpleLighting = M3ProgramLighting(_SkinNormalVS_glsl + SimpleLighting_vert, Simple_frag);

    // plane reflection (mirror / water)
    // programMirror = M3Program(Mirror_vert, Mirror_frag);
    programMirror = M3Program(SkinningVS_glsl + Simple_vert, Mirror_frag, reflectionType: M3ReflectionType.planar);

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

    // depth-only masked: skinning + alpha test (for shadow depth pass)
    final progSimpleMasked = M3Program(SkinningVS_glsl + Unlit_vert, '#define ENABLE_ALPHA_TEST \n$fsUnlit');
    progSimpleMasked.name = 'SimpleMasked';
    programSimpleMasked = progSimpleMasked;

    // lighting related programs
    setLightingProgram(M3ShaderOptions());

    M3Log.i('M3ProgramManager', 'all programs initialized.');
  }

  String _getShadowFS(M3ShaderOptions options) {
    // shadow map, CSM, PCF
    String strShadowFS = ShadowFS_glsl;

    // PCF - 0:none, 1:default(4-tap), 2:3x3, 3:5x5
    if (options.pcf == 1) {
      strShadowFS = "#define ENABLE_PCF \n$strShadowFS";
    } else if (options.pcf == 2) {
      strShadowFS = "#define ENABLE_PCF_3x3 \n$strShadowFS";
    } else if (options.pcf == 3) {
      strShadowFS = "#define ENABLE_PCF_5x5 \n$strShadowFS";
    }
    return strShadowFS;
  }

  bool _isLightingInitialized = false;

  void setLightingProgram(M3ShaderOptions options) {
    if (_isLightingInitialized) {
      programTexture.dispose();
      programShadow.dispose();
      programTextureMasked.dispose();
      programShadowMasked.dispose();

      programTextureNormal.dispose();
      programShadowNormal.dispose();
      programTextureNormalMasked.dispose();
      programShadowNormalMasked.dispose();
    }

    // texture lighting program
    String strVert = _SkinNormalVS_glsl + TexturedLighting_vert;
    String strFrag = SurfaceGeometry_glsl + TexturedLighting_frag;

    // pixel lighting: phong shading, cartoon, PBR, IBL
    if (options.perPixel) {
      if (options.pbr) {
        // ES3 PBR: Use modern ES3 shaders
        strVert = "#define ENABLE_PBR \n$strVert";
        strFrag = "#define ENABLE_PBR \n$strFrag";
        if (options.ibl) {
          strFrag = "#define ENABLE_IBL \n$strFrag";
        }
      } else {
        // ES2 Lighting: phong shading, cartoon
        if (options.cartoon) {
          strFrag = "#define ENABLE_CARTOON \n$strFrag";
        }
      }
      // add pixel lighting shader to vertex/fragment shader for final result
      strVert = "#define ENABLE_PIXEL_LIGHTING \n$strVert";
      strFrag = "#define ENABLE_PIXEL_LIGHTING \n$strFrag";
      if (options.pointLights || options.spotLights) {
        // LightFS_glsl is appended once; defines select which code is active
        if (options.pointLights) {
          strFrag = "#define ENABLE_POINT_LIGHTS \n$strFrag";
        }
        if (options.spotLights) {
          strFrag = "#define ENABLE_SPOT_LIGHTS \n$strFrag";
        }
        strFrag = "$strFrag \n$LightFS_glsl";
      }
      strFrag = strFrag + PixelFS_glsl;
    }

    if (options.fog) {
      strVert = "#define ENABLE_FOG \n$strVert";
      strFrag = "#define ENABLE_FOG \n$strFrag \n$FogFS_glsl";
    }

    M3Log.i('setLightingProgram', 'prepare lighting');
    programTexture = M3ProgramLighting(strVert, strFrag);
    final strFragMasked = "#define ENABLE_ALPHA_TEST \n$strFrag";
    programTextureMasked = M3ProgramLighting(strVert, strFragMasked);

    // NormalMap variant programs
    final String strFragNormal = "#define ENABLE_NORMALMAP \n$strFrag";
    final String strFragNormalMasked = "#define ENABLE_ALPHA_TEST \n#define ENABLE_NORMALMAP \n$strFrag";
    programTextureNormal = M3ProgramLighting(strVert, strFragNormal);
    programTextureNormalMasked = M3ProgramLighting(strVert, strFragNormalMasked);

    // PCF: Percentage Closer Filtering
    String strShadowFS = _getShadowFS(options);

    // shadow map, CSM
    strVert = ShadowVS_glsl + strVert; // shadow vertex shader
    strFrag = strFrag + strShadowFS; // shadow fragment shader

    // ENABLE_SPOT_SHADOW must be prepended AFTER ShadowVS_glsl so the define
    // appears before ShadowVS_glsl in the final string (preprocessor reads top-down)
    final bool useShadow = M3AppEngine.instance.renderEngine.options.useShadow;
    if (options.spotLights && useShadow) {
      strVert = "#define ENABLE_SPOT_SHADOW \n$strVert";
      strFrag = "#define ENABLE_SPOT_SHADOW \n$strFrag";
    }

    // Shadow program: programShadowmap when csmCount == 0, programShadowCSM when csmCount > 0
    if (options.csmCount == 0) {
      String vsShadow = "#define ENABLE_SHADOW_MAP \n$strVert";
      String fsShadow = "#define ENABLE_SHADOW_MAP \n$strFrag";
      M3Log.i('setLightingProgram', 'prepare shadowmap (CSM=0)');
      programShadow = M3ProgramShadowmap(vsShadow, fsShadow);
      fsShadow = "#define ENABLE_ALPHA_TEST \n$fsShadow";
      programShadowMasked = M3ProgramShadowmap(vsShadow, fsShadow);

      String fsShadowNormal = "#define ENABLE_NORMALMAP \n#define ENABLE_SHADOW_MAP \n$strFrag";
      programShadowNormal = M3ProgramShadowmap(vsShadow, fsShadowNormal);
      String fsShadowNormalMasked =
          "#define ENABLE_ALPHA_TEST \n#define ENABLE_NORMALMAP \n#define ENABLE_SHADOW_MAP \n$strFrag";
      programShadowNormalMasked = M3ProgramShadowmap(vsShadow, fsShadowNormalMasked);
    } else {
      final String csmDefine = options.csmOnFS ? "#define ENABLE_SHADOW_CSM_FS \n" : "#define ENABLE_SHADOW_CSM_VS \n";
      String vsShadow = "$csmDefine \n$strVert";
      String fsShadow = "$csmDefine \n$strFrag";
      M3Log.i('setLightingProgram', 'prepare shadow CSM (count=${options.csmCount})');
      programShadow = M3ProgramShadowCSM(vsShadow, fsShadow);
      fsShadow = "#define ENABLE_ALPHA_TEST \n$fsShadow";
      programShadowMasked = M3ProgramShadowCSM(vsShadow, fsShadow);

      String fsShadowNormal = "$csmDefine \n#define ENABLE_NORMALMAP \n$strFrag";
      programShadowNormal = M3ProgramShadowCSM(vsShadow, fsShadowNormal);
      String fsShadowNormalMasked = "$csmDefine \n#define ENABLE_ALPHA_TEST \n#define ENABLE_NORMALMAP \n$strFrag";
      programShadowNormalMasked = M3ProgramShadowCSM(vsShadow, fsShadowNormalMasked);
    }

    _setWaterProgram(options);
    _isLightingInitialized = true;
  }

  void _setWaterProgram(M3ShaderOptions options) {
    if (_isLightingInitialized) {
      programWater.dispose();
      programWaterCSM.dispose();
    }

    // water program without shadow
    String vsWater = SkinningVS_glsl + Water_vert;
    String fsWater = SurfaceGeometry_glsl + Water_frag;
    fsWater = "#define ENABLE_WATER_SPECULAR \n$fsWater";

    if (options.pointLights || options.spotLights) {
      if (options.pointLights) {
        fsWater = "#define ENABLE_POINT_LIGHTS \n$fsWater";
      }
      if (options.spotLights) {
        fsWater = "#define ENABLE_SPOT_LIGHTS \n$fsWater";
      }
      fsWater = "$fsWater \n$LightFS_glsl";
    }
    if (options.fog) {
      vsWater = "#define ENABLE_FOG \n$vsWater";
      fsWater = "#define ENABLE_FOG \n$fsWater \n$FogFS_glsl";
    }
    M3Log.i('setLightingProgram', 'prepare water');
    programWater = M3ProgramWater(vsWater, fsWater);

    // PCF: Percentage Closer Filtering
    String strShadowFS = _getShadowFS(options);

    // water program with shadow CSM
    final String csmDefine = options.csmOnFS ? "#define ENABLE_SHADOW_CSM_FS \n" : "#define ENABLE_SHADOW_CSM_VS \n";
    vsWater = "$csmDefine \n$ShadowVS_glsl \n$vsWater";
    fsWater = "$csmDefine \n$fsWater \n$strShadowFS";
    programWaterCSM = M3ProgramWaterCSM(vsWater, fsWater);
  }

  void checkUpdate(M3ShaderOptions options) {
    if (options.isDirty) {
      setLightingProgram(options);
      options.isDirty = false;
    }
  }

  void dispose() {
    // Programs
    programSimple.dispose();
    programSkybox.dispose();
    programRectangle.dispose();
    programMirror.dispose();
    programWater.dispose();
    programWaterCSM.dispose();
    programSkyboxReflect.dispose();
    programExternalOES.dispose();
    programSimpleMasked.dispose();
    programSimpleLighting.dispose();

    // lighting related programs
    programTexture.dispose();
    programShadow.dispose();
    programTextureMasked.dispose();
    programShadowMasked.dispose();

    programTextureNormal.dispose();
    programShadowNormal.dispose();
    programTextureNormalMasked.dispose();
    programShadowNormalMasked.dispose();
  }
}
