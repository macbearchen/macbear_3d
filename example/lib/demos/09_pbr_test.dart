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

    int rows = 5;
    int cols = 5;
    double spacing = 2.5;

    for (int i = 0; i < rows; i++) {
      double metallic = i / (rows - 1);
      for (int j = 0; j < cols; j++) {
        double roughness = j / (cols - 1);

        final mesh = M3Mesh(sphereGeom);
        mesh.subMeshes[0].mtr
          ..diffuse = Vector4(0.0, 1.0, 0.0, 1.0)
          ..reflection = metallic
          ..metallic = metallic
          ..roughness = max(roughness, 0.05); // Avoid zero roughness for GGX

        double x = (i - (rows - 1) / 2) * spacing;
        double y = (j - (cols - 1) / 2) * spacing;

        final ball = addMesh(mesh, Vector3(x, y, 0));
        ball.rotation.setEuler(i * pi / 10, j * pi / 20, 0);
        ball.scale = Vector3.all(1.5);
      }
    }

    final groundZ = -2.0;
    // Add a ground plane
    final geomPlane = M3PlaneGeom(20, 20);
    final plane = addMesh(M3Mesh(geomPlane), Vector3(0, 0, groundZ));
    plane.mesh.subMeshes[0].mtr
      ..diffuse = Vector4(0.2, 0.9, 0.7, 1.0)
      ..reflection = 0.3
      ..metallic = 0.3
      ..roughness = 0.0
      ..planarReflection = renderEngine.planarReflection;

    // axis gizmo
    addMesh(M3Resources.axisGizmoMesh, Vector3(0, 0, 2));

    // 08-3: Apply mirror shader to ground
    renderEngine.planarReflection.clipPlane.setFromComponents(0, 0, 1, -groundZ);
    renderEngine.planarReflection.setRenderScale(1.0);
  }

  @override
  void update(double delta) {
    super.update(delta);

    // rotate light
    dirLight.setEuler(dirLight.euler.yaw + delta * 0.1, -pi / 3, 0, distance: dirLight.distanceToTarget);

    // Rotate camera slowly
    // camera.setEuler(
    //   camera.euler.yaw + delta * 0.1,
    //   camera.euler.pitch,
    //   camera.euler.roll,
    //   distance: camera.distanceToTarget,
    // );
  }
}
