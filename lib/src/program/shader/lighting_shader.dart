part of '../program.dart';

/// lighting shader in program
mixin M3LightingShader {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  late UniformLocation uniformAmbient; // "ColorAmbient" = inColor * LightAmbient * MaterialDiffuse
  late UniformLocation uniformDiffuse; // "ColorDiffuse" = inColor * LightDiffuse * MaterialDiffuse
  late UniformLocation uniformSpecular; // "ColorSpecular" = inColor * LightDiffuse * MaterialSpecular (w: Shininess)

  late UniformLocation uniformLightDirection; // light direction "uLightDir" (per object-space)

  M3DirectionalLight? _light; // active light
  final List<M3PointLight> _pointLights = [];

  void initLightingLocation(Program prog) {
    uniformAmbient = gl.getUniformLocation(prog, "ColorAmbient");
    uniformDiffuse = gl.getUniformLocation(prog, "ColorDiffuse");
    uniformSpecular = gl.getUniformLocation(prog, "ColorSpecular");

    uniformLightDirection = gl.getUniformLocation(prog, "uLightDir");
  }

  void attachLight(M3DirectionalLight dirLight) {
    _light = dirLight;
  }

  void setLightDirection(Matrix4 mMatrix) {
    if (_light == null) return;

    if (M3Program.isLocationValid(uniformLightDirection)) {
      Vector3 lightDir = _light!.getDirection();
      Vector4 localDir = Matrix4.inverted(mMatrix) * Vector4(lightDir.x, lightDir.y, lightDir.z, 0.0);
      localDir.normalize();
      gl.uniform3fv(uniformLightDirection, localDir.xyz.storage);
    }
  }
}
