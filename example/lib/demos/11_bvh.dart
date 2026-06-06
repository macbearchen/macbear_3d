// ignore_for_file: file_names
import '../main_all.dart';

// ignore: camel_case_types
class BvhScene_11 extends DemoScene {
  BvhSkeleton? skeleton;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

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
    skeleton?.rootTransform.position = Vector3.zero();
    skeleton?.rootTransform.rotation = Quaternion.fromRotation(M3Constants.rotXPos90);
    skeleton?.addToScene(this);

    final plane = addMesh(M3Mesh(M3PlaneGeom(20, 20, uvScale: Vector2.all(5.0))), Vector3(0, 0, 0));
    plane.color = Vector4(0.1, 1.0, 0.3, 1.0);
  }

  @override
  void update(double delta) {
    super.update(delta);
    skeleton?.update(delta);
  }
}
