// Macbear3D engine
import '../m3_internal.dart';

part 'directional_light.dart';
part 'point_light.dart';
part 'spot_light.dart';

/// A directional or positional light source for scene illumination.
///
/// Extends [M3Node] for scene-graph hierarchy and world matrix evaluation.
abstract class M3Light extends M3Node {
  static Vector3 ambient = Vector3(0.2, 0.2, 0.2);
  Vector3 color = Colors.white.rgb - ambient;

  // shadow map
  bool castShadow = false;
  M3ShadowMap? shadowMap;

  M3Light() {
    position = Vector3(0, 0, 6);
  }

  /// set shadow map
  void setShadowMap(M3ShadowMap? sm) {
    shadowMap = sm;
    castShadow = sm != null;
  }

  static Vector4 blendRGBA(Vector4 a, Vector4 b) {
    return Vector4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w);
  }

  static Vector3 blendRGB(Vector3 a, Vector3 b) {
    return Vector3(a.x * b.x, a.y * b.y, a.z * b.z);
  }

  void drawHelper(M3Program prog, M3Camera viewer) {
    Matrix4 targetMatrix = Matrix4.identity();
    targetMatrix.setTranslation(worldMatrix.getTranslation());
    targetMatrix.scaleByVector3(Vector3.all(0.1));
    prog.setMatrices(viewer, targetMatrix);
    M3Resources.debugPointLight.draw(prog, fillMode: .wireframe);
  }
}

/// light manager
class M3PointLightManager {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  static const int _maxPointLights = 8;
  static const int _maxShadow = 3;
  static const int _matCount = 4; // 8 點光源, 每 mat4 兩盞點光源

  final Float32List _pointMats = Float32List(_matCount * 16);
  final Int32List _counts = Int32List.fromList([0, 0]);
  int get pointCount => _counts[0];
  int get shadowFlag => _counts[1];

  late UniformLocation _uniformPointLights;
  late UniformLocation _uniformPointLightCounts;

  List<M3PointLight> _pointLights = [];

  M3PointLightManager();

  void initLocation(Program program) {
    _uniformPointLights = gl.getUniformLocation(program, 'uPointLights');
    _uniformPointLightCounts = gl.getUniformLocation(program, 'uPointLightCounts');
  }

  void attachPointLights(List<M3PointLight> pointLights) {
    _pointLights = pointLights;
  }

  /// 每幀呼叫一次，lights 建議先經過 frustum/range culling 再傳入
  /// 內部強制排序（陰影燈優先），不信任外部呼叫端已排好順序
  void setLightUniforms(Matrix4 mMatrixInv) {
    final sorted = [..._pointLights];
    sorted.sort((a, b) {
      if (a.castShadow != b.castShadow) {
        return a.castShadow ? -1 : 1;
      }
      return 0;
    });

    final active = sorted.take(_maxPointLights).toList();

    int shadowCount = 0;
    for (final l in active) {
      if (l.castShadow && shadowCount < _maxShadow) {
        shadowCount++;
      }
    }

    _counts[0] = active.length;
    _counts[1] = shadowCount;

    _pointMats.fillRange(0, _pointMats.length, 0.0);

    for (int i = 0; i < pointCount && i < _maxPointLights; i++) {
      final packed = active[i].packBuffer(mMatrixInv);
      final matIndex = i ~/ 2;
      final localIndex = i % 2;
      final offset = matIndex * 16 + localIndex * 8;

      _pointMats.setRange(offset, offset + 8, packed);
    }

    if (M3Program.isLocationValid(_uniformPointLights)) {
      gl.uniformMatrix4fv(_uniformPointLights, false, _pointMats);
    }

    if (M3Program.isLocationValid(_uniformPointLightCounts)) {
      gl.uniform2iv(_uniformPointLightCounts, _counts);
    }
  }
}

/// Spotlight manager — packs up to 8 spotlights into `uSpotLights[8]` (1 mat4 each).
class M3SpotLightManager {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  static const int _maxSpotLights = 8;

  final Float32List _spotMats = Float32List(_maxSpotLights * 16);
  final Int32List _counts = Int32List.fromList([0, 0]);
  int get spotCount => _counts[0];
  int get shadowFlag => _counts[1];

  late UniformLocation _uniformSpotLights;
  late UniformLocation _uniformSpotLightCounts;

  // Spot shadow uniforms
  late UniformLocation _uniformSamplerSpotShadowmap;
  late UniformLocation _uniformSpotShadowmapTexelSize;
  late UniformLocation _uniformMatrixSpotShadowAtlas;
  late UniformLocation _uniformSpotShadowNormalBias;

  final Float32List _spotShadowMats = Float32List(_maxSpotLights * 16);

  List<M3SpotLight> _spotLights = [];

  M3SpotLightManager();

  void initLocation(Program program) {
    _uniformSpotLights = gl.getUniformLocation(program, 'uSpotLights');
    _uniformSpotLightCounts = gl.getUniformLocation(program, 'uSpotLightCounts');

    _uniformSamplerSpotShadowmap = gl.getUniformLocation(program, 'SamplerSpotShadowmap');
    _uniformSpotShadowmapTexelSize = gl.getUniformLocation(program, 'SpotShadowmapTexelSize');
    _uniformMatrixSpotShadowAtlas = gl.getUniformLocation(program, 'uMatrixSpotShadowAtlas');
    _uniformSpotShadowNormalBias = gl.getUniformLocation(program, 'SpotShadowNormalBias');

    if (M3Program.isLocationValid(_uniformSamplerSpotShadowmap)) {
      gl.uniform1i(_uniformSamplerSpotShadowmap, 4); // GL_TEXTURE4
    }
  }

  void attachSpotLights(List<M3SpotLight> spotLights) {
    _spotLights = spotLights;
  }

  /// Upload spotlight uniforms for the current frame.
  ///
  /// [mMatrixInv] — inverse model matrix (world → object space), same convention
  /// as [M3PointLightManager.setLightUniforms].
  void setLightUniforms(Matrix4 mMatrixInv, [Matrix4? mMatrix]) {
    final active = _spotLights.take(_maxSpotLights).toList();
    _counts[0] = active.length;

    int shadowBitmask = 0;
    M3ShadowMap? shadowMap;
    double normalBias = 0.02;

    for (int i = 0; i < active.length; i++) {
      if (active[i].castShadow && active[i].shadowMap != null) {
        shadowBitmask |= (1 << i);
        shadowMap ??= active[i].shadowMap;
        normalBias = active[i].shadowNormalBias;
      }
    }
    _counts[1] = shadowBitmask;

    _spotMats.fillRange(0, _spotMats.length, 0.0);

    for (int i = 0; i < spotCount && i < _maxSpotLights; i++) {
      final packed = active[i].packBuffer(mMatrixInv); // 16 floats
      final offset = i * 16;
      _spotMats.setRange(offset, offset + 16, packed);
    }

    if (M3Program.isLocationValid(_uniformSpotLights)) {
      gl.uniformMatrix4fv(_uniformSpotLights, false, _spotMats);
    }

    if (M3Program.isLocationValid(_uniformSpotLightCounts)) {
      gl.uniform2iv(_uniformSpotLightCounts, _counts);
    }

    // Apply shadow map atlas if any spotlight casts shadow
    if (shadowMap != null && shadowBitmask != 0) {
      final sm = shadowMap;

      if (M3Program.isLocationValid(_uniformSamplerSpotShadowmap)) {
        gl.activeTexture(WebGL.TEXTURE4);
        sm.depthTex.bind();
        gl.uniform1i(_uniformSamplerSpotShadowmap, 4);
        gl.activeTexture(WebGL.TEXTURE0);
      }

      if (M3Program.isLocationValid(_uniformSpotShadowmapTexelSize)) {
        gl.uniform2f(_uniformSpotShadowmapTexelSize, 1.0 / sm.mapW, 1.0 / sm.mapH);
      }

      if (M3Program.isLocationValid(_uniformSpotShadowNormalBias)) {
        gl.uniform1f(_uniformSpotShadowNormalBias, normalBias);
      }

      if (M3Program.isLocationValid(_uniformMatrixSpotShadowAtlas)) {
        final matModel = mMatrix ?? Matrix4.inverted(mMatrixInv);
        _spotShadowMats.fillRange(0, _spotShadowMats.length, 0.0);

        // Atlas has 8 vertical slots: slot i occupies Y [i/8, (i+1)/8]
        const double scaleY = 0.5 / _maxSpotLights; // 0.5 / 8 = 0.0625

        for (int i = 0; i < active.length; i++) {
          if ((shadowBitmask & (1 << i)) == 0) continue;

          final spot = active[i];
          final viewer = spot.lightViewer;
          final Matrix4 lightMatrix = viewer.projectionMatrix * viewer.viewMatrix * matModel;

          // Build atlas bias matrix for slot i
          final Matrix4 biasMatrix = Matrix4.copy(M3Constants.biasMatrix);
          final double biasY = (0.5 + i) / _maxSpotLights;
          biasMatrix.setEntry(1, 1, scaleY);
          biasMatrix.setEntry(1, 3, biasY);

          final Matrix4 shadowMatrix = biasMatrix * lightMatrix;
          final int offset = i * 16;
          _spotShadowMats.setRange(offset, offset + 16, shadowMatrix.storage);
        }

        gl.uniformMatrix4fv(_uniformMatrixSpotShadowAtlas, false, _spotShadowMats);
      }
    }
  }
}
