// ignore_for_file: file_names
import 'main_all.dart';

// ignore: camel_case_types
class StarterScene_00 extends M3Scene {
  M3TextTexture? _logo;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    M3AppEngine.backgroundColor = Vector3(0.1, 0.3, 0.15);

    _logo = await M3TextTexture.createFromText('麥克熊 3D');
  }

  @override
  void render2D() {
    super.render2D();

    Matrix4 mat2D = Matrix4.identity();

    M3Shape2D.drawImage(_logo!, mat2D, color: Vector4(1, 1, 1, 1));

    mat2D.setTranslation(Vector3(_logo!.texW + 6, 0, 0));
    M3Resources.text2D.drawText('Welcome to Macbear 3D.', mat2D, color: Vector4(0.5, 1, 0.6, 1));

    final info = '''
Click buttons to test examples.
  1. Cube scene
  2. Skybox scene
  3. Primitives scene
  4. Obj teapot scene
  5. GLTF scene
  6. Shadow for large scene
  7. Physics scene
  8. Text 3D scene
''';

    mat2D.setTranslation(Vector3(20, 80, 0));
    mat2D.scaleByVector3(Vector3.all(0.7));
    M3Resources.text2D.drawText(info, mat2D);
  }
}
