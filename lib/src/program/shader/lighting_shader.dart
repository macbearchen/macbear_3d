part of '../program.dart';

/// lighting shader in program
mixin M3LightingShader {
  RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

  late UniformLocation uniformAmbient; // "ColorAmbient" = inColor * LightAmbient * MaterialDiffuse
  late UniformLocation uniformDiffuse; // "ColorDiffuse" = inColor * LightDiffuse * MaterialDiffuse
  late UniformLocation uniformSpecular; // "ColorSpecular" = inColor * LightDiffuse * MaterialSpecular (w: Shininess)

  late UniformLocation uniformLightPosition; // light position "LightPosition" (per object-space)

  M3Light? _light; // active light

  void initLightingLocation(Program prog) {
    uniformAmbient = gl.getUniformLocation(prog, "ColorAmbient");
    uniformDiffuse = gl.getUniformLocation(prog, "ColorDiffuse");
    uniformSpecular = gl.getUniformLocation(prog, "ColorSpecular");

    uniformLightPosition = gl.getUniformLocation(prog, "LightPosition");
  }

  void attachLight(M3Light sceneLight) {
    _light = sceneLight;
  }

  void setLightPosition(Matrix4 mMatrix) {
    if (_light == null) return;

    if (M3Program.isLocationValid(uniformLightPosition)) {
      Vector4 lightDirection = Matrix4.inverted(mMatrix) * _light!.getDirection();
      lightDirection.normalize();
      gl.uniform3fv(uniformLightPosition, lightDirection.xyz.storage);
    }
  }
}
