// Macbear3D engine
import '../m3_internal.dart';

/// rendering mode: solid - triangle, wireframe - edges
enum M3FillMode { solid, wireframe }

class M3RenderContext {
  late M3Scene _scene;
  late M3Camera _viewer; // scene camera or light (light for shadow map)

  // opaque, transparent, unlit
  final M3RenderQueue opaque = M3RenderQueue(); // M3AlphaMode.opaque
  final M3RenderQueue masked = M3RenderQueue(); // M3AlphaMode.mask
  final M3RenderQueue transparent = M3RenderQueue(); // M3AlphaMode.blend

  final M3RenderQueue unlit = M3RenderQueue(); // external OES

  // reflection queue
  final M3RenderQueue planarReflection = M3RenderQueue();
  final M3RenderQueue reflectionProbe = M3RenderQueue();

  void prepareRenderQueue(
    M3Scene scene,
    M3Camera viewer, {
    bool bOnlyOpaque = false,
    M3PlanarReflection? excludeReflection,
  }) {
    // reset queues
    opaque.clear();
    masked.clear();
    transparent.clear();
    unlit.clear();

    planarReflection.clear();
    reflectionProbe.clear();

    // store scene, viewer
    _scene = scene;
    _viewer = viewer;

    final stats = M3AppEngine.instance.renderEngine.stats;

    // 1. Collect phase: Cull and categorize into queues
    for (final entity in scene.entities) {
      // statistics: total entities
      if (stats.enabled) {
        stats.totalEntities++;
        stats.totalSubmeshes += entity.mesh.subMeshes.length;
      }

      // culling
      if (!viewer.isVisible(entity.worldBounding)) {
        continue;
      }

      // statistics: visible entities
      if (stats.enabled) stats.entities++;

      final meshMatrix = entity.worldMatrix * entity.mesh.initMatrix;
      final subMeshCount = entity.mesh.subMeshes.length;
      for (final sub in entity.mesh.subMeshes) {
        // submesh culling check (skipped for single-submesh meshes)
        if (subMeshCount > 1 && !viewer.isVisible(sub.worldBounding)) {
          continue;
        }

        // statistics: visible sub-meshes, vertices, triangles
        if (stats.enabled) {
          stats.submeshes++;
          stats.vertices += sub.geom.vertexCount;
          stats.triangles += sub.geom.getTriangleCount();
        }

        // skip planar reflection surface
        if (excludeReflection != null && sub.mtr.planarReflection == excludeReflection) {
          continue;
        }

        final worldMat = meshMatrix * sub.localMatrix;
        final viewPos = viewer.viewMatrix * worldMat.getTranslation();
        // Depth for sorting (negative Z in view space is forward)
        final depth = viewPos.z;

        // Collects a sub-mesh into the appropriate queue based on its material.
        final item = M3RenderItem(entity: entity, subMesh: sub, worldMatrix: worldMat, depth: depth);
        item.pointLights = scene.pointLights;
        item.spotLights = scene.spotLights;

        // 1-1. Collect for unlit / opacity / masked / transparency
        if (sub.mtr.diffuseTexture is M3ExternalTexture) {
          unlit.add(item);
        } else if (sub.mtr.alphaMode == M3AlphaMode.blend) {
          if (!bOnlyOpaque) {
            transparent.add(item);
          }
        } else if (sub.mtr.alphaMode == M3AlphaMode.mask) {
          masked.add(item);
        } else {
          opaque.add(item);
        }

        // 1-2. Collect for reflection
        if (sub.mtr.reflection > 0.0) {
          if (sub.mtr.planarReflection != null) {
            planarReflection.add(item); // planar mode: for mirror
          } else {
            reflectionProbe.add(item); // cubemap mode: for reflection probe
          }
        }
      }
    }
    // 2. Sort opaque and masked (Front-to-Back for Early-Z)
    opaque.sortOpaque();
    masked.sortOpaque();
    if (bOnlyOpaque) {
      return; // remark it: produce some shore effect
    }

    // 3. Sort transparent
    transparent.sortTransparent();
  }

  /// exclude entities from render queue
  void excludeEntities(List<M3Entity> entities) {
    for (var e in entities) {
      opaque.items.removeWhere((item) => item.entity == e);
      masked.items.removeWhere((item) => item.entity == e);
      transparent.items.removeWhere((item) => item.entity == e);
      unlit.items.removeWhere((item) => item.entity == e);
    }
  }

  bool needsPlanarReflectionPass() {
    return planarReflection.items.any((item) => item.subMesh.mtr.planarReflection != null);
  }

  bool needsReflectionProbePass() {
    return reflectionProbe.items.any((item) => item.entity.getProbe() != null);
  }

  /// render all render queues: solid color pass
  void renderColorPass([M3Program? fallbackProg]) {
    final gl = M3AppEngine.instance.renderEngine.gl;

    // 1. Opaque & Masked: Disable blending, enable depth writing
    gl.disable(WebGL.BLEND);
    gl.blendFunc(WebGL.ONE, WebGL.ONE);
    gl.depthMask(true);

    // (1/4) Opaque objects
    _executeQueue(opaque, defaultProg: fallbackProg);

    // (2/4) Masked objects (alpha test / cutoff)
    _executeQueue(masked, defaultProg: fallbackProg);

    // (3/4) Unlit objects
    final progUnlit = M3Resources.programExternalOES!;
    _executeQueue(unlit, defaultProg: progUnlit, useVariant: false);

    // 2. Transparent objects: Enable alpha blending, disable depth writing
    if (!transparent.isEmpty) {
      gl.enable(WebGL.BLEND);
      gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA);
      gl.depthMask(false);
      // (4/4) Transparent objects
      _executeQueue(transparent, defaultProg: fallbackProg);
      gl.depthMask(true);
      gl.disable(WebGL.BLEND);
    }
  }

  /// render all render queues: wireframe pass
  void renderWireframePass() {
    final gl = M3AppEngine.instance.renderEngine.gl;
    M3Program prog = M3Resources.programSimple!;

    // 1. Opaque & Masked: Disable blending, enable depth writing
    gl.disable(WebGL.BLEND);
    gl.blendFunc(WebGL.ONE, WebGL.ONE);
    gl.depthMask(true);

    // (1/4) Opaque objects
    _executeQueue(opaque, defaultProg: prog, fillMode: .wireframe, useVariant: false);

    // (2/4) Masked objects (alpha test / cutoff)
    _executeQueue(masked, defaultProg: prog, fillMode: .wireframe, useVariant: false);

    // (3/4) Unlit objects
    _executeQueue(unlit, defaultProg: prog, fillMode: .wireframe, useVariant: false);

    // 2. Transparent objects: Enable alpha blending, disable depth writing
    gl.enable(WebGL.BLEND);
    gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA);
    gl.depthMask(false);
    // (4/4) Transparent objects
    _executeQueue(transparent, defaultProg: prog, fillMode: .wireframe, useVariant: false);
    gl.depthMask(true);
    gl.disable(WebGL.BLEND);
  }

  /// Depth-only pass: opaque + masked with skinning + alpha test.
  /// Used by shadow map rendering — transparent and unlit objects are intentionally excluded.
  void renderDepthPass() {
    // Opaque: write depth, no blending
    _executeQueue(opaque, defaultProg: M3Resources.programSimple!, useVariant: false);
    // Masked: same depth shader but with alpha cutoff
    final progMasked = M3Resources.programSimpleMasked;
    if (progMasked != null && !masked.isEmpty) {
      _executeQueue(masked, defaultProg: progMasked, useVariant: false);
    }
    // transparent & unlit: intentionally skipped for shadow depth
  }

  /// composited 2-pass reflection rendering
  void renderReflectionPass() {
    RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

    gl.depthFunc(WebGL.EQUAL); // Match exactly from 1st pass
    gl.depthMask(false); // Don't write to depth buffer in blending pass
    gl.enable(WebGL.BLEND);
    gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA); // alpha blending

    final stats = M3AppEngine.instance.renderEngine.stats;
    // (1/2) render reflection probe objects
    M3Program? progProbe = M3Resources.programSkyboxReflect;
    final options = M3AppEngine.instance.renderEngine.options;
    if (progProbe != null && !options.shader.ibl) {
      _executeQueue(reflectionProbe, defaultProg: progProbe, useVariant: false); // reflection cubemap
      stats.reflection += reflectionProbe.items.length;
    }

    // (2/2) render planar reflection objects
    M3Program? progPlanar = M3Resources.programMirror;
    if (progPlanar != null) {
      _executeQueue(planarReflection, defaultProg: progPlanar, useVariant: false); // planar reflection
      stats.reflection += planarReflection.items.length;
    }

    // Restore depth state
    gl.depthMask(true);
    gl.depthFunc(WebGL.LEQUAL);
  }

  /// execute queue with shader, switching among the 8 variant keys when [useVariant] is true.
  void _executeQueue(
    M3RenderQueue queue, {
    M3Program? defaultProg,
    M3FillMode fillMode = .solid,
    bool useVariant = true,
  }) {
    if (queue.isEmpty) return;

    RenderingContext gl = M3AppEngine.instance.renderEngine.gl;

    M3Program? currentProg;
    int currentVariantKey = -1;

    void bindProgram(M3Program prog) {
      if (currentProg == prog) return;
      currentProg = prog;
      gl.useProgram(prog.program);
      prog.applyFrameUniforms(_viewer);
      if (prog is M3ProgramLighting) {
        prog.applyFog(_scene.fog); // fog supported
      }
    }

    // override material to apply entity color and reflection
    final mtrOverride = M3Material();
    final colorOverride = Vector4.all(1.0);
    // apply reflection cubemap
    final M3Texture defaultCubemap = _scene.skybox?.cubemapTexture ?? M3Resources.texDefaultCubemap;
    M3Texture currentCubemap = defaultCubemap;

    // If not using dynamic variants, bind default program upfront
    if (!useVariant) {
      final prog = defaultProg ?? M3Resources.programTexture!;
      bindProgram(prog);
      prog.setEnvironmentMap(currentCubemap);
    }

    // track cull face state (default is cull face enabled)
    bool cullFaceEnabled = true;

    for (final item in queue.items) {
      // Switch program when variant key changes (items are pre-sorted by variantKey)
      if (useVariant) {
        if (item.variantKey != currentVariantKey || currentProg == null) {
          currentVariantKey = item.variantKey;
          final prog =
              M3Resources.getLightingProgramByVariant(currentVariantKey) ?? defaultProg ?? M3Resources.programTexture!;
          bindProgram(prog);
          prog.setEnvironmentMap(currentCubemap);
        }
      }

      final prog = currentProg!;
      final sub = item.subMesh;
      final entity = item.entity;
      final nextCubemap = entity.getProbe()?.cubemapTexture ?? defaultCubemap;

      // toggle CULL_FACE per material
      final shouldCull = !sub.mtr.doubleSided;
      if (shouldCull != cullFaceEnabled) {
        if (shouldCull) {
          gl.enable(WebGL.CULL_FACE);
        } else {
          gl.disable(WebGL.CULL_FACE);
        }
        cullFaceEnabled = shouldCull;
      }

      // copy material from sub
      mtrOverride.setFrom(sub.mtr);
      mtrOverride.mipLevel = nextCubemap.maxMipLevel;
      colorOverride.setFrom(entity.color);
      if (prog.reflectionType != M3ReflectionType.none) {
        // for reflection pass
        // scale diffuse by reflection, and use planar reflection texture if available
        final f = mtrOverride.reflection;
        // colorOverride.setValues(f, f, f, f);
        colorOverride.setFrom(mtrOverride.diffuse);
        colorOverride.a *= f;
        // planar reflection
        if (prog.reflectionType == M3ReflectionType.planar && mtrOverride.planarReflection != null) {
          mtrOverride.diffuseTexture = mtrOverride.planarReflection!.texture;
          mtrOverride.mipLevel = mtrOverride.diffuseTexture.maxMipLevel;
        }
      }

      prog.setMatrices(_viewer, item.worldMatrix);
      prog.setMaterial(mtrOverride, colorOverride);
      prog.setSkinning(entity.mesh.skin);

      if (currentCubemap != nextCubemap) {
        currentCubemap = nextCubemap;
        prog.setEnvironmentMap(currentCubemap);
      }
      sub.geom.draw(prog, fillMode: fillMode);
    }

    // restore default cull face state
    if (!cullFaceEnabled) {
      gl.enable(WebGL.CULL_FACE);
    }
  }
}
