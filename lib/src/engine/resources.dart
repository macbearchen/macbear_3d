// ignore_for_file: unused_import
// Macbear3D engine
import '../m3_internal.dart';

class M3Resources {
  static RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  // ------------------------------
  // Textures
  // ------------------------------
  // white color for default albedo / emissive / ORM, or fill texture
  static final texWhite = M3Texture.createSolidColor(Vector4(1, 1, 1, 1));
  // black color for default emissive or other purposes
  static final texBlack = M3Texture.createSolidColor(Vector4(0, 0, 0, 1));
  // normal map : (0.5, 0.5, 1.0) is up-direction
  static final texDefaultNormal = M3Texture.createSolidColor(Vector4(0.5, 0.5, 1, 1));
  // default IBL cubemap
  static final texDefaultCubemap = M3Texture.createDefaultIBLCube();
  // oclussion(R), roughness(G), metallic(B)
  static final texDefaultORM = M3Texture.createSolidColor(Vector4(1, 1, 1, 1));

  // axis gizmo mesh
  static M3Mesh? _axisDotMesh;
  static M3Mesh? _axisGizmoMesh;
  static M3Mesh? _frustumMesh;
  static M3Mesh get axisDotMesh => _axisDotMesh ??= M3MeshFactory.createAxisDot();
  static M3Mesh get axisGizmoMesh => _axisGizmoMesh ??= M3MeshFactory.createAxisGizmo();
  static M3Mesh get frustumMesh => _frustumMesh ??= M3MeshFactory.createFrustum();

  // ------------------------------
  // Camera: debug
  // ------------------------------
  static M3Camera? debugCamera;

  // ------------------------------
  // Geometries: debug
  // ------------------------------
  static final debugAxis = M3DebugAxisGeom(size: 0.5);
  static final debugDot = M3OctahedralGeom(0.25);
  static final debugFrustum = M3BoxGeom(2.0, 2.0, 2.0);
  static final debugPointLight = M3SphereGeom(1.0, widthSegments: 8, heightSegments: 4);
  static final debugSphere = M3DebugSphereGeom(radius: 1.0);
  static final debugSpotLight = M3CylinderGeom(topRadius: 0.0, bottomRadius: 0.6, radiusSegments: 10, height: 1.0);
  static final debugView = M3PlaneGeom(1.8, 1.8, widthSegments: 6, heightSegments: 4);

  // ------------------------------
  // Unit geometries
  // ------------------------------
  static final unitCube = M3BoxGeom(1.0, 1.0, 1.0);
  static final unitCylinder = M3CylinderGeom(topRadius: 0.5, bottomRadius: 0.5, height: 1);
  static final unitBone = M3OctahedralGeom(0.5, bias: Vector3(-0.6, 0, 0));
  static final unitOctahedral = M3OctahedralGeom(0.5);
  static final unitSphere = M3SphereGeom(0.5);

  // ------------------------------
  // 2D shapes
  // ------------------------------
  // for dynamic draw: line, triangle
  static M3Shape2D? _line;
  static M3Shape2D? _triangle;

  // text2D from sprite, rectUnit for image
  static M3Text2D? _text2D;
  static M3Rectangle2D? _rectUnit;

  static M3Text2D get text2D {
    return _text2D!;
  }

  static M3Shape2D get line {
    _line ??= M3Shape2D(WebGL.LINES, 2)..createVBO(WebGL.DYNAMIC_DRAW);
    return _line!;
  }

  static M3Shape2D get triangle {
    _triangle ??= M3Shape2D(WebGL.TRIANGLES, 3)..createVBO(WebGL.DYNAMIC_DRAW);
    return _triangle!;
  }

  static M3Rectangle2D get rectUnit {
    _rectUnit ??= M3Rectangle2D()
      ..setRectangle(0, 0, 1, 1)
      ..createVBO(WebGL.STATIC_DRAW);
    return _rectUnit!;
  }

  static Future<void> init() async {
    M3Log.i('M3Resources', 'init starting...');
    // Textures
    texWhite;
    texBlack;
    texDefaultNormal;
    texDefaultCubemap;
    texDefaultORM;
    M3Log.i('M3Resources', 'basic textures initialized');

    // debug camera for directional-light shadow map frustum only
    debugCamera = M3Camera(); // remark to disable debug camera
    debugCamera
      ?..setViewport(0, 0, 8, 5, fovy: 45, near: 1, far: 30)
      ..target.setFrom(Vector3(-10, 0, 1))
      ..setEuler(0, -pi / 5, 0, distance: 4);
    debugCamera = null;

    // Mesh
    axisDotMesh;
    axisGizmoMesh;
    frustumMesh;

    // Geometries
    debugAxis;
    debugDot;
    debugFrustum;
    debugPointLight;
    debugSphere;
    debugSpotLight;
    debugView;

    unitCube;
    unitCylinder;
    unitBone;
    unitOctahedral;
    unitSphere;
    M3Log.i('M3Resources', 'unit geometries initialized');

    // 2D
    line;
    triangle;
    rectUnit;
    _text2D = await M3Text2D.createText2D(fontSize: 30);
    M3Log.i('M3Resources', 'text2D initialized');
  }

  static void dispose() {
    // Textures
    texWhite.dispose();
    texBlack.dispose();
    texDefaultNormal.dispose();
    texDefaultCubemap.dispose();
    texDefaultORM.dispose();

    // Geometries
    debugAxis.dispose();
    debugDot.dispose();
    debugFrustum.dispose();
    debugPointLight.dispose();
    debugSphere.dispose();
    debugSpotLight.dispose();
    debugView.dispose();

    unitCube.dispose();
    unitBone.dispose();
    unitOctahedral.dispose();
    unitSphere.dispose();

    // 2D
    _line?.dispose();
    _triangle?.dispose();
    _rectUnit?.dispose();
    _text2D?.dispose();
  }
}
