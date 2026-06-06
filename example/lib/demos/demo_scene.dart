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
}
