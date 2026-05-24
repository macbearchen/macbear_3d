//  GLSL program OpenGL shader-language
//  Created by Macbear on 2025/9/24.

// Macbear3D engine
import '../m3_internal.dart';

// part for program
part 'program_eye.dart';
part 'program_lighting.dart';
part 'program_shadowmap.dart';
part 'program_water.dart';

/// A WebGL shader program wrapper for GLSL vertex and fragment shaders.
///
/// Manages uniform locations, vertex attributes, and matrix transformations.
///
/// command:
///   dart run build_runner build --delete-conflicting-outputs
class M3Program {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  static bool isLocationValid(UniformLocation? loc) {
    final id = loc?.id;
    return id != null && (id is! int || id >= 0);
  }

  // shader program
  late WebGLShader _shaderVert;
  late WebGLShader _shaderFrag;

  late Program program;

  // uniform part:
  late UniformLocation uniformProjection; // "Projection" matrix
  late UniformLocation uniformModel; // "Model" matrix
  late UniformLocation uniformMVP; // "ModelviewProjection" matrix of (Projection * Modelview)

  late UniformLocation uniformTexMatrix; // "uTexMatrix" for texture-matrix
  late UniformLocation uniformSamplerDiffuse; // texture "SamplerDiffuse"
  late UniformLocation uniformParamPBR; // x: Metallic, y: Roughness, z: Mipmap-level
  late UniformLocation uniformSamplerEnvironment;

  late UniformLocation uniformCameraViewport; // camera viewport

  // vertex-attribute part:
  late UniformLocation attribVertex; // vertex "inVertex"
  late UniformLocation attribColor; // vertex "inColor"
  late UniformLocation attribNormal; // vertex "inNormal"
  late UniformLocation attribUV; // texture coordinate UV

  late UniformLocation uniformColor; // "uColor" for color mesh

  // vertex by bone-skinning/weight
  late UniformLocation uniformBoneCount; // "BonesCount" for mesh-vertex
  late UniformLocation uniformBoneMatrixArray; // "BoneMatrixArray" matrix-array
  late UniformLocation uniformBoneMatrixArrayIT; // "BoneMatrixArrayIT" inverse-tranpose-matrix-array
  late UniformLocation attribBoneIndex; // bone-index
  late UniformLocation attribBoneWeight; // bone-weight

  /// Compiles and links a shader program from vertex and fragment sources.
  M3Program(String strVert, String strFrag) {
    // Ensure #version directive is at the very beginning if present
    strVert = _ensureVersionAtStart(strVert);
    strFrag = _ensureVersionAtStart(strFrag);

    final bool isES3 = strVert.startsWith("#version 300 es") || strFrag.startsWith("#version 300 es");

    // vertrx shader
    _shaderVert = gl.createShader(WebGL.VERTEX_SHADER);
    gl.shaderSource(_shaderVert, strVert);
    gl.compileShader(_shaderVert);

    // check shader compile status
    if (gl.getShaderParameter(_shaderVert, WebGL.COMPILE_STATUS) == false) {
      final log = gl.getShaderInfoLog(_shaderVert);
      debugPrint("--- VERTEX SHADER COMPILE ERROR ---\n$log\n--- SOURCE ---\n$strVert");
    }

    // fragment shader
    _shaderFrag = gl.createShader(WebGL.FRAGMENT_SHADER);
    gl.shaderSource(_shaderFrag, strFrag);
    gl.compileShader(_shaderFrag);

    // check shader compile status
    if (gl.getShaderParameter(_shaderFrag, WebGL.COMPILE_STATUS) == false) {
      final log = gl.getShaderInfoLog(_shaderFrag);
      debugPrint("--- FRAGMENT SHADER COMPILE ERROR ---\n$log\n--- SOURCE ---\n$strFrag");
    }

    // create program and attach shader
    program = gl.createProgram();
    gl.attachShader(program, _shaderVert);
    gl.attachShader(program, _shaderFrag);

    // bind attrib location before glLinkProgram (if not using layout in ES3)
    if (!isES3) {
      gl.bindAttribLocation(program, 0, "inVertex");
      gl.bindAttribLocation(program, 1, "inColor");
      gl.bindAttribLocation(program, 2, "inNormal");
      gl.bindAttribLocation(program, 3, "inTexCoord");
      gl.bindAttribLocation(program, 4, "inBoneIndex");
      gl.bindAttribLocation(program, 5, "inBoneWeight");
    }

    gl.linkProgram(program);

    // check link status
    final param = gl.getProgramParameter(program, WebGL.LINK_STATUS);
    if (param.id == false) {
      final log = gl.getProgramInfoLog(program);
      debugPrint("--- PROGRAM LINK ERROR ---\n$log");
    }

    gl.useProgram(program);

    // prepare uniform and attrib location
    initLocation();

    // check GL error
    gl.checkError();
  }

  String _ensureVersionAtStart(String source) {
    const versionHeader = "#version 300 es";
    String cleanSource = source;

    // 1. Find and remove all #version headers
    bool hasVersion = false;
    if (cleanSource.contains(versionHeader)) {
      cleanSource = cleanSource.replaceAll(versionHeader, "");
      hasVersion = true;
    }

    // 2. Find and remove all #extension headers
    final extensionRegExp = RegExp(r"^#extension\s+.+:(enable|require).*$", multiLine: true);
    final Iterable<Match> matches = extensionRegExp.allMatches(cleanSource);
    final List<String> extensions = matches.map((m) => m.group(0)!.trim()).toList();
    cleanSource = cleanSource.replaceAll(extensionRegExp, "");

    // 3. Rebuild source: #version first, then #extensions, then the rest
    final buffer = StringBuffer();
    if (hasVersion) {
      buffer.writeln(versionHeader);
    }
    for (final ext in extensions) {
      buffer.writeln(ext);
    }
    buffer.write(cleanSource.trim());

    return buffer.toString();
  }

  void initLocation() {
    uniformProjection = gl.getUniformLocation(program, "Projection");
    uniformModel = gl.getUniformLocation(program, "Model");
    uniformMVP = gl.getUniformLocation(program, "ModelviewProjection");

    uniformColor = gl.getUniformLocation(program, "uColor");
    uniformTexMatrix = gl.getUniformLocation(program, "uTexMatrix");
    uniformSamplerDiffuse = gl.getUniformLocation(program, "SamplerDiffuse");
    uniformParamPBR = gl.getUniformLocation(program, "uParamPBR");
    uniformSamplerEnvironment = gl.getUniformLocation(program, "SamplerEnvironment");

    uniformCameraViewport = gl.getUniformLocation(program, "CameraViewport");

    // Set up some default material parameters.
    if (M3Program.isLocationValid(uniformParamPBR)) {
      gl.uniform3f(uniformParamPBR, 0.0, 0.5, 3.0);
    }

    // vertex-attrib
    attribVertex = gl.getAttribLocation(program, "inVertex");
    attribColor = gl.getAttribLocation(program, "inColor");
    attribNormal = gl.getAttribLocation(program, "inNormal");
    attribUV = gl.getAttribLocation(program, "inTexCoord");
    // bones matrix-array
    uniformBoneCount = gl.getUniformLocation(program, "BoneCount");
    uniformBoneMatrixArray = gl.getUniformLocation(program, "BoneMatrixArray");
    uniformBoneMatrixArrayIT = gl.getUniformLocation(program, "BoneMatrixArrayIT");
    // vertex by bone-skinning
    attribBoneIndex = gl.getAttribLocation(program, "inBoneIndex");
    attribBoneWeight = gl.getAttribLocation(program, "inBoneWeight");

    if (isLocationValid(uniformSamplerDiffuse)) {
      // Set the active sampler to stage 0.  Not really necessary since the uniform
      // defaults to zero anyway, but good practice.
      gl.activeTexture(WebGL.TEXTURE0);
      gl.uniform1i(uniformSamplerDiffuse, 0); // GL_TEXTURE0 for active-texture
    }
  }

  void dispose() {
    // delete program, shader
    gl.deleteProgram(program);
    gl.deleteShader(_shaderFrag);
    gl.deleteShader(_shaderVert);
  }

  void setProjectionMatrix(Matrix4 mat) {
    if (isLocationValid(uniformProjection)) {
      gl.uniformMatrix4fv(uniformProjection, false, mat.storage);
    }
  }

  void setModelMatrix(Matrix4 mat) {
    if (isLocationValid(uniformModel)) {
      gl.uniformMatrix4fv(uniformModel, false, mat.storage);
    }
  }

  void setMVPMatrix(Matrix4 mat) {
    if (isLocationValid(uniformMVP)) {
      gl.uniformMatrix4fv(uniformMVP, false, mat.storage);
    }
  }

  /// unused for now
  void applyCamera(M3Camera cam) {
    if (isLocationValid(uniformCameraViewport)) {
      gl.uniform4f(
        uniformCameraViewport,
        cam.viewportX.toDouble(),
        cam.viewportY.toDouble(),
        cam.viewportW.toDouble(),
        cam.viewportH.toDouble(),
      );
    }
  }

  void setMatrices(M3Camera cam, Matrix4 mMatrix) {
    // Projection matrix
    setProjectionMatrix(cam.projectionMatrix);

    // Model matrix
    setModelMatrix(mMatrix);

    // ModelView-Projection matrix
    if (isLocationValid(uniformMVP)) {
      Matrix4 mvpMatrix = cam.projectionMatrix * cam.viewMatrix * mMatrix;
      setMVPMatrix(mvpMatrix);
    }
  }

  void setMaterial(M3Material mtr, Vector4 color) {
    if (isLocationValid(uniformColor)) {
      // mColor4 colorMix;
      // colorMix = color * mtr.m_diffuse;
      // only work when NOT glEnableVertexAttribArray(m_attribColor)
      // gl.vertexAttrib4fv(attribColor.id, pRGBA); // diffuse as glColor4f in fixed-function GL 1.x

      gl.uniform4fv(uniformColor, color.storage);
    }

    // texture matrix
    if (isLocationValid(uniformTexMatrix)) {
      gl.uniformMatrix3fv(uniformTexMatrix, false, mtr.texMatrix.storage);
    }
    // diffuse-texture: GL_TEXTURE0
    if (isLocationValid(uniformSamplerDiffuse)) {
      gl.activeTexture(WebGL.TEXTURE0);
      mtr.diffuseTexture.bind(); // 2D or Cubemap
    }

    // PBR
    if (M3Program.isLocationValid(uniformParamPBR)) {
      gl.uniform3f(uniformParamPBR, mtr.metallic, mtr.roughness, mtr.mipLevel.toDouble());
    }
  }

  void setEnvironmentMap(M3Texture cubemap) {
    if (isLocationValid(uniformSamplerEnvironment)) {
      gl.uniform1i(uniformSamplerEnvironment, 2);
      gl.activeTexture(WebGL.TEXTURE2); // bind cubemap to GL_TEXTURE2
      cubemap.bind(); // Cubemap
      gl.activeTexture(WebGL.TEXTURE0); // restore back to GL_TEXTURE0
    }
  }

  void setSkinning(M3Skin? skin) {
    // Skinned Mesh support
    if (isLocationValid(uniformBoneCount)) {
      gl.uniform1i(uniformBoneCount, skin?.boneCount ?? 0);

      if (skin != null) {
        final boneArray = Float32List(skin.boneCount * 16);
        for (int i = 0; i < skin.boneCount; i++) {
          boneArray.setAll(i * 16, skin.boneMatrices[i].storage);
        }
        gl.uniformMatrix4fv(uniformBoneMatrixArray, false, boneArray);
      }
    }
  }

  void disableAttribute() {
    if (isLocationValid(attribVertex)) {
      gl.disableVertexAttribArray(attribVertex.id);
    }
    if (isLocationValid(attribNormal)) {
      gl.disableVertexAttribArray(attribNormal.id);
    }
    if (isLocationValid(attribUV)) {
      gl.disableVertexAttribArray(attribUV.id);
    }
  }
}
