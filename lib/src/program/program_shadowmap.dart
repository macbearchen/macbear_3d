part of 'program.dart';

// texture sampler for shadowmap
abstract class M3ProgramShadow extends M3ProgramLighting {
  late UniformLocation uniformSamplerShadowmap;
  late UniformLocation uniformShadowmapSize;
  late UniformLocation uniformNormalBias;

  M3ProgramShadow(super.strVert, super.strFrag);

  @override
  void initLocation() {
    super.initLocation();

    uniformSamplerShadowmap = gl.getUniformLocation(program, "SamplerShadowmap");
    uniformShadowmapSize = gl.getUniformLocation(program, "ShadowmapSize");
    uniformNormalBias = gl.getUniformLocation(program, "NormalBias");

    if (uniformSamplerShadowmap.id >= 0) {
      gl.uniform1i(uniformSamplerShadowmap, 1);
    }
  }

  @override
  void applyLight(M3Light sceneLight) {
    super.applyLight(sceneLight);

    if (uniformShadowmapSize.id >= 0) {
      final shadowMap = M3AppEngine.instance.renderEngine.shadowMap!;
      gl.uniform2f(uniformShadowmapSize, shadowMap.mapW.toDouble(), shadowMap.mapH.toDouble());
    }
    if (uniformNormalBias.id >= 0) {
      gl.uniform1f(uniformNormalBias, sceneLight.shadowNormalBias);
    }
  }

  void bindShadow(WebGLTexture texture) {
    gl.activeTexture(WebGL.TEXTURE1);
    gl.bindTexture(WebGL.TEXTURE_2D, texture);
    gl.uniform1i(uniformSamplerShadowmap, 1);

    gl.activeTexture(WebGL.TEXTURE0);
  }
}

class M3ProgramShadowmap extends M3ProgramShadow {
  late UniformLocation uniformMatrixShadowmap;

  M3ProgramShadowmap(super.strVert, super.strFrag);

  @override
  void initLocation() {
    super.initLocation();

    uniformMatrixShadowmap = gl.getUniformLocation(program, "MatrixShadowmap");
  }

  @override
  void setMatrices(M3Camera cam, Matrix4 mMatrix) {
    super.setMatrices(cam, mMatrix);

    final light = _light!;
    if (uniformMatrixShadowmap.id >= 0) {
      // light-space
      Matrix4 lightMatrix = light.projectionMatrix * light.viewMatrix * mMatrix;
      Matrix4 shadowMatrix = M3Constants.biasMatrix * lightMatrix;
      gl.uniformMatrix4fv(uniformMatrixShadowmap, false, shadowMatrix.storage);
    }
  }
}

class M3ProgramShadowCSM extends M3ProgramShadow {
  late UniformLocation uniformMatrixCSM;
  late UniformLocation uniformDepthCSM;

  M3ProgramShadowCSM(super.strVert, super.strFrag);

  @override
  void initLocation() {
    super.initLocation();

    uniformMatrixCSM = gl.getUniformLocation(program, "MatrixCSM");
    uniformDepthCSM = gl.getUniformLocation(program, "DepthCSM");
  }

  @override
  void applyCamera(M3Camera cam) {
    super.applyCamera(cam);

    if (uniformDepthCSM.id >= 0) {
      final maxCSM = 4;
      final numCSM = min(maxCSM, cam.csmCount);

      Float32List depthBuffer = Float32List(maxCSM);
      for (int i = 0; i < numCSM; i++) {
        // eye-depth to frag-z
        final eyeDepth = cam.csmSplitDistances[i + 1];
        depthBuffer[i] = cam.eyeDepthToFragZFromMatrix(eyeDepth);
      }
      gl.uniform4fv(uniformDepthCSM, depthBuffer);
    }
  }

  @override
  void setMatrices(M3Camera cam, Matrix4 mMatrix) {
    super.setMatrices(cam, mMatrix);

    final light = _light!;
    if (uniformMatrixCSM.id >= 0) {
      final maxCSM = 4;
      final numCSM = min(maxCSM, light.cascades.length);

      Float32List matricesBuffer = Float32List(maxCSM * 16);
      Matrix4 biasMatrix = Matrix4.copy(M3Constants.biasMatrix);

      for (int i = 0; i < numCSM; i++) {
        final cascade = light.cascades[i];
        // bias matrix
        final halfH = cascade.atlasScaleV / 2;
        biasMatrix.setEntry(1, 1, halfH);
        biasMatrix.setEntry(1, 3, halfH + cascade.atlasBiasV);

        // light-space
        Matrix4 lightMatrix = cascade.projectionMatrix * light.viewMatrix * mMatrix;
        Matrix4 shadowMatrix = biasMatrix * lightMatrix;
        matricesBuffer.setRange(i * 16, i * 16 + 16, shadowMatrix.storage);
      }

      gl.uniformMatrix4fv(uniformMatrixCSM, false, matricesBuffer);
    }
  }
}
