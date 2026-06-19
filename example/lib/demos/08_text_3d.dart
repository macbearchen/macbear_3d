// ignore_for_file: file_names
import '../main_all.dart';

// ignore: camel_case_types
class Text3DScene_08 extends DemoScene {
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 9);

    // Lighting (ambient not supported directly on scene, handled by light setup or shaders)
    // light.color = Vector4(1, 1, 1, 1);
    // light.setEuler(0, 0, 0, distance: 20); // standard light

    // NotoSansMonoCJKtc-VF.ttf,
    // https://github.com/googlefonts/noto-cjk/raw/main/Sans/Variable/OTF/NotoSansCJKtc-VF.otf
    // final fontPath = 'https://github.com/googlefonts/noto-cjk/raw/main/Sans/Variable/OTF/NotoSansCJKtc-VF.otf';
    final isLocalFont = true;
    final fontPath = 'https://github.com/googlefonts/noto-cjk/raw/main/Sans/Variable/TTF/NotoSansCJKtc-VF.ttf';
    var localPath = 'assets/fonts/RobotoMono/RobotoMono-Regular.ttf';
    if (M3Package.name != null) {
      localPath = 'packages/${M3Package.name}/assets/fonts/RobotoMono/RobotoMono-Regular.ttf';
    }
    // final fontPath = 'assets/NotoSansMonoCJKtc-VF.ttf';
    M3ResourceManager resManager = M3AppEngine.instance.resourceManager;
    final font = await resManager.loadFont(isLocalFont ? localPath : fontPath); // ignore: dead_code
    final text = isLocalFont ? "OpenGL ES3" : "麥克熊"; // ignore: dead_code
    // Create Text Geometry
    final textGeom = M3TextGeom(text, font, size: 1.2, depth: 0.2, curveSubdivisions: 3, creaseAngle: 40);
    final textGeom2 = M3TextGeom('Macbear 3D', font, size: 1.6, depth: 0.4, curveSubdivisions: 3, creaseAngle: 40);

    // Create Material
    final mtr = M3Material();
    mtr.diffuse = Vector4(0.1, 0.6, 1.0, 1.0); // Blue
    mtr.shininess = 32;

    final mtr2 = M3Material();
    mtr2.diffuse = Vector4(0.8, 1.0, 0.1, 1.0); // yellow
    // 08-1: text geometry
    final mesh = M3Mesh(textGeom, material: mtr);
    final entity = addMesh(mesh, Vector3(-4, 0, 1.5)); // OpenGL ES
    entity.rotation.setEuler(0, pi * 0.45, 0);

    final mesh2 = M3Mesh(textGeom2, material: mtr2);
    final entity2 = addMesh(mesh2, Vector3(-3, -3, 0)); // Macbear 3D
    entity2.rotation.setEuler(0, 0, pi / 5);

    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    // 08-2: plane geometry
    final groundZ = -1.0;
    final plane = addMesh(
      M3Mesh(M3PlaneGeom(20, 20, widthSegments: 20, heightSegments: 20, uvScale: Vector2.all(5.0))),
      Vector3(0, 0, groundZ),
    );

    // 08-3: Apply mirror shader to ground
    renderEngine.planarReflection.clipPlane.setFromComponents(0, 0, 1, -groundZ);
    renderEngine.planarReflection.setRenderScale(0.5);

    plane.mesh.subMeshes[0].mtr
      ..reflection = 0.2
      ..roughness = 0.0
      ..metallic = 0.2
      ..planarReflection = renderEngine.planarReflection
      ..diffuseTexture = texGround;
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;
    light.setEuler(sec * pi / 6, -pi / 5, 0, distance: light.distanceToTarget); // rotate light
  }
}
