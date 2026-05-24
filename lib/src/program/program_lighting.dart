part of 'program.dart';

mixin M3LightingShader {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

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

  void applyLight(M3Light sceneLight) {
    _light = sceneLight;
  }
}

class M3ProgramLighting extends M3ProgramEye with M3LightingShader {
  // shader fog

  M3ProgramLighting(super.strVert, super.strFrag);

  @override
  void initLocation() {
    super.initLocation();

    initLightingLocation(program);
  }

  @override
  void setMatrices(M3Camera cam, Matrix4 mMatrix) {
    super.setMatrices(cam, mMatrix);

    final light = _light!;
    if (M3Program.isLocationValid(uniformLightPosition)) {
      Vector4 lightDirection = Matrix4.inverted(mMatrix) * light.getDirection();
      lightDirection.normalize();
      gl.uniform3fv(uniformLightPosition, lightDirection.xyz.storage);
    }
  }

  @override
  void setMaterial(M3Material mtr, Vector4 color) {
    super.setMaterial(mtr, color);

    Vector4 outDiffuse = M3Light.blendRGBA(mtr.diffuse, color);

    // ambient: RGB
    if (M3Program.isLocationValid(uniformAmbient)) {
      Vector3 outAmbient = M3Light.blendRGB(M3Light.ambient, outDiffuse.rgb);
      gl.uniform3fv(uniformAmbient, outAmbient.storage);
    }

    // diffuse: RGBA
    if (M3Program.isLocationValid(uniformDiffuse)) {
      outDiffuse.xyz = M3Light.blendRGB(_light!.color, outDiffuse.rgb);
      gl.uniform4fv(uniformDiffuse, outDiffuse.storage);
    }

    // specular: RGB
    if (M3Program.isLocationValid(uniformSpecular)) {
      Vector3 outSpecular = M3Light.blendRGB(mtr.specular, color.rgb);
      outSpecular = M3Light.blendRGB(_light!.color, outSpecular);

      // Pass as vec4: RGB, w = Shininess
      gl.uniform4f(uniformSpecular, outSpecular.x, outSpecular.y, outSpecular.z, mtr.shininess);
    }
  }
}
