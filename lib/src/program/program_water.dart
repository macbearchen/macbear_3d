part of 'program.dart';

/// water distortion shader program
class M3ProgramWater extends M3ProgramLighting with M3WaterShader {
  M3ProgramWater(super.strVert, super.strFrag);

  @override
  void initLocation() {
    super.initLocation();

    initWaterLocation(program);
  }

  void setLightTBN(Vector3 tangent, Vector3 binormal, Vector3 normal) {
    if (_light != null) {
      Vector3 srcLight = _light!.position;
      Vector3 tangentLight = Vector3(srcLight.dot(tangent), srcLight.dot(binormal), srcLight.dot(normal));
      gl.uniform3fv(uniformLightDirection, tangentLight.storage);
    }
    // water TBN
    _setTBN(tangent, binormal, normal);
  }
}

/// water distortion shader program with CSM
class M3ProgramWaterCSM extends M3ProgramShadowCSM with M3WaterShader {
  M3ProgramWaterCSM(super.strVert, super.strFrag);

  @override
  void initLocation() {
    super.initLocation();

    initWaterLocation(program);
  }

  void setLightTBN(Vector3 tangent, Vector3 binormal, Vector3 normal) {
    if (_light != null) {
      Vector3 srcLight = _light!.position;
      Vector3 tangentLight = Vector3(srcLight.dot(tangent), srcLight.dot(binormal), srcLight.dot(normal));
      gl.uniform3fv(uniformLightDirection, tangentLight.storage);
    }
    // water TBN
    _setTBN(tangent, binormal, normal);
  }
}
