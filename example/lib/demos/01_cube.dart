// ignore_for_file: unused_local_variable, file_names
import 'demo_scene.dart';

// ignore: camel_case_types
class CubeScene_01 extends DemoScene {
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(-pi / 9, -pi / 4, 0, distance: 24);
    skybox = await createCubemapLobby(); // nvlobby cubemap

    final num = 7;
    final spacingX = 2.5;
    final spacingY = 2.5;
    // 01: box geometry
    for (int i = 0; i < num; i++) {
      for (int j = 0; j < num; j++) {
        for (int k = 0; k < 2; k++) {
          final pos = Vector3((i - num * 0.5) * spacingX, (j - num * 0.5) * spacingY, k * 1.2);
          final sz = 1.0;
          if (k % 2 == 0) {
            addMesh(M3Mesh(M3BoxGeom(sz, sz, sz)), pos);
          } else {
            addMesh(M3Mesh(M3Resources.unitSphere), pos);
          }
        }
      }
    }

    // axis gizmo
    addMesh(M3Resources.axisGizmoMesh, Vector3(0, 0, 0));

    final texName = "example/test_8x8.astc";
    final texName2 = "example/nvlobby_xneg.jpg";
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 4,
      lightColor: Vector4(0.80, 0.60, 0.40, 1),
      darkColor: Vector4(0.70, 0.5, 0.3, 1),
    );
    // ground plane
    final mtrGround = M3Material()
      // ..diffuseTexture = texTest
      ..diffuseTexture = texGround
      ..setMatte()
      ..doubleSided = true;

    // final groundMesh = M3Mesh(M3PlaneGeom(100, 100, widthSegments: 4, heightSegments: 4), material: mtrGround);
    final groundMesh = M3TiledPlaneMesh(tilesX: 10, tilesY: 10, tileWidth: 5, tileHeight: 5);
    for (final sub in groundMesh.subMeshes) {
      sub.mtr = mtrGround;
    }
    final entity = addMesh(groundMesh, Vector3(0, 0, -1));
    // entity.color = Vector4(1, 0.6, 0, 1);
  }

  @override
  Widget buildUI(BuildContext context) {
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
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
