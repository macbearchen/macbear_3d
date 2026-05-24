// ignore_for_file: file_names
import 'package:flutter/material.dart' hide Matrix4;
import '../main_all.dart' hide Colors;

// ignore: camel_case_types
class SkyboxScene_02 extends M3Scene {
  GraphicsInfo? _gpuInfo;

  late M3ReflectionProbe _probe;
  late M3Entity _center;
  late M3Entity _orbit1;
  late M3Entity _orbit2;
  double orbitAngle = 0.0;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    _gpuInfo ??= PlatformInfo.getGraphicsInfo();
    PlatformInfo.checkGLExtensions();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 8);

    // 02-1: nvlobby cubemap
    final strPrefix = 'example/nvlobby_';
    final strExt = 'jpg';
    skybox = await M3Skybox.createCubemap(
      '${strPrefix}xpos.$strExt',
      '${strPrefix}xneg.$strExt',
      '${strPrefix}ypos.$strExt',
      '${strPrefix}yneg.$strExt',
      '${strPrefix}zpos.$strExt',
      '${strPrefix}zneg.$strExt',
    );

    // 02-2: ball geometry
    M3Texture texGrid = M3Texture.createCheckerboard(size: 10);
    final ballMesh = M3Mesh(M3Resources.unitSphere);
    ballMesh.subMeshes[0].mtr
      ..diffuseTexture = texGrid
      ..reflection = 0.4
      ..metallic = 0.8
      ..roughness = 0.1;
    _center = addMesh(ballMesh, Vector3.zero());
    _center.scale = Vector3.all(3);

    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(0.65, 0.45, 0.25, 1),
      darkColor: Vector4(0.36, 0.22, 0.12, 1),
    );

    // Apply mirror shader to ground
    const posZ = -2.0;
    renderEngine.planarReflection.clipPlane.setFromComponents(0, 0, 1, -posZ);

    final meshPlane = M3Mesh(M3PlaneGeom(12, 12, uvScale: Vector2.all(4.0)));
    meshPlane.subMeshes[0].mtr
      ..reflection = 0.5
      ..roughness = 0.1
      ..planarReflection = renderEngine.planarReflection
      ..diffuseTexture = texGround;

    renderEngine.planarReflection.setScale(0.3);
    final plane = addMesh(meshPlane, Vector3(0, 0, posZ));

    // 02-3: orbit around
    final meshSphere = M3Mesh(M3Resources.unitSphere);
    final meshTorus = M3Mesh(M3TorusGeom(0.6, 0.2));
    meshSphere.subMeshes[0].mtr
      ..reflection = 0.0
      ..metallic = 0.0
      ..roughness = 1.0;

    _orbit1 = addMesh(meshSphere, Vector3(5, 2, 1));
    _orbit1
      ..rotation.setEuler(0, pi / 3, 0)
      ..color = Vector4(1.0, 1.0, 0.0, 1.0);

    _orbit2 = addMesh(meshTorus, Vector3(0, 6, 0));
    _orbit2
      ..rotation.setEuler(0, pi / 7, 0)
      ..color = Vector4(1.0, 0.0, 1.0, 1.0);

    // 02-4: reflection probe
    _probe = M3ReflectionProbe(near: 0.2, far: 50.0);
    _probe.setOwner(_center);
    renderEngine.probes.add(_probe);
  }

  @override
  Widget? buildUI(BuildContext context) {
    if (_gpuInfo == null) return null;
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.black54,
        child: Text(_gpuInfo.toString(), style: const TextStyle(color: Colors.yellow, fontSize: 12)),
      ),
    );
  }

  @override
  void update(double delta) {
    super.update(delta);

    orbitAngle += delta * 0.5;
    _orbit1.position = Vector3(5 * cos(orbitAngle), 5 * sin(orbitAngle), 1);

    _orbit2.position = Vector3(3 * cos(orbitAngle * 0.7), 0, 4 * sin(orbitAngle * 0.7));

    _center.rotation = Quaternion.euler(orbitAngle * 0.1, orbitAngle * 0.2, orbitAngle * 0.3);
    _center.position = Vector3(1 * cos(orbitAngle), 0, 1 * sin(orbitAngle));
  }
}
