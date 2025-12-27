import 'dart:math';

// Macbear3D engine
import 'package:oimo_physics/oimo_physics.dart' as oimo;

import '../macbear_3d.dart';
import '../src/texture/text_texture.dart';

class TestScene extends M3Scene {
  final _geomPyramid = M3PyramidGeom(1.0, 1.0, 1.0);
  final _geomCube = M3BoxGeom(1.0, 1.0, 1.0);
  final _geomSphere = M3SphereGeom(0.6, 0.6, 16, 8);
  final _geomTorus = M3TorusGeom();
  final _geomCylinder = M3CylinderGeom(0.3, 0.6, 2, 12, 2);
  final _geomPlane = M3PlaneGeom(
    30.0,
    30.0,
    80,
    50,
    Vector2(1.0, 1.0),
    callback: (x, y) {
      double rad = pi / 3;
      return (cos(x * rad) + sin(y * rad)) / 2;
    },
  );
  M3Entity? _model;
  M3Entity? _teapot;

  M3Texture? texYoshi;
  M3Texture? texText;
  M3Texture? texLabel;

  // constructor
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setLookat(Vector3(0, 12, 16), Vector3(0, 0, 2), Vector3(0, 0, 1));
    camera.setEuler(0, -pi / 3, 0, distance: 20);

    final camera2 = M3Camera();
    camera2.setLookat(Vector3(0, 4, 5), Vector3.zero(), Vector3(0, 0, 1));
    cameras.add(camera2);

    int halfView = 3;
    final camera3 = M3Camera();
    camera3.setViewport(-halfView, -halfView, halfView * 2, halfView * 2, fovy: 0, far: 50);
    camera3.setLookat(Vector3(0, -6, 8), Vector3(0, 0, 3), Vector3(0, 0, 1));
    cameras.add(camera3);
    // scene.cameras.insert(0, camera3);

    // physics world
    final world = M3AppEngine.instance.physicsEngine.world!;

    // create ground rigid body
    final groundConfig = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), 40.0, 40.0, 10.0)],
      position: Vector3(0.0, 0.0, -5.0),
    );
    // ignore: unused_local_variable
    final rbGround = world.add(groundConfig) as oimo.RigidBody;

    // ground plane model
    final meshPlane = addMesh(M3Mesh(_geomPlane), Vector3(0, 0, -2))..color = Vector4(1.0, 1.0, 1.0, 1);
    // (optional) link meshPlane to rbGround if you want it to move, but it's static.

    // create body models
    List<Vector3> arrayPos = [Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(0, 3, 0), Vector3(0.2, 0.4, 3)];
    List<Vector4> arrayColor = [Colors.yellow, Colors.red, Colors.green, Colors.blue];

    // cube model (dynamic)
    for (int i = 0; i < arrayPos.length; i++) {
      final pos = arrayPos[i];
      pos.z += 5.0; // drop from sky

      // create visual entity
      final entity = addMesh(M3Mesh(_geomCube), pos)..color = arrayColor[i];

      // create rigid body
      final config = oimo.ObjectConfigure(
        shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), 1.0, 1.0, 1.0)],
        position: pos,
        move: true, // dynamic
      );
      final rb = world.add(config) as oimo.RigidBody;

      // link
      entity.rigidBody = rb;
    }
    addMesh(M3Mesh(_geomSphere), Vector3(2, 2, -1)).color = Vector4(0.0, 1.0, 1.0, 1);
    addMesh(M3Mesh(_geomTorus), Vector3(2, 2, 2)).color = Vector4(1.0, 1.0, 0.2, 1);
    addMesh(M3Mesh(_geomCylinder), Vector3(5, 0, 1)).color = Vector4(.3, 1.0, 0.9, 1);

    // pyramid model
    _model = addMesh(M3Mesh(_geomPyramid), Vector3(2, 2, 0));
    _model!.color = Vector4(0.0, 1.0, 1.0, 1);

    // obj model - using M3Mesh.load()
    final meshTeapot = await M3Mesh.load('teapot.obj');
    _teapot = addMesh(meshTeapot, Vector3(-3, -4, 0));
    _teapot!.color = Vector4(1.0, 0.5, 0.0, 1);
    // _teapot!.scale = Vector3.all(0.5);

    // glTF: Avocado, BoxTextured, SheenChair, RiggedSimple, ScatteringSkull, CesiumMan
    // glTF: Fox, Duck
    // glTF model - using M3Mesh.load()

    final meshGltf = await M3Mesh.load('glTF/CesiumMan.glb');
    final gltf = addMesh(meshGltf, Vector3(0, 0, 3));
    gltf.color = Colors.white;
    gltf.scale = Vector3.all(3);
    /*
    final meshDuck = await M3Mesh.loadFromUrl(
      //      'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/Duck/glTF-Binary/Duck.glb',
      'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/Avocado/glTF-Binary/Avocado.glb',
    );
    final duck = addMesh(meshDuck, Vector3(3, 0, 3));
    duck.scale = Vector3.all(20);
*/
    // texture test
    // final strPrefix = 'data_test/cubemap/box_';
    // final strExt = 'bmp';
    final strPrefix = 'data_test/cubemap/nvlobby_';
    final strExt = 'jpg';
    skybox = await M3Skybox.createCubemap(
      '${strPrefix}xpos.$strExt',
      '${strPrefix}xneg.$strExt',
      '${strPrefix}ypos.$strExt',
      '${strPrefix}yneg.$strExt',
      '${strPrefix}zpos.$strExt',
      '${strPrefix}zneg.$strExt',
    );

    // String strTex = 'yoshi_6x6.astc';
    String strTex = 'astc/test_12x12.astc';
    // String strTex = 'astc/test_4x4.astc';
    // String strTex = 'data_test/land.pvr';

    M3Texture texKtx = await M3Texture.loadTexture(strTex);
    texYoshi = await M3Texture.loadTexture('yoshi_s.png');
    texLabel = await M3TextTexture.createFromText('Dynamic Text 測試', fontSize: 32);
    texText = await M3TextTexture.createFixed('Fixed Text\n測試');

    meshPlane.mesh!.mtr.texDiffuse = texKtx;
    meshPlane.mesh!.mtr.specular = Vector3.zero();
    meshPlane.mesh!.mtr.shininess = 1;
    // scene._geomCylinder.mtr.texDiffuse = texYoshi;
  }

  @override
  void update(Duration elapsed) {
    super.update(elapsed);

    double sec = elapsed.inMilliseconds / 1000.0;

    light.setEuler(sec * pi / 18, -pi / 3, 0, distance: light.distanceToTarget); // rotate light
    // debugPrint('Light Direction: $dirLight');

    double angle = sec * pi / 4; // 45 degree per second
    // rotate pyramid model
    if (_model != null) {
      _model!.rotation.setEuler(0, 0, angle);
    }

    if (_teapot != null) {
      final quat = Quaternion.euler(angle, 0, 0);
      final quatYPos90 = Quaternion.euler(0, pi / 2, 0);
      _teapot!.rotation = quatYPos90.multiply(quat);
    }
  }

  @override
  void render2D() {
    // draw rectangle full-screen
    Matrix4 mat2D = Matrix4.identity();

    // draw rectangle
    final texTest = texYoshi!;
    final texT1 = texLabel!;
    final texT2 = texText!;

    mat2D.setTranslation(Vector3(200.0, 40.0, 0.0));
    M3Shape2D.drawImage(texTest, mat2D, color: Vector4(1, 1, 1, 1));

    mat2D.setTranslation(Vector3(5.0, 10.0, 0.0));
    M3Shape2D.drawImage(texT1, mat2D, color: Vector4(1, 1, 0, 1));

    mat2D.setTranslation(Vector3(10.0, 120.0, 0.0));
    M3Shape2D.drawImage(texT2, mat2D, color: Vector4(0, 1, 1, 1));

    mat2D.setTranslation(Vector3(200.0, 200.0, 0.0));
  }
}
