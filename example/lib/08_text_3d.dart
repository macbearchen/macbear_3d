// ignore_for_file: file_names
import 'main.dart';

// ignore: camel_case_types
class Text3DScene_08 extends M3Scene {
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 8);

    // Lighting (ambient not supported directly on scene, handled by light setup or shaders)
    // light.color = Vector4(1, 1, 1, 1);
    // light.setEuler(0, 0, 0, distance: 20); // standard light

    // NotoSansMonoCJKtc-VF.ttf,
    // https://github.com/googlefonts/noto-cjk/raw/main/Sans/Variable/OTF/NotoSansCJKtc-VF.otf
    final fontPath = 'https://github.com/googlefonts/noto-cjk/raw/main/Sans/Variable/OTF/NotoSansCJKtc-VF.otf';
    // final fontPath = 'assets/NotoSansMonoCJKtc-VF.ttf';
    M3ResourceManager resManager = M3AppEngine.instance.resourceManager;
    final font = await resManager.loadFont(fontPath);
    final text = "麥克熊";
    // Create Text Geometry
    final textGeom = M3TextGeom(text, font, size: 1.5, depth: 0.3, curveSubdivisions: 3, creaseAngle: 40);
    final textGeom2 = M3TextGeom('Macbear 3D', font, size: 2, depth: 0.6, curveSubdivisions: 3, creaseAngle: 40);

    // Create Material
    final mtr = M3Material();
    mtr.diffuse = Vector4(1.0, 0.5, 0.0, 1.0); // Orange
    mtr.shininess = 32;

    final mtr2 = M3Material();
    mtr2.diffuse = Vector4(1.0, 1.0, 0.2, 1.0); // yellow
    // 08-1: text geometry
    final mesh = M3Mesh(textGeom, material: mtr);
    final entity = addMesh(mesh, Vector3(-2.5, 0, 2)); // TW
    entity.rotation.setEuler(0, pi * 0.4, 0);

    final mesh2 = M3Mesh(textGeom2, material: mtr2);
    final entity2 = addMesh(mesh2, Vector3(-2, -3, 0)); // 3D
    entity2.rotation.setEuler(0, 0, pi / 3);

    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    // 08-2: plane geometry
    final plane = addMesh(
      M3Mesh(M3PlaneGeom(20, 20, widthSegments: 20, heightSegments: 20, uvScale: Vector2.all(5.0))),
      Vector3(0, 0, -1),
    );
    plane.mesh!.mtr.texDiffuse = texGround;
    plane.mesh!.mtr.specular = Vector3.all(.6);
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;
    light.setEuler(sec * pi / 6, -pi / 5, 0, distance: light.distanceToTarget); // rotate light
  }
}
