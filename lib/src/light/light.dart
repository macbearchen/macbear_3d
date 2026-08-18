// Macbear3D engine
import '../m3_internal.dart';
import '../renderer/shadow_map.dart';

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
  bool castShadow = true;
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

  static const int _maxLights = 8;
  static const int _maxShadow = 3;
  static const int _matCount = 4; // 8 點光源, 每 mat4 兩盞點光源

  final Float32List _lightMats = Float32List(_matCount * 16);
  final Int32List _counts = Int32List.fromList([0, 0]);
  int get lightCount => _counts[0];
  int get shadowCount => _counts[1];

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

    final active = sorted.take(_maxLights).toList();

    int shadowCount = 0;
    for (final l in active) {
      if (l.castShadow && shadowCount < _maxShadow) {
        shadowCount++;
      }
    }

    _counts[0] = active.length;
    _counts[1] = shadowCount;

    _lightMats.fillRange(0, _lightMats.length, 0.0);

    for (int i = 0; i < lightCount && i < _maxLights; i++) {
      final packed = active[i].packBuffer(mMatrixInv);
      final matIndex = i ~/ 2;
      final localIndex = i % 2;
      final offset = matIndex * 16 + localIndex * 8;

      _lightMats.setRange(offset, offset + 8, packed);
    }

    if (M3Program.isLocationValid(_uniformPointLights)) {
      gl.uniformMatrix4fv(_uniformPointLights, false, _lightMats);
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
  int _spotCount = 0;
  int get spotCount => _spotCount;

  late UniformLocation _uniformSpotLights;
  late UniformLocation _uniformSpotLightCount;

  List<M3SpotLight> _spotLights = [];

  M3SpotLightManager();

  void initLocation(Program program) {
    _uniformSpotLights = gl.getUniformLocation(program, 'uSpotLights');
    _uniformSpotLightCount = gl.getUniformLocation(program, 'uSpotLightCount');
  }

  void attachSpotLights(List<M3SpotLight> spotLights) {
    _spotLights = spotLights;
  }

  /// Upload spotlight uniforms for the current frame.
  ///
  /// [mMatrixInv] — inverse model matrix (world → object space), same convention
  /// as [M3PointLightManager.setLightUniforms].
  void setLightUniforms(Matrix4 mMatrixInv) {
    final active = _spotLights.take(_maxSpotLights).toList();
    _spotCount = active.length;

    _spotMats.fillRange(0, _spotMats.length, 0.0);

    for (int i = 0; i < _spotCount; i++) {
      final packed = active[i].packBuffer(mMatrixInv); // 16 floats
      final offset = i * 16;
      _spotMats.setRange(offset, offset + 16, packed);
    }

    if (M3Program.isLocationValid(_uniformSpotLights)) {
      gl.uniformMatrix4fv(_uniformSpotLights, false, _spotMats);
    }

    if (M3Program.isLocationValid(_uniformSpotLightCount)) {
      gl.uniform1i(_uniformSpotLightCount, _spotCount);
    }
  }
}
