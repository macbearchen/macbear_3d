//  GLSL program OpenGL shader-language
//  Created by Macbear on 2025/9/24.

// Macbear3D engine
import '../../macbear_3d.dart';

// part for program
part 'program_eye.dart';
part 'program_lighting.dart';
part 'program_shadowmap.dart';

/// A WebGL shader program wrapper for GLSL vertex and fragment shaders.
///
/// Manages uniform locations, vertex attributes, and matrix transformations.
class M3Program {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  // shader program
  late WebGLShader _shaderVert;
  late WebGLShader _shaderFrag;

  late Program program;

  // uniform part:
  late UniformLocation uniformProjection; // "Projection" matrix
  late UniformLocation uniformModelview; // "Modelview" matrix
  late UniformLocation uniformMVP; // "ModelviewProjection" matrix of (Projection * Modelview)

  late UniformLocation uniformTexMatrix; // "uTexMatrix" for texture-matrix
  late UniformLocation uniformSamplerDiffuse; // texture "SamplerDiffuse"
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
    // vertrx shader
    _shaderVert = gl.createShader(WebGL.VERTEX_SHADER);
    gl.shaderSource(_shaderVert, strVert);
    gl.compileShader(_shaderVert);

    // fragment shader
    _shaderFrag = gl.createShader(WebGL.FRAGMENT_SHADER);
    gl.shaderSource(_shaderFrag, strFrag);
    gl.compileShader(_shaderFrag);

    // create program and attach shader
    program = gl.createProgram();
    gl.attachShader(program, _shaderVert);
    gl.attachShader(program, _shaderFrag);

    // bind attrib location before glLinkProgram
    // nvidia:
    // (0) gl_Vertex
    // (2) gl_Normal
    // (3) gl_Color
    // (4) gl_SecondaryColor
    // (5) gl_FogCoord
    // (8) gl_MultiTexCoord0
    // (9) gl_MultiTexCoord1...
    gl.bindAttribLocation(program, 0, "inVertex");
    gl.bindAttribLocation(program, 1, "inColor");
    gl.bindAttribLocation(program, 2, "inNormal");
    gl.bindAttribLocation(program, 3, "inTexCoord");
    gl.bindAttribLocation(program, 4, "inBoneIndex");
    gl.bindAttribLocation(program, 5, "inBoneWeight");

    gl.linkProgram(program);
    gl.useProgram(program);

    // prepare uniform and attrib location
    initLocation();

    // shader log
    String? strLog = gl.getShaderInfoLog(_shaderFrag);
    strLog != null ? debugPrint(strLog) : null;
    strLog = gl.getShaderInfoLog(_shaderVert);
    strLog != null ? debugPrint(strLog) : null;

    // check GL error
    gl.checkError();
  }

  void initLocation() {
    uniformProjection = gl.getUniformLocation(program, "Projection");
    uniformModelview = gl.getUniformLocation(program, "Modelview");
    uniformMVP = gl.getUniformLocation(program, "ModelviewProjection");

    uniformColor = gl.getUniformLocation(program, "uColor");
    uniformTexMatrix = gl.getUniformLocation(program, "uTexMatrix");
    uniformSamplerDiffuse = gl.getUniformLocation(program, "SamplerDiffuse");
    uniformCameraViewport = gl.getUniformLocation(program, "CameraViewport");

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

    if (uniformSamplerDiffuse.id >= 0) {
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
    if (uniformProjection.id >= 0) {
      gl.uniformMatrix4fv(uniformProjection, false, mat.storage);
    }
  }

  void setModelViewMatrix(Matrix4 mat) {
    if (uniformModelview.id >= 0) {
      gl.uniformMatrix4fv(uniformModelview, false, mat.storage);
    }
  }

  void setMVPMatrix(Matrix4 mat) {
    if (uniformMVP.id >= 0) {
      gl.uniformMatrix4fv(uniformMVP, false, mat.storage);
    }
  }

  void applyCamera(M3Camera cam) {}

  void setMatrices(M3Camera cam, Matrix4 mMatrix) {
    // Projection matrix
    setProjectionMatrix(cam.projectionMatrix);

    // ModelView matrix
    Matrix4 mvMatrix = cam.viewMatrix * mMatrix;
    setModelViewMatrix(mvMatrix);

    // ModelView-Projection matrix
    if (uniformMVP.id >= 0) {
      Matrix4 mvpMatrix = cam.projectionMatrix * mvMatrix;
      setMVPMatrix(mvpMatrix);
    }
  }

  void setMaterial(M3Material mtr, Vector4 color) {
    if (uniformColor.id >= 0) {
      // mColor4 colorMix;
      // colorMix = color * mtr.m_diffuse;
      // only work when NOT glEnableVertexAttribArray(m_attribColor)
      // gl.vertexAttrib4fv(attribColor.id, pRGBA); // diffuse as glColor4f in fixed-function GL 1.x

      gl.uniform4fv(uniformColor, color.storage);
    }

    // texture matrix
    if (uniformTexMatrix.id >= 0) {
      gl.uniformMatrix3fv(uniformTexMatrix, false, mtr.texMatrix.storage);
    }
    // diffuse-texture: GL_TEXTURE0
    if (uniformSamplerDiffuse.id >= 0) {
      gl.activeTexture(WebGL.TEXTURE0);
      mtr.texDiffuse.bind(); // 2D or Cubemap
    }
  }

  void disableAttribute() {
    if (attribVertex.id >= 0) {
      gl.disableVertexAttribArray(attribVertex.id);
    }
    if (attribNormal.id >= 0) {
      gl.disableVertexAttribArray(attribNormal.id);
    }
    if (attribUV.id >= 0) {
      gl.disableVertexAttribArray(attribUV.id);
    }
  }
}
