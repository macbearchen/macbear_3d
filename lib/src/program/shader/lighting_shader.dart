part of '../program.dart';

/// lighting shader in program
mixin M3LightingShader {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  late UniformLocation uniformAmbient; // "ColorAmbient" = inColor * LightAmbient * MaterialDiffuse
  late UniformLocation uniformDiffuse; // "ColorDiffuse" = inColor * LightDiffuse * MaterialDiffuse
  late UniformLocation uniformSpecular; // "ColorSpecular" = inColor * LightDiffuse * MaterialSpecular (w: Shininess)

  late UniformLocation uniformLightDirection; // light direction "uLightDir" (per object-space)

  M3DirectionalLight? _dirLight; // directional light
  final List<M3PointLight> _pointLights = [];

  void initLightingLocation(Program prog) {
    uniformAmbient = gl.getUniformLocation(prog, "ColorAmbient");
    uniformDiffuse = gl.getUniformLocation(prog, "ColorDiffuse");
    uniformSpecular = gl.getUniformLocation(prog, "ColorSpecular");

    uniformLightDirection = gl.getUniformLocation(prog, "uLightDir");
  }

  void attachLight(M3DirectionalLight dirLight) {
    _dirLight = dirLight;
  }

  void setLightDirection(Matrix4 mMatrix) {
    if (_dirLight != null && M3Program.isLocationValid(uniformLightDirection)) {
      Vector3 lightDir = _dirLight!.getDirection();
      Vector4 localDir = Matrix4.inverted(mMatrix) * Vector4(lightDir.x, lightDir.y, lightDir.z, 0.0);
      localDir.normalize();
      gl.uniform3fv(uniformLightDirection, localDir.xyz.storage);
    }
  }

  void setPointLights(Matrix4 mMatrix) {
    if (_pointLights.isNotEmpty) {}
  }
}
