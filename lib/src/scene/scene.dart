import 'package:flutter/widgets.dart' hide Matrix4;

// Macbear3D engine
import '../m3_internal.dart';

export 'camera.dart';
export 'entity.dart';
export 'light.dart';
export 'skybox.dart';

part 'sample_scene.dart';

/// Abstract base class for 3D scenes in the engine.
///
/// Manages entities, cameras, lights, physics integration, and provides
/// rendering methods for solid, wireframe, and 2D content.
abstract class M3Scene {
  M3RenderEngine get renderEngine => M3AppEngine.instance.renderEngine;
  RenderingContext get gl => renderEngine.gl;

  M3InputController? inputController;
  final M3PhysicsSystem physicsSystem;

  final _light = M3Light();
  final _camera = M3Camera();
  List<M3Camera> cameras = [];

  M3Camera get camera => cameras[0];
  M3Light get light => _light;

  // physics entities
  final List<M3Entity> entities = [];

  M3Skybox? skybox;
  M3Water? water;

  M3Scene({M3PhysicsSystem? physics}) : physicsSystem = physics ?? M3PhysicsSystem(M3NoPhysicsEngine()) {
    cameras.add(_camera);
    inputController = M3CameraOrbitController(_camera);

    // camera lookat Origin
    _camera.setLookat(Vector3(10, 0, 0), Vector3.zero(), Vector3(0, 0, 1));
    _camera.setEuler(0, 0, 0, distance: 20);

    // sun light
    int halfView = 8;
    light.setViewport(-halfView, -halfView, halfView * 2, halfView * 2, fovy: 0, far: 50);
    light.setEuler(pi / 5, -pi / 3, 0, distance: 15); // rotate light
  }

  void dispose() {
    skybox?.dispose();
    physicsSystem.dispose();
  }

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // load skybox, meshes, etc.
  Future<void> load() async {
    _isLoaded = true;

    await physicsSystem.init();
    debugPrint('<<< Physics System >>>\n${physicsSystem.info}\n');
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

  double _totalTime = 0.0;
  double get totalTime => _totalTime;

  void savePhysicsStates() {
    for (final entity in entities) {
      entity.savePhysicsState();
    }
  }

  void update(double delta) {
    _totalTime += delta;

    for (final camera in cameras) {
      // update camera
      camera.updateFrustum();
    }

    for (final entity in entities) {
      // update animation
      entity.update(delta);
    }

    physicsSystem.update(delta, onBeforeStep: savePhysicsStates);
    final alpha = physicsSystem.interpolationAlpha;

    for (final entity in entities) {
      // sync physics
      entity.syncFromPhysics(alpha);
    }

    for (final entity in entities) {
      // update bounds
      entity.updateBounds();
    }
  }

  void renderDebug() {}

  // render helper: zero, camera, light, wireframe
  void renderHelper() {
    M3Program progSimple = M3Resources.programSimple!;

    // pre-draw
    gl.useProgram(progSimple.program);
    gl.uniform1i(progSimple.uniformBoneCount, 0);

    for (final entity in entities) {
      // culling
      if (entity.mesh == null || !camera.isVisible(entity.worldBounding)) continue;

      final mesh = entity.mesh!;

      // origin axis
      progSimple.setMatrices(camera, entity.worldMatrix);
      // draw axis at object origin
      // Use the first submesh's material or a default for axis color?
      // Actually axis is fixed color, but setMaterial is needed for uniform locations
      progSimple.setMaterial(mesh.subMeshes.isNotEmpty ? mesh.subMeshes[0].mtr : M3Material(), Colors.red);
      M3Resources.debugAxis.draw(progSimple);

      // bounding sphere
      Sphere worldSphere = entity.worldBounding.sphere;
      if (worldSphere.radius > 0) {
        Matrix4 matSphere = Matrix4.identity();
        matSphere.translateByVector3(worldSphere.center);
        matSphere.scaleByVector3(Vector3.all(worldSphere.radius * 1.03));
        progSimple.setMaterial(mesh.subMeshes.isNotEmpty ? mesh.subMeshes[0].mtr : M3Material(), Colors.magenta);
        progSimple.setMatrices(camera, matSphere);
        M3Resources.debugSphere.draw(progSimple);
      }
      // AABB
      final matAabb = Matrix4.identity();
      matAabb.translateByVector3(entity.worldBounding.aabb.center);
      Vector3 extents = (entity.worldBounding.aabb.max - entity.worldBounding.aabb.min) / 2;
      extents += Vector3.all(0.03);
      matAabb.scaleByVector3(extents);
      progSimple.setMaterial(mesh.subMeshes.isNotEmpty ? mesh.subMeshes[0].mtr : M3Material(), Colors.lime);
      progSimple.setMatrices(camera, matAabb);
      M3Resources.debugFrustum.draw(progSimple, bSolid: false);
    }

    M3Material mtrHelper = M3Material();
    for (final cam in cameras) {
      progSimple.setMaterial(mtrHelper, Colors.skyBlue);
      cam.drawHelper(progSimple, camera);
    }

    // draw reflection camera
    renderEngine.planarReflection.drawHelper(camera);

    progSimple.setMaterial(mtrHelper, Colors.yellow);
    light.drawHelper(progSimple, camera);
  }

  void render2D() {}

  /// Build scene-specific UI controls.
  Widget? buildUI(BuildContext context) => null;
}
