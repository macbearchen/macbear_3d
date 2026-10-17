// ignore_for_file: file_names
import 'demo_scene.dart';

// ignore: camel_case_types
class ObjTeapotScene_04 extends DemoScene {
  M3Entity? _teapot;
  M3Material? mtrTeapot;

  bool isDebugDraw = false;
  bool isEnableProbe = true;
  bool isEnablePlanar = true;

  // test reflection probe
  late M3ReflectionProbe _probe;
  late M3Entity _orbit1;
  late M3Entity _orbit2;
  late M3Entity _plane;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    // 04-1: sample cubemap
    skybox = await createCubemapLobby(); // nvlobby cubemap

    // 04-2: obj model - using M3Mesh.load()
    final meshTeapot = await M3Mesh.load('example/teapot.obj');
    meshTeapot.subMeshes[0].localMatrix.setTranslation(Vector3(0, -1.0, 0));
    mtrTeapot = meshTeapot.subMeshes[0].mtr;
    mtrTeapot!
      ..reflection = 0.5
      ..metallic = 1.0
      ..roughness = 0.2;

    _teapot = addMesh(meshTeapot, Vector3(0, 0, 0));
    _teapot!.color = Vector4(1.0, 0.6, 0.5, 1);

    // 04-3: plane geometry
    // Apply mirror shader to ground
    final planeMesh = M3TiledPlaneMesh(tilesX: 5, tilesY: 1, tileWidth: 2, tileHeight: 12);
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(0.65, 0.45, 0.25, 1),
      darkColor: Vector4(0.36, 0.22, 0.12, 1),
    );

    for (int i = 0; i < planeMesh.subMeshes.length; i++) {
      double roughness = i / (planeMesh.subMeshes.length - 1);
      planeMesh.subMeshes[i].mtr
        ..reflection = 0.5
        ..metallic = 0.5
        ..roughness = roughness
        ..diffuse = Vector4(0.8, 1.0, 0.7, 1)
        // ..texDiffuse = texGround
        ..planarReflection = renderEngine.planarReflection;
    }
    renderEngine.renderTargets.get('mirror').setRenderScale(1.0);

    _plane = addMesh(planeMesh, Vector3(0, 0, 0));
    // _plane.rotation.setEuler(pi / 12, 0, 0);

    // 04-4: orbit around
    final meshCube = createCompoundMesh();
    final meshTorus = M3Mesh(M3TorusGeom(0.6, 0.2));
    meshCube.subMeshes[0].mtr
      ..reflection = 0.0
      ..metallic = 0.0
      ..roughness = 1.0;

    _orbit1 = addMesh(meshCube, Vector3(5, 2, 1));
    _orbit1
      ..rotation.setEuler(0, pi / 3, 0)
      ..color = Vector4(1.0, 1.0, 0.3, 1.0);

    _orbit2 = addMesh(meshTorus, Vector3(0, 6, 0));
    _orbit2
      ..rotation.setEuler(0, pi / 7, 0)
      ..color = Vector4(0.2, 0.3, 0.96, 1.0);

    // 04-5: reflection probe
    _probe = M3ReflectionProbe(near: 0.2, far: 50.0);
    renderEngine.probes.add(_probe);
    _probe.setOwner(_teapot);

    // reflection setting
    setReflectionProbe(true);
  }

  void setReflectionProbe(bool enable) {
    isEnableProbe = enable;
    _probe.setOwner(enable ? _teapot : null);
  }

  void setPlanarReflection(bool enable) {
    isEnablePlanar = enable;
    for (final sub in _plane.mesh.subMeshes) {
      sub.mtr.planarReflection = enable ? renderEngine.planarReflection : null;
    }
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;
    double orbitAngle = sec * pi / 6;

    // mirrored plane
    Quaternion rotPlane = Quaternion.euler(0, 0, -orbitAngle / 5.0);
    rotPlane *= Quaternion.euler(pi / 30, 0, 0);
    _plane.rotation = rotPlane;
    _plane.position = Vector3(0, 0, -1.0);
    final normalZ = _plane.worldMatrix.getRotation() * Vector3(0, 0, 1);
    final d = -_plane.position.dot(normalZ);
    renderEngine.planarReflection.clipPlane.setFromComponents(normalZ.x, normalZ.y, normalZ.z, d);

    double angle = sec * pi / 9; // 45 degree per second

    _orbit1.setEuler(angle, angle * 1.2, angle * 2);
    _orbit1.position = Vector3(5 * cos(angle), 5 * sin(angle), 1);
    _orbit2.setEuler(angle * 3, angle * 5, 0);
    _orbit2.position = Vector3(3 * cos(-angle * 0.7), 2 * sin(-angle * 0.3), 3 * sin(angle * 0.7) + 1.5);

    if (_teapot != null) {
      final quatYPos90 = Quaternion.euler(0, pi / 2, 0);
      _teapot!.position = Vector3(0.5 * cos(orbitAngle), 0, 0.5 * sin(orbitAngle) + 1.0);
      _teapot!.rotation = quatYPos90 * Quaternion.euler(angle, 0, 0);
    }
  }

  @override
  void debugDraw() {
    if (!isDebugDraw) return;

    // test for skybox
    Matrix4 boxMatrix = Matrix4.identity();
    boxMatrix.setRotation(M3Constants.rotXPos90);
    boxMatrix.setTranslation(Vector3(-5, 5, 5));
    boxMatrix.scaleByVector3(Vector3.all(3));

    M3Skybox.drawCube(camera, boxMatrix, skybox!.cubemapTexture, writeDepth: true);

    final probe = _teapot?.getProbe();
    if (probe != null) {
      // test for probe
      Matrix4 probeMatrix = Matrix4.identity();
      probeMatrix.setRotation(M3Constants.rotXPos90);
      probeMatrix.setTranslation(Vector3(5, 5, 5));
      probeMatrix.scaleByVector3(Vector3.all(3));

      M3Skybox.drawCube(camera, probeMatrix, probe.cubemapTexture, writeDepth: true);
    }
  }

  @override
  Widget buildUI(BuildContext context) {
    if (mtrTeapot == null) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Teapot Material",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            _buildSlider("Metallic", () => mtrTeapot!.metallic, (val) {
              mtrTeapot!.metallic = val;
            }),
            _buildSlider("Roughness", () => mtrTeapot!.roughness, (val) {
              mtrTeapot!.roughness = val;
              mtrTeapot!.reflection = 1.0 - val;
            }),
            const SizedBox(height: 10),
            const Text(
              "Reflection Probe",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            _buildToggle("Debug", () => isDebugDraw, (val) => isDebugDraw = val),
            _buildToggle("Enable", () => isEnableProbe, (val) => setReflectionProbe(val)),
            const SizedBox(height: 10),
            const Text(
              "Planar Reflection",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            _buildToggle("Enable", () => isEnablePlanar, (val) => setPlanarReflection(val)),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool Function() getValue, ValueChanged<bool> onChanged) {
    return StatefulBuilder(
      builder: (context, setState) {
        final bool value = getValue();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            Switch(
              value: value,
              activeThumbColor: Colors.lightGreen,
              onChanged: (val) {
                setState(() {
                  onChanged(val);
                });
              },
            ),
            Text(value ? "ON" : "OFF", style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        );
      },
    );
  }

  Widget _buildSlider(String label, double Function() getValue, ValueChanged<double> onChanged) {
    return StatefulBuilder(
      builder: (context, setState) {
        final double value = getValue();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            SizedBox(
              width: 150,
              child: Slider(
                value: value,
                min: 0,
                max: 1,
                activeColor: Colors.lightGreen,
                onChanged: (val) {
                  setState(() {
                    onChanged(val);
                  });
                },
              ),
            ),
            Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        );
      },
    );
  }
}
