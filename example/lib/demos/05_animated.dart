// ignore_for_file: file_names
import '../main_all.dart';

// ignore: camel_case_types
class AnimatedScene_05 extends DemoScene {
  // Gltf models
  M3Entity? _duck;
  M3Entity? _man;
  M3Entity? _fox;
  int _foxAnimIndex = 0;
  double _foxAnimTimer = 0.0;

  // BVH skeleton
  BvhSkeleton? skeleton;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    // set background color
    M3AppEngine.backgroundColor = Vector3(0.3, 0.1, 0.3);

    M3Texture texGround = M3Texture.createCheckerboard(
      size: 10,
      lightColor: Vector4(.7, 1, .5, 1),
      darkColor: Vector4(.5, 0.8, .3, 1),
    );

    // Apply mirror shader to ground
    const posZ = 0.0;
    renderEngine.planarReflection.clipPlane.setFromComponents(0, 0, 1, -posZ);

    // plane geometry
    final meshPlane = M3Mesh(M3PlaneGeom(30, 30, uvScale: Vector2.all(4.0)));
    meshPlane.subMeshes[0].mtr
      ..reflection = 0.3
      ..roughness = 0.0
      ..metallic = 0.3
      ..planarReflection = renderEngine.planarReflection
      ..diffuseTexture = texGround;

    final plane = addMesh(meshPlane, Vector3(0, 0, posZ));
    renderEngine.planarReflection.setRenderScale(0.5);

    // 05-1: GLTF model - using M3Mesh.load()
    final meshGltf = await M3Mesh.load('example/CesiumMan.glb');
    meshGltf.animator?.play(0);
    _man = addMesh(meshGltf, Vector3(0, 5, 0));
    _man!.color = Colors.white;
    _man!.rotation = Quaternion.euler(0, pi / 2, 0);
    _man!.scale = Vector3.all(2.0);

    // 05-2: GLTF model - using M3Mesh.load()
    final meshDuck = await M3Mesh.load('example/Duck.glb');
    _duck = addMesh(meshDuck, Vector3(-4, -4, 0));
    _duck!.scale = Vector3.all(1.0);

    final meshFox = await M3Mesh.load('example/Fox.glb');
    meshFox.animator?.play(0);
    _fox = addMesh(meshFox, Vector3(-2, 0, 0));
    _fox!.rotation = Quaternion.euler(0, pi / 2, 0);
    _fox!.scale = Vector3.all(0.04);

    // Fox 1: Survey Animation (Index 0)
    final mesh1 = meshFox.clone();
    mesh1.animator?.play(0);
    mesh1.animator?.playRate = 0.6;
    final entity1 = addMesh(mesh1, Vector3(-4, 0, 0));
    entity1.rotation = Quaternion.euler(0, pi / 2, 0);
    entity1.scale = Vector3.all(0.05);
    entity1.color = Vector4(1, 0.5, 0.5, 1); // Reddish

    // Fox 2: Walk Animation (Index 1)
    final mesh2 = meshFox.clone();
    mesh2.animator?.play(1);
    final entity2 = addMesh(mesh2, Vector3(2, 0, 0));
    entity2.rotation = Quaternion.euler(0, pi / 2, 0);
    entity2.scale = Vector3.all(0.03);
    entity2.color = Vector4(0.5, 1, 0.5, 1); // Greenish

    // Fox 3: Run Animation (Index 2)
    final mesh3 = meshFox.clone();
    mesh3.animator?.play(2);
    final entity3 = addMesh(mesh3, Vector3(4, 0, 0));
    entity3.rotation = Quaternion.euler(0, pi / 2, 0);
    entity3.scale = Vector3.all(0.02);
    entity3.color = Vector4(0.5, 0.5, 1, 1); // Blueish

    // BVH resource: Biovision hierarchical data
    // https://theorangeduck.com/media/uploads/BVHView/bvhview.html
    // http://lo-th.github.io/olympe/BVH_player.html
    // BVH data from mocapdata.com:
    // This motion capture data is licensed by mocapdata.com, Eyes, JAPAN Co. Ltd. under the Creative Commons Attribution 2.1 Japan License.
    // To view a copy of this license, contact mocapdata.com, Eyes, JAPAN Co. Ltd. or visit http://creativecommons.org/licenses/by/2.1/jp/ .
    // http://mocapdata.com/
    // (C) Copyright Eyes, JAPAN Co. Ltd. 2008-2009.
    // Load and parse BVH from assets
    final bvhFile = 'assets/example/karate-03-spin kick-yokoyama.bvh';
    skeleton = await BvhSkeleton.load(bvhFile);
    skeleton?.rootTransform.scale = Vector3.all(0.025);
    skeleton?.rootTransform.position = Vector3(0, -4, 0);
    skeleton?.rootTransform.rotation = Quaternion.fromRotation(M3Constants.rotXPos90);
    skeleton?.addToScene(this);
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;

    // Update Fox Animation Cycle
    if (_fox != null) {
      _foxAnimTimer += delta;
      if (_foxAnimTimer > 3.0) {
        _foxAnimTimer = 0.0;
        _foxAnimIndex = (_foxAnimIndex + 1) % 3;
        _fox!.mesh.animator?.crossFade(_foxAnimIndex, 0.5);
        M3Log.i('AnimatedScene', 'Fox animation cross-fade to index: $_foxAnimIndex');
      }
    }

    double angle = sec * pi / 10; // 18 degree per second

    if (_duck != null) {
      final quatYPos90 = Quaternion.euler(0, pi / 2, 0);
      _duck!.rotation = quatYPos90 * Quaternion.euler(angle, 0, 0);
    }

    skeleton?.update(delta);
  }
}
