// ignore_for_file: file_names
import 'main.dart';

// ignore: camel_case_types
class GlftScene_05 extends M3Scene {
  M3Entity? _duck;
  M3Entity? _man;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setLookat(Vector3(10, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, 1));
    camera.setEuler(pi / 6, -pi / 6, 0, distance: 8);

    // plane geometry
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    final plane = addMesh(M3Mesh(M3PlaneGeom(20, 20, uvScale: Vector2.all(5.0))), Vector3(0, 0, 0));
    plane.mesh!.mtr.texDiffuse = texGround;

    // 05-1: GLTF model - using M3Mesh.load()
    final meshGltf = await M3Mesh.load('example/CesiumMan.glb');
    meshGltf.animator?.play(0);
    _man = addMesh(meshGltf, Vector3(0, 0, 0));
    _man!.color = Colors.white;
    _man!.rotation = Quaternion.euler(0, pi / 2, 0);
    _man!.scale = Vector3.all(3);

    // 05-2: GLTF model - using M3Mesh.load()
    // https://github.com/KhronosGroup/glTF-Sample-Models
    // iOS entitlements should enable for internet access
    // com.apple.security.network.client
    /*
    final meshDuck = await M3Mesh.load(
      // 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/Avocado/glTF-Binary/Avocado.glb',
      'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/Duck/glTF-Binary/Duck.glb',
    );
*/
    final meshDuck = await M3Mesh.load('example/Duck.glb');
    _duck = addMesh(meshDuck, Vector3(0, 5, 0));
    _duck!.scale = Vector3.all(0.03);

    final meshFox = await M3Mesh.load('example/Fox.glb');
    meshFox.animator?.play(0);
    final fox = addMesh(meshFox, Vector3(-3, 0, 0));
    fox.rotation = Quaternion.euler(0, pi / 2, 0);
    fox.scale = Vector3.all(0.04);

    // set background color
    M3AppEngine.backgroundColor = Vector3(0.3, 0.1, 0.3);
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;

    light.setEuler(sec * pi / 18, -pi / 3, 0, distance: light.distanceToTarget); // rotate light
    // debugPrint('Light Direction: $dirLight');

    double angle = sec * pi / 10; // 18 degree per second

    if (_duck != null) {
      final quatYPos90 = Quaternion.euler(0, pi / 2, 0);
      _duck!.rotation = quatYPos90 * Quaternion.euler(angle, 0, 0);
    }
  }
}
