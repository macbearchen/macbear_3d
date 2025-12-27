import 'dart:math';

// Macbear3D engine
import '../../macbear_3d.dart';
import '../texture/material.dart';

export 'camera.dart';
export 'entity.dart';
export 'light.dart';
export 'skybox.dart';

abstract class M3Scene {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;
  M3InputController? inputController;

  final _light = M3Light();
  final _camera = M3Camera();
  List<M3Camera> cameras = [];

  M3Camera get camera => cameras[0];
  M3Light get light => _light;

  // physics entities
  final List<M3Entity> entities = [];

  M3Skybox? skybox;

  M3Scene() {
    cameras.add(_camera);
    inputController = M3CameraOrbitController(_camera);

    // camera lookat Origin
    _camera.setLookat(Vector3(10, 0, 0), Vector3.zero(), Vector3(0, 0, 1));
    _camera.setEuler(0, 0, 0, distance: 20);

    // sun light
    int halfView = 8;
    light.setViewport(-halfView, -halfView, halfView * 2, halfView * 2, fovy: 0, far: 30);
    light.setEuler(0, -pi / 3, 0, distance: light.distanceToTarget); // rotate light
  }

  void dispose() {
    skybox?.dispose();

    final world = M3AppEngine.instance.physicsEngine.world!;
    for (final entity in entities) {
      if (entity.rigidBody != null) {
        world.removeRigidBody(entity.rigidBody!);
      }
    }
  }

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // load skybox, meshes, etc.
  Future<void> load() async {
    _isLoaded = true;
  }

  M3Entity addMesh(M3Mesh mesh, Vector3 position) {
    final entity = M3Entity();
    entity.mesh = mesh;
    entity.position = position;

    entities.add(entity);

    return entity;
  }

  void addEntity(M3Entity entity) {
    entities.add(entity);
  }

  void update(Duration elapsed) {
    // sync physics
    for (final entity in entities) {
      entity.syncFromPhysics();
    }
  }

  // render solid models
  void render(M3Program prog, M3Camera camera, {bool bSolid = true}) {
    // pre-draw
    gl.useProgram(prog.program);
    gl.uniform1i(prog.uniformBoneCount, 0);

    for (final entity in entities) {
      if (entity.mesh == null) continue;
      // culling
      if (!camera.checkVisible(entity)) continue;

      final mesh = entity.mesh!;
      prog.setMatrices(camera, entity.matrix);
      prog.setMaterial(mesh.mtr, entity.color);

      // Skinned Mesh support
      if (mesh.skin != null) {
        gl.uniform1i(prog.uniformBoneCount, mesh.skin!.boneCount);
        final boneArray = Float32List(mesh.skin!.boneCount * 16);
        for (int i = 0; i < mesh.skin!.boneCount; i++) {
          boneArray.setAll(i * 16, mesh.skin!.boneMatrices[i].storage);
        }
        gl.uniformMatrix4fv(prog.uniformBoneMatrixArray, false, boneArray);
      } else {
        gl.uniform1i(prog.uniformBoneCount, 0);
      }

      mesh.geom.draw(prog, bSolid: bSolid);
    }
  }

  // render helper: zero, camera, light, wireframe
  void renderHelper() {
    M3Program progSimple = M3AppEngine.instance.renderEngine.programSimple!;

    // pre-draw
    gl.useProgram(progSimple.program);
    gl.uniform1i(progSimple.uniformBoneCount, 0);

    for (final entity in entities) {
      if (entity.mesh == null) continue;
      // culling
      if (!camera.checkVisible(entity)) continue;

      final mesh = entity.mesh!;
      progSimple.setMatrices(camera, entity.matrix);
      // draw axis at object origin
      progSimple.setMaterial(mesh.mtr, Colors.red);
      M3Constants.geomAxis.draw(progSimple);
    }

    M3Material mtrHelper = M3Material();
    progSimple.setMaterial(mtrHelper, Colors.yellow);
    light.drawHelper(progSimple, camera);

    progSimple.setMaterial(mtrHelper, Colors.skyBlue);
    for (final cam in cameras) {
      cam.drawHelper(progSimple, camera);
    }
  }

  void renderWireframe() {
    M3Program progSimple = M3AppEngine.instance.renderEngine.programSimple!;

    // pre-draw
    gl.useProgram(progSimple.program);
    gl.uniform1i(progSimple.uniformBoneCount, 0);

    for (final entity in entities) {
      if (entity.mesh == null) continue;
      // culling
      if (!camera.checkVisible(entity)) continue;

      final mesh = entity.mesh!;
      progSimple.setMatrices(camera, entity.matrix);
      // wireframe
      progSimple.setMaterial(mesh.mtr, entity.color);
      mesh.geom.draw(progSimple, bSolid: false);
    }
  }

  void render2D() {}
}
