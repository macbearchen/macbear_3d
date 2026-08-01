// ignore_for_file: file_names
import 'package:flutter/material.dart';
import '../main_all.dart' hide Colors;

// ignore: camel_case_types
class Text3DScene_08 extends DemoScene {
  final TextEditingController _textController = TextEditingController();
  M3TrueTypeParser? _font;
  M3Entity? _textEntity;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 9, -pi / 6, 0, distance: 11);

    // Lighting (ambient not supported directly on scene, handled by light setup or shaders)
    // light.color = Vector4(1, 1, 1, 1);
    // light.setEuler(0, 0, 0, distance: 20); // standard light

    // NotoSansMonoCJKtc-VF.ttf,
    // https://github.com/googlefonts/noto-cjk/raw/main/Sans/Variable/OTF/NotoSansCJKtc-VF.otf
    // final fontPath = 'https://github.com/googlefonts/noto-cjk/raw/main/Sans/Variable/OTF/NotoSansCJKtc-VF.otf';
    final isLocalFont = true; // (M3Package.name == null);
    // final fontPath = 'https://github.com/googlefonts/noto-cjk/raw/main/Sans/Variable/TTF/NotoSansCJKtc-VF.ttf';
    final serverPath = 'https://github.com/googlefonts/noto-cjk/raw/main/Sans/Variable/TTF/Subset/NotoSansTC-VF.ttf';
    var localPath = 'assets/fonts/RobotoMono/RobotoMono-Regular.ttf';
    if (M3Package.name != null) {
      localPath = 'packages/${M3Package.name}/assets/fonts/RobotoMono/RobotoMono-Regular.ttf';
    }
    localPath = 'assets/notofonts/NotoSansTC-VF.ttf';

    final fontPath = isLocalFont ? localPath : serverPath; // ignore: dead_code
    final text = isLocalFont ? "OpenGL ES3 麥克熊" : "麥克熊"; // ignore: dead_code

    M3Log.i('font', fontPath);
    M3ResourceManager resManager = M3AppEngine.instance.resourceManager;

    _font = await resManager.loadFont(fontPath);
    _textController.text = text;
    // Create Text Geometry
    final textGeom = M3TextGeom(text, _font!, size: 1.2, depth: 0.3, curveSubdivisions: 3, creaseAngle: 40);
    final textGeom2 = M3TextGeom('Macbear 3D', _font!, size: 1.6, depth: 0.5, curveSubdivisions: 3, creaseAngle: 40);

    // Create Material
    final mtr = M3Material();
    mtr.diffuse = Vector4(0.1, 0.6, 1.0, 1.0); // Blue
    mtr.shininess = 32;

    final mtr2 = M3Material();
    mtr2.diffuse = Vector4(0.8, 1.0, 0.1, 1.0); // yellow
    // 08-1: text geometry
    final mesh = M3Mesh(textGeom, material: mtr);
    _textEntity = addMesh(mesh, Vector3(-6, 0, 1.5)); // OpenGL ES
    _textEntity!.rotation.setEuler(0, pi * 0.45, 0);

    final mesh2 = M3Mesh(textGeom2, material: mtr2);
    final entity2 = addMesh(mesh2, Vector3(-3, -3, 0.3)); // Macbear 3D
    entity2.rotation.setEuler(0, 0, pi / 5);

    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );
    // 08-2: plane geometry
    final groundZ = -0.3;
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
  }

  void _updateText() {
    final font = _font;
    final entity = _textEntity;
    if (font == null || entity == null) return;

    final text = _textController.text;
    if (text.isEmpty) return;

    // Dispose old geometry
    entity.mesh.subMeshes[0].geom.dispose();

    // Create new geometry
    final textGeom = M3TextGeom(text, font, size: 1.2, depth: 0.2, curveSubdivisions: 3, creaseAngle: 40);

    entity.mesh.subMeshes[0].geom = textGeom;
    entity.markDirty();

    M3AppEngine.instance.refresh();
  }

  @override
  Widget buildUI(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Edit 3D Text",
              style: TextStyle(color: Colors.lightGreenAccent, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white10,
                hintText: "Enter 3D Text",
                hintStyle: const TextStyle(color: Colors.white30),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.lightGreenAccent),
                ),
              ),
              onSubmitted: (_) => _updateText(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: _updateText,
              child: const Text("Update", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
