import '../main_all.dart';

class DemoScene extends M3Scene {
  DemoScene({super.physics});

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    M3AppEngine.backgroundColor = Vector3(0.1, 0.3, 0.15);
    camera.setEuler(pi / 6, -pi / 6, 0, distance: 12);

    // skybox = await createCubemapLobby(); // nvlobby cubemap
    initPointLights(7);
    pointLights[0].intensity = 2.5;
    pointLights[0].range = 9;

    initSpotLights(4);
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;
    // rotate light
    dirLight.lightViewer.setEuler(sec * pi / 18, -pi / 3, 0); // rotate light
    // M3Log.d('DemoScene', 'Light Direction: $dirLight');

    // move point lights
    final cosSec = cos(sec * 0.3);
    final sinSec = sin(sec * 0.3);

    pointLights[0].position = Vector3(5 * cosSec, 5 * sinSec, 1.2);
    pointLights[1].position = Vector3(3 * -sinSec, 3 * -cosSec, 0.7);
    pointLights[2].position = Vector3(8 * sinSec, 8 * sinSec, 1.2);
    pointLights[3].position = Vector3(0, 8 * sinSec, 1.2);
    pointLights[4].position = Vector3(0, 8 * cosSec, 1.2);

    final cosSec2 = cos(sec * 0.6);
    final sinSec2 = sin(sec * 0.6);
    spotLights[0].direction = Vector3(cosSec2 * 0.5, 0, -1);
    spotLights[1].direction = Vector3(0.2, sinSec2 * 0.5, -1);
    spotLights[3].direction = Vector3(sinSec2, cosSec2, 0);
  }

  // create nvlobby cubemap
  Future<M3Skybox> createCubemapLobby() async {
    final strPrefix = 'example/nvlobby_';
    final strExt = 'jpg';
    final skybox = await M3Skybox.createCubemap(
      '${strPrefix}xpos.$strExt',
      '${strPrefix}xneg.$strExt',
      '${strPrefix}ypos.$strExt',
      '${strPrefix}yneg.$strExt',
      '${strPrefix}zpos.$strExt',
      '${strPrefix}zneg.$strExt',
    );

    return skybox;
  }

  M3Mesh createCompoundMesh() {
    final mtrRed = M3Material()
      ..diffuse = Vector4(1, 0, 0, 1)
      ..setMatte();
    // 02-3: orbit around
    final meshCube = M3Mesh(M3Resources.unitCube);
    final cylinder = M3SubMesh(M3Resources.unitCylinder, material: mtrRed);
    cylinder.localMatrix.scaleByVector3(Vector3(0.5, 0.5, 4));
    meshCube.subMeshes.add(cylinder);
    return meshCube;
  }
}
