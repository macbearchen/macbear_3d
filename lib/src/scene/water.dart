// Macbear3D engine
import '../m3_internal.dart';

/// Layer for water wave animation
class M3WaterFlowLayer {
  Vector2 offset = Vector2.zero();
  Vector2 scale = Vector2.all(1.0);
  Vector2 velocity = Vector2.zero();
}

/// water effect, using plane reflection / refraction.
class M3Water extends M3Entity {
  M3ProgramWater get progWater => M3Resources.programWater!; // debug: programMirror
  M3ProgramWaterCSM get progWaterCSM => M3Resources.programWaterCSM!;

  Plane surfacePlane = Plane.components(0, 0, 1, 0);
  M3Texture normalMap = M3Resources.texNormal; // normal-map for water wave distortion
  double waveDistortion = 20.0;
  double reflectionDepthBias = 0.8;
  late M3Scene scene;

  static M3Mesh createWaterSurface({
    double width = 400,
    double height = 400,
    int widthSegments = 8,
    int heightSegments = 8,
    Vector2? uvScale,
  }) {
    final mtr = M3Material()
      ..setGlossy()
      ..metallic = 0.3
      ..reflection = 0.3;
    final waterMesh = M3Mesh(
      M3PlaneGeom(width, height, widthSegments: widthSegments, heightSegments: heightSegments, uvScale: uvScale),
      material: mtr,
    );

    return waterMesh;
  }

  M3Material get waterMaterial => mesh.subMeshes[0].mtr;

  // water surface render pass
  final M3PlanarReflection reflectionPass;
  final M3PlanarReflection refractionPass;

  // fog part:
  M3Fog waterFog = M3Fog()
    ..color = M3Constants.colorMountainLake
    ..depth = 6; // fog depth: 0 mean no fog

  // for bump flow animation
  M3WaterFlowLayer flow0 = M3WaterFlowLayer()
    ..scale = Vector2.all(3)
    ..velocity = Vector2(0.016, -0.014);
  M3WaterFlowLayer flow1 = M3WaterFlowLayer()
    ..scale = Vector2.all(7)
    ..velocity = Vector2(0.025, -0.03);

  M3Water({M3Mesh? waterMesh, bool useReflection = true, bool useRefraction = true})
    : reflectionPass = M3PlanarReflection(),
      refractionPass = M3PlanarReflection(),
      super(mesh: waterMesh ?? createWaterSurface()) {
    // reflection/refraction enable state
    reflectionPass.enable = useReflection;
    refractionPass.enable = useRefraction;

    // water tint color
    final tint = M3Constants.colorBeach;
    setWaterTint(Vector4(tint.x, tint.y, tint.z, 0.6));
  }

  bool renderSurfaceEnabled = true;
  bool get reflectionEnabled => reflectionPass.enable;

  set reflectionEnabled(bool value) {
    reflectionPass.enable = value;
    if (value) {
      reflectionPass.resize(M3AppEngine.instance.appWidth, M3AppEngine.instance.appHeight);
    }
  }

  bool get refractionEnabled => refractionPass.enable;

  set refractionEnabled(bool value) {
    refractionPass.enable = value;
    if (value) {
      refractionPass.resize(M3AppEngine.instance.appWidth, M3AppEngine.instance.appHeight);
    }
  }

  /// water surface tint color
  void setWaterTint(Vector4 tint) {
    color.setFrom(tint);
  }

  /// plane equation: ax + by + cz + d = 0
  void setSurfacePlane({Vector3? normal, double constant = 0}) {
    final Vector3 n = normal ?? surfacePlane.normal;
    surfacePlane.setFromComponents(n.x, n.y, n.z, constant);
    reflectionPass.clipPlane.setFromComponents(n.x, n.y, n.z, constant);
    refractionPass.clipPlane.setFromComponents(n.x, n.y, n.z, constant);

    position = Vector3(0, 0, -constant);
  }

  void resize(int width, int height) {
    reflectionPass.resize(width, height);
    refractionPass.resize(width, height);
  }

  @override
  void update(double dt) {
    super.update(dt);

    flow0.offset += flow0.velocity * dt;
    flow0.offset.x %= 1.0;
    flow0.offset.y %= 1.0;

    flow1.offset += flow1.velocity * dt;
    flow1.offset.x %= 1.0;
    flow1.offset.y %= 1.0;
  }

  void captureWater() {
    progWater.attachLight(scene.light);

    reflectionPass.captureReflection(scene);

    waterFog.customPlane = surfacePlane;
    refractionPass.captureRefraction(scene, waterFog);
  }

  void render({M3FillMode fillMode = M3FillMode.solid}) {
    final viewer = scene.camera;
    if (fillMode == M3FillMode.solid) {
      RenderingContext gl = M3AppEngine.instance.renderEngine.gl;
      gl.enable(WebGL.BLEND);
      gl.blendFunc(WebGL.SRC_ALPHA, WebGL.ONE_MINUS_SRC_ALPHA); // alpha blending
      gl.depthMask(false); // Don't write to depth buffer in blending pass

      final renderEngine = M3AppEngine.instance.renderEngine;
      bool csmEnabled = renderEngine.isShadowEnabled && scene.light.cascades.isNotEmpty;
      csmEnabled = false;
      final dynamic prog = csmEnabled ? progWaterCSM : progWater;
      gl.useProgram(prog.program);
      prog.applyCamera(viewer);
      prog.applyFog(scene.fog);
      prog.bindWater(this);
      if (csmEnabled) {
        prog.bindShadow(renderEngine.shadowMap!.depthTexture);
        prog.applyShadow(scene.light);
      }

      // water material: set reflection texture if enabled
      if (reflectionPass.enable) {
        waterMaterial.diffuseTexture = reflectionPass.texture;
      } else {
        waterMaterial.diffuseTexture = M3Resources.texWhite;
      }

      final alpha = 1.0; //water!.waterMaterial.reflection;
      final waterMatrix = worldMatrix;
      prog.setMatrices(viewer, waterMatrix);
      prog.setMaterial(waterMaterial, Vector4(0.0, 1.0, 0.8, alpha));
      prog.setSkinning(null);

      // Call setLightTBN after setMatrices to set tangent-space uniforms and light position correctly
      final normal = surfacePlane.normal;
      var tangent = Vector3(1.0, 0.0, 0.0);
      if (tangent.dot(normal).abs() > 0.9) {
        tangent = Vector3(0.0, 1.0, 0.0);
      }
      final binormal = normal.cross(tangent).normalized();
      tangent = binormal.cross(normal).normalized();
      prog.setLightTBN(tangent, binormal, normal);

      // reflection for above water, refraction for below water
      mesh.subMeshes[0].geom.draw(prog);
    } else {
      final progEdge = M3Resources.programSimple!;
      final waterMatrix = worldMatrix;
      progEdge.setMatrices(viewer, waterMatrix);
      progEdge.setMaterial(waterMaterial, Vector4(0, 1, 1, 0.6));
      mesh.subMeshes[0].geom.draw(progEdge, fillMode: M3FillMode.wireframe);
    }
  }

  void drawDebug() {
    final passes = {reflectionPass, refractionPass};

    const ratio = 0.5;
    double x = 8;
    double y = 8;
    double w = 0;
    double h = 0;
    for (final pass in passes) {
      if (pass.enable && pass.visible) {
        w = pass.width * ratio;
        h = pass.height * ratio;
        pass.drawDebugReflection(x, y, w, h);
        x += w + 2;
      }
    }

    // water normal map
    Matrix4 matRect = Matrix4.identity();
    matRect.setTranslation(Vector3(x, y, 0.0));
    w = normalMap.texW * ratio;
    h = normalMap.texH * ratio;
    final scaleNormalMap = Vector3(w / normalMap.texW, h / normalMap.texH, 1.0);

    matRect.scaleByVector3(scaleNormalMap);
    M3Shape2D.drawImage(normalMap, matRect);
  }

  void dispose() {
    if (normalMap != M3Resources.texNormal) {
      normalMap.dispose();
    }

    reflectionPass.dispose();
    refractionPass.dispose();
  }
}
