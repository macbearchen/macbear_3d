// ignore_for_file: file_names
import 'package:flutter/material.dart' as fm;
import '../main_all.dart';

// ignore: camel_case_types
class CubeScene_01 extends DemoScene {
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    // 01: box geometry
    addMesh(M3Mesh(M3BoxGeom(1.0, 1.0, 1.0)), Vector3.zero());

    // axis gizmo
    addMesh(M3Resources.axisGizmoMesh, Vector3(0, 0, 0));

    // ground plane
    final mtrGround = M3Material()
      ..diffuse = Vector4(0.588, 0.471, 0.353, 1.0)
      ..setMatte();
    final groundMesh = M3Mesh(M3PlaneGeom(20, 20, uvScale: Vector2.all(5.0)), material: mtrGround);
    addMesh(groundMesh, Vector3(0, 0, -1));
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
  6. Shadow for large scene
  7. Physics scene
  8. Text 3D scene
  9. PBR Test scene''';
    return fm.Positioned(
      top: 50,
      left: 8,
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
