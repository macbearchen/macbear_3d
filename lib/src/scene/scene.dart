import 'package:flutter/widgets.dart' hide Matrix4;
import 'package:oimo_physics/oimo_physics.dart' as oimo;

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
  final M3RenderPipeline _pipeline = M3RenderPipeline();

  M3Scene() {
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

  double _totalTime = 0.0;
  double get totalTime => _totalTime;

  void savePhysicsStates() {
    for (final entity in entities) {
      entity.savePhysicsState();
    }
  }

  void update(double delta) {
    _totalTime += delta;

    for (final entity in entities) {
      // update animation
      entity.update(delta);

      // sync physics
      entity.syncFromPhysics();

      // update bounds
      entity.updateBounds();
    }
  }

  void _bindReflection(M3Texture? cubemap) {
    if (cubemap != null) {
      cubemap.bind();
    } else {
      if (skybox != null) {
        skybox!.mtr.texDiffuse.bind();
      } else {
        M3Resources.texDefaultCube.bind();
      }
    }
  }

  void _applyReflectionCubemap(M3Program prog, M3Texture? cubemap) {
    final shaderOptions = M3AppEngine.instance.renderEngine.options.shader;
    if (prog is M3ProgramLighting && shaderOptions.pbr && shaderOptions.ibl) {
      if (M3Program.isLocationValid(prog.uniformSamplerEnvironment)) {
        gl.uniform1i(prog.uniformSamplerEnvironment, 2);
        gl.activeTexture(WebGL.TEXTURE2); // bind cubemap to GL_TEXTURE2
        _bindReflection(cubemap);

        gl.activeTexture(WebGL.TEXTURE0); // restore back to GL_TEXTURE0
      }
    }
  }

  // render solid models
  void render(M3Program prog, M3Camera camera, {bool bSolid = true, bool bOnlyOpaque = false}) {
    _pipeline.clear();

    final stats = M3AppEngine.instance.renderEngine.stats;

    // 1. Collect phase: Cull and categorize into queues
    for (final entity in entities) {
      if (entity.mesh == null) continue;
      final mesh = entity.mesh!;

      // culling
      if (!camera.isVisible(entity.worldBounding)) {
        if (stats.enabled) stats.culling++;
        continue;
      }

      if (stats.enabled) stats.entities++;

      final meshMatrix = entity.worldMatrix * mesh.initMatrix;
      for (final sub in mesh.subMeshes) {
        final worldMat = meshMatrix * sub.localMatrix;
        final viewPos = camera.viewMatrix * worldMat.getTranslation();
        // Depth for sorting (negative Z in view space is forward)
        final depth = viewPos.z;

        _pipeline.collect(entity, sub, worldMat, depth);
      }
    }

    // 2. Sort phase
    _pipeline.sort();

    // 3. Execute phase
    // Opaque first
    _executeQueue(_pipeline.opaque, prog, camera, bSolid: bSolid);

    if (bOnlyOpaque) return;

    // Then Transparent (Back-to-Front)
    // Note: Transparent sorting and blending is handled within the pipeline execution
    _executeQueue(_pipeline.transparent, prog, camera, bSolid: bSolid);
  }

  void _executeQueue(M3RenderQueue queue, M3Program prog, M3Camera camera, {bool bSolid = true}) {
    if (queue.isEmpty) return;

    // pre-draw state
    gl.useProgram(prog.program);
    prog.applyCamera(camera);

    // apply reflection cubemap
    _applyReflectionCubemap(prog, skybox?.mtr.texDiffuse);

    final stats = M3AppEngine.instance.renderEngine.stats;
    M3Program currentBoundProg = prog;

    for (final item in queue.items) {
      final sub = item.subMesh;
      final entity = item.entity;

      M3Program activeProg = prog;
      if (prog is M3ProgramLighting &&
          sub.mtr.texDiffuse is M3ExternalTexture &&
          M3Resources.programExternalOES != null) {
        activeProg = M3Resources.programExternalOES!;
      }

      // Avoid redundant useProgram calls
      if (activeProg != currentBoundProg) {
        gl.useProgram(activeProg.program);
        activeProg.applyCamera(camera);
        _applyReflectionCubemap(activeProg, skybox?.mtr.texDiffuse);
        currentBoundProg = activeProg;
      }

      activeProg.setMatrices(camera, item.worldMatrix);
      activeProg.setMaterial(sub.mtr, entity.color);
      activeProg.setSkinning(entity.mesh!.skin);

      // pre-reflection probe
      if (entity.reflectionProbe != null) {
        _applyReflectionCubemap(activeProg, entity.reflectionProbe!.texCubemap);
      }

      sub.geom.draw(activeProg, bSolid: bSolid);

      // post-reflection probe
      if (entity.reflectionProbe != null) {
        _applyReflectionCubemap(activeProg, null);
      }

      // statistics
      if (stats.enabled) {
        stats.vertices += sub.geom.vertexCount;
        stats.triangles += sub.geom.getTriangleCount(bSolid: bSolid);
      }
    }

    // Restore original program if needed
    if (currentBoundProg != prog) {
      gl.useProgram(prog.program);
    }
  }

  void renderDebug() {}

  void renderReflection() {
    if (M3Resources.programSkyboxReflect == null) {
      return;
    }
    M3ProgramEye prog = M3Resources.programSkyboxReflect!;
    gl.depthFunc(WebGL.EQUAL); // Match exactly from 1st pass
    gl.depthMask(false); // Don't write to depth buffer in additive pass
    gl.blendFunc(WebGL.ONE, WebGL.ONE); // Additive blending

    // pre-draw
    gl.useProgram(prog.program);
    prog.applyCamera(camera);

    for (final entity in entities) {
      // culling
      if (entity.mesh == null || !camera.isVisible(entity.worldBounding)) {
        continue;
      }

      final mesh = entity.mesh!;
      final meshMatrix = entity.worldMatrix * mesh.initMatrix;
      for (final sub in mesh.subMeshes) {
        if (sub.mtr.reflection <= 0) continue;

        Vector4 reflectColor = Vector4.all(sub.mtr.reflection);

        prog.setMatrices(camera, meshMatrix * sub.localMatrix);
        // Use submaterial for PBR properties (metallic, roughness, diffuse)
        prog.setMaterial(sub.mtr, reflectColor);
        // Override SamplerDiffuse with skybox cubemap for reflection lookup
        gl.activeTexture(WebGL.TEXTURE0);

        prog.setSkinning(mesh.skin);

        // pre-reflection probe
        if (entity.reflectionProbe != null) {
          _bindReflection(entity.reflectionProbe!.texCubemap);
        }

        sub.geom.draw(prog, bSolid: true);

        // post-reflection probe
        if (entity.reflectionProbe != null) {
          _bindReflection(null);
        }

        // statistics
        final stats = M3AppEngine.instance.renderEngine.stats;
        if (stats.enabled) stats.reflection++;
      }
    }

    // Reset depth state
    gl.depthMask(true);
    gl.depthFunc(WebGL.LEQUAL);
  }

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

    progSimple.setMaterial(mtrHelper, Colors.yellow);
    light.drawHelper(progSimple, camera);
  }

  void render2D() {}

  /// Build scene-specific UI controls.
  Widget? buildUI(BuildContext context) => null;
}
