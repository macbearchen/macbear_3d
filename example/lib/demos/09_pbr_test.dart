// ignore_for_file: file_names
import '../main_all.dart';

// ignore: camel_case_types
class PbrTestScene_09 extends DemoScene {
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(-pi / 12, -pi / 8, 0, distance: 30);

    skybox = await createCubemapLobby(); // nvlobby cubemap

    final sphereGeom = M3Resources.unitSphere;

    int rows = 6;
    int cols = 6;
    double spacing = 3.5;

    for (int i = 0; i < rows; i++) {
      double metallic = i / (rows - 1);
      for (int j = 0; j < cols; j++) {
        double roughness = j / (cols - 1);

        final mesh = M3Mesh(sphereGeom);
        mesh.subMeshes[0].mtr
          ..diffuse = Vector4(1.0, 1.0, 0.8, 1.0)
          ..reflection = metallic
          ..metallic = metallic
          ..roughness = max(roughness, 0.05); // Avoid zero roughness for GGX

        double x = (i - (rows - 1) / 2) * spacing;
        double y = (j - (cols - 1) / 2) * spacing;

        final ball = addMesh(mesh, Vector3(x, y, -1));
        ball.rotation.setEuler(i * pi / 10, j * pi / 20, 0);
        ball.scale = Vector3.all((i + 40) * 0.05);
      }
    }

    final groundZ = -2.2;
    // Add a ground plane
    // final planeMesh = M3Mesh(M3PlaneGeom(30, 30));
    final planeMesh = M3TiledPlaneMesh(tilesX: 5, tilesY: 5, tileWidth: 5, tileHeight: 5);
    final plane = addMesh(planeMesh, Vector3(0, 0, groundZ));
    int i = 0;
    for (M3SubMesh sub in plane.mesh.subMeshes) {
      sub.mtr
        ..diffuse = Vector4(0.6, 0.9, 0.7, 1.0)
        ..reflection = 0.3
        ..metallic = 0.3
        ..roughness = 0.0
        ..planarReflection = (i % 2 == 0) ? null : renderEngine.planarReflection;
      i++;
    }

    // axis gizmo
    addMesh(M3Resources.axisGizmoMesh, Vector3(0, 0, 0));

    // 08-3: Apply mirror shader to ground
    renderEngine.planarReflection.clipPlane.setFromComponents(0, 0, 1, -groundZ);
    renderEngine.planarReflection.setRenderScale(1.0);
  }

  @override
  void update(double delta) {
    super.update(delta);

    // Rotate camera slowly
    final euler = camera.euler;
    camera.setEuler(euler.yaw + delta * 0.1, euler.pitch, 0, distance: camera.distanceToTarget);
  }
}
