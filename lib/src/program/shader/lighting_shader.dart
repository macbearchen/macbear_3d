part of '../program.dart';

/// lighting shader in program
mixin M3LightingShader {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  late UniformLocation uniformAmbient; // "ColorAmbient" = inColor * LightAmbient * MaterialDiffuse
  late UniformLocation uniformDiffuse; // "ColorDiffuse" = inColor * LightDiffuse * MaterialDiffuse
  late UniformLocation uniformSpecular; // "ColorSpecular" = inColor * LightDiffuse * MaterialSpecular (w: Shininess)

  // directional light related:
  late UniformLocation uniformLightDirection; // light direction "uLightDir" (per object-space)

  M3PointLightManager pointLightManager = M3PointLightManager();
  M3SpotLightManager spotLightManager = M3SpotLightManager();

  // scene lights:
  M3DirectionalLight? _dirLight; // directional light

  void initLightingLocation(Program prog) {
    uniformAmbient = gl.getUniformLocation(prog, "ColorAmbient");
    uniformDiffuse = gl.getUniformLocation(prog, "ColorDiffuse");
    uniformSpecular = gl.getUniformLocation(prog, "ColorSpecular");

    uniformLightDirection = gl.getUniformLocation(prog, "uLightDir");

    // light managers
    pointLightManager.initLocation(prog);
    spotLightManager.initLocation(prog);
  }

  /// directional light: scene only support one directional light.
  void attachDirectionalLight(M3DirectionalLight dirLight) {
    _dirLight = dirLight;
  }

  /// point light: scene support multiple point lights.
  void attachPointLights(List<M3PointLight> pointLights) {
    pointLightManager.attachPointLights(pointLights);
  }

  /// spot light: scene support multiple spot lights.
  void attachSpotLights(List<M3SpotLight> spotLights) {
    spotLightManager.attachSpotLights(spotLights);
  }

  /// set light uniforms.
  void setLightUniforms(Matrix4 mMatrix) {
    Matrix4 matInv = Matrix4.inverted(mMatrix);

    // directional light:
    if (_dirLight != null && M3Program.isLocationValid(uniformLightDirection)) {
      Vector3 lightDir = _dirLight!.getDirection();
      Vector4 localDir = matInv * Vector4(lightDir.x, lightDir.y, lightDir.z, 0.0);
      localDir.normalize();
      gl.uniform3fv(uniformLightDirection, localDir.xyz.storage);
    }

    // point lights
    pointLightManager.setLightUniforms(matInv);

    // spot lights
    spotLightManager.setLightUniforms(matInv);
  }
}

