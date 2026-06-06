part of 'program.dart';

// water distortion shader program
class M3ProgramWater extends M3ProgramLighting {
  late UniformLocation uniformBumpTranslateScale0; // bump translation, scale
  late UniformLocation uniformBumpTranslateScale1; // bump translation, scale
  late UniformLocation uniformWaveDistortion; // wave distortion

  // tangent-space: tangent, binormal, normal
  late UniformLocation uniformAxisTangent;
  late UniformLocation uniformAxisBinormal;
  late UniformLocation uniformAxisNormal;

  M3ProgramWater(super.strVert, super.strFrag, {super.reflectionType});

  @override
  void initLocation() {
    super.initLocation();

    uniformBumpTranslateScale0 = gl.getUniformLocation(program, "BumpTranslateScale0");
    uniformBumpTranslateScale1 = gl.getUniformLocation(program, "BumpTranslateScale1");
    uniformWaveDistortion = gl.getUniformLocation(program, "WaveDistortion");

    uniformAxisTangent = gl.getUniformLocation(program, "AxisTangent");
    uniformAxisBinormal = gl.getUniformLocation(program, "AxisBinormal");
    uniformAxisNormal = gl.getUniformLocation(program, "AxisNormal");

    // Set the sampler2D variables
    gl.uniform1i(gl.getUniformLocation(program, "NormalTex"), 1); // GL_TEXTURE1
    gl.uniform1i(gl.getUniformLocation(program, "RefractionTex"), 2); // GL_TEXTURE2
  }

  void bindWater(M3Water water) {
    // Bind texture
    gl.activeTexture(WebGL.TEXTURE1);
    water.normalMap.bind();

    gl.activeTexture(WebGL.TEXTURE2);
    if (water.refractionPass != null) {
      water.refractionPass!.texture.bind();
    } else {
      M3Resources.texWhite.bind();
    }

    // diffuse by reflection
    gl.activeTexture(WebGL.TEXTURE0);
    if (water.reflectionPass != null) {
      water.reflectionPass!.texture.bind();
    } else {
      M3Resources.texWhite.bind();
    }

    // uniform param for bump of water (per GLSL)
    gl.uniform4f(
      uniformBumpTranslateScale0,
      water.flow0.offset.x,
      water.flow0.offset.y,
      water.flow0.scale.x,
      water.flow0.scale.y,
    );
    gl.uniform4f(
      uniformBumpTranslateScale1,
      water.flow1.offset.x,
      water.flow1.offset.y,
      water.flow1.scale.x,
      water.flow1.scale.y,
    );
    gl.uniform1f(uniformWaveDistortion, water.waveDistortion);
  }

  void setTBN(Vector3 tangent, Vector3 binormal, Vector3 normal) {
    if (_light != null) {
      Vector3 srcLight = _light!.position;
      Vector3 tangentLight = Vector3(srcLight.dot(tangent), srcLight.dot(binormal), srcLight.dot(normal));
      gl.uniform3fv(uniformLightPosition, tangentLight.storage);
    }
    // tangent-space: tangent, binormal, normal
    gl.uniform3fv(uniformAxisTangent, tangent.storage);
    gl.uniform3fv(uniformAxisBinormal, binormal.storage);
    gl.uniform3fv(uniformAxisNormal, normal.storage);
  }
}
