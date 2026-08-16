// ignore_for_file: file_names
import 'package:flutter/material.dart' as fm;
import '../main_all.dart';

// ignore: camel_case_types
class CubeScene_01 extends DemoScene {
  late M3LineGeom _line;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(-pi / 9, -pi / 4, 0, distance: 24);

    _line = M3LineGeom(Vector3(0, 0, 0), Vector3(1, 1, 1));

    // 01: box geometry
    for (int i = 0; i < 10; i++) {
      for (int j = 0; j < 10; j++) {
        for (int k = 0; k < 1; k++) {
          final pos = Vector3(i * 2 - 10, j * 2 - 10, k * 2);
          final box = addMesh(M3Mesh(M3BoxGeom(1.0, 1.0, 1.0)), pos);
          // final ball = addMesh(M3Mesh(M3Resources.unitSphere), Vector3(i * 2, j * 2, k * 2));
          // box.scale.setValues(1, 1, 1);
        }
      }
    }

    // axis gizmo
    addMesh(M3Resources.axisGizmoMesh, Vector3(0, 0, 0));

    final texName = "example/test_8x8.astc";
    final texName2 = "example/nvlobby_xneg.jpg";
    M3Texture texTest = await M3Texture.loadTexture(texName);
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 8,
      lightColor: Vector4(0.65, 0.45, 0.25, 1),
      darkColor: Vector4(0.36, 0.22, 0.12, 1),
    );
    // ground plane
    final mtrGround = M3Material()
      // ..diffuseTexture = texTest
      ..setMatte();
    final groundMesh = M3Mesh(
      M3PlaneGeom(100, 100, widthSegments: 4, heightSegments: 4, uvScale: Vector2.all(10.0)),
      material: mtrGround,
    );
    final entity = addMesh(groundMesh, Vector3(0, 0, -1));
    // entity.color = Vector4(1, 0.6, 0, 1);
  }

  @override
  void drawHelper(M3HelperType helperType) {
    super.drawHelper(helperType);

    // draw line
    M3Material mtr = M3Material();

    final prog = M3Resources.programSimple!;
    prog.setMatrices(camera, Matrix4.identity());
    prog.setMaterial(mtr, Colors.red);
    _line.drawLine(prog, Vector3(0, 0, 3), Vector3(-5, 5, 1));
  }

  @override
  fm.Widget buildUI(fm.BuildContext context) {
    const String info =
        '''
Welcome to 麥克熊 3D.
${M3AppEngine.version}

Click buttons to test examples.
  1. Cube scene
  2. Skybox scene
  3. Primitives scene
  4. Obj teapot scene
  5. Animated scene: Gltf, BVH
  6. Terrain LOD and Water scene
  7. Physics scene
  8. Text 3D scene
  9. PBR Test scene''';
    return fm.SafeArea(
      bottom: false,
      child: fm.Container(
        padding: const fm.EdgeInsets.all(12),
        decoration: fm.BoxDecoration(color: fm.Colors.black54, borderRadius: fm.BorderRadius.circular(12)),
        child: fm.Column(
          mainAxisSize: fm.MainAxisSize.min,
          crossAxisAlignment: fm.CrossAxisAlignment.start,
          children: [
            const fm.Text(
              info,
              style: fm.TextStyle(color: fm.Colors.white, fontWeight: fm.FontWeight.bold),
            ),
            const fm.SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
