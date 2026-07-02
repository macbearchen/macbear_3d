// ignore_for_file: file_names
import 'package:flutter/material.dart' as fm;
import '../main_all.dart';

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
    const sizeH = 4.0;
    final geomPlane = M3PlaneGeom(sizeH * 3, sizeH, widthSegments: 6, heightSegments: 2, uvScale: Vector2(9.0, 3.0));
    final meshPlane = M3Mesh(geomPlane);
    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(0.65, 0.45, 0.25, 1),
      darkColor: Vector4(0.36, 0.22, 0.12, 1),
    );

    final subA = M3SubMesh(geomPlane);
    final subB = M3SubMesh(geomPlane);
    meshPlane.subMeshes.add(subA);
    meshPlane.subMeshes.add(subB);

    const offsetScale = 1.0;
    subA.localMatrix.setTranslation(Vector3(0, -sizeH * offsetScale, 0));
    subB.localMatrix.setTranslation(Vector3(0, sizeH * offsetScale, 0));

    const roughnessArray = <double>[0.3, 0.0, 0.5];
    for (int i = 0; i < meshPlane.subMeshes.length; i++) {
      meshPlane.subMeshes[i].mtr
        ..reflection = 0.5
        ..metallic = 0.5
        ..roughness = roughnessArray[i]
        ..diffuse = Vector4(0.6, 1.0, roughnessArray[i] + 0.3, 1)
        // ..texDiffuse = texGround
        ..planarReflection = renderEngine.planarReflection;
    }
    renderEngine.planarReflection.setRenderScale(1.0);

    _plane = addMesh(meshPlane, Vector3(0, 0, 0));
    _plane.rotation.setEuler(pi / 12, 0, 0);

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

    dirLight.setEuler(sec * pi / 18, -pi / 3, 0, distance: dirLight.distanceToTarget); // rotate light
    // debugPrint('Light Direction: $dirLight');

    // mirrored plane
    Quaternion rotPlane = Quaternion.euler(0, 0, -orbitAngle / 10.0);
    rotPlane *= Quaternion.euler(pi / 10, 0, 0);
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

      M3Skybox.drawCube(camera, probeMatrix, probe.cubemapTexture!, writeDepth: true);
    }
  }

  @override
  fm.Widget buildUI(fm.BuildContext context) {
    if (mtrTeapot == null) return const fm.SizedBox.shrink();

    return fm.Positioned(
      top: 10,
      left: 10,
      child: fm.Container(
        padding: const fm.EdgeInsets.all(12),
        decoration: fm.BoxDecoration(color: fm.Colors.black54, borderRadius: fm.BorderRadius.circular(12)),
        child: fm.Column(
          mainAxisSize: fm.MainAxisSize.min,
          crossAxisAlignment: fm.CrossAxisAlignment.start,
          children: [
            const fm.Text(
              "Teapot Material",
              style: fm.TextStyle(color: fm.Colors.white, fontWeight: fm.FontWeight.bold),
            ),
            const fm.SizedBox(height: 8),
            _buildSlider("Metallic", () => mtrTeapot!.metallic, (val) {
              mtrTeapot!.metallic = val;
            }),
            _buildSlider("Roughness", () => mtrTeapot!.roughness, (val) {
              mtrTeapot!.roughness = val;
              mtrTeapot!.reflection = 1.0 - val;
            }),
            const fm.SizedBox(height: 16),
            const fm.Text(
              "Reflection Probe",
              style: fm.TextStyle(color: fm.Colors.white, fontWeight: fm.FontWeight.bold),
            ),
            const fm.SizedBox(height: 8),
            _buildToggle("Debug", () => isDebugDraw, (val) => isDebugDraw = val),
            _buildToggle("Enable", () => isEnableProbe, (val) => setReflectionProbe(val)),
            const fm.SizedBox(height: 16),
            const fm.Text(
              "Planar Reflection",
              style: fm.TextStyle(color: fm.Colors.white, fontWeight: fm.FontWeight.bold),
            ),
            const fm.SizedBox(height: 8),
            _buildToggle("Enable", () => isEnablePlanar, (val) => setPlanarReflection(val)),
          ],
        ),
      ),
    );
  }

  fm.Widget _buildToggle(String label, bool Function() getValue, fm.ValueChanged<bool> onChanged) {
    return fm.StatefulBuilder(
      builder: (context, setState) {
        final bool value = getValue();
        return fm.Row(
          mainAxisSize: fm.MainAxisSize.min,
          children: [
            fm.SizedBox(
              width: 80,
              child: fm.Text(label, style: const fm.TextStyle(color: fm.Colors.white70, fontSize: 12)),
            ),
            fm.Switch(
              value: value,
              activeThumbColor: fm.Colors.lightGreen,
              onChanged: (val) {
                setState(() {
                  onChanged(val);
                });
              },
            ),
            fm.Text(value ? "ON" : "OFF", style: const fm.TextStyle(color: fm.Colors.white, fontSize: 12)),
          ],
        );
      },
    );
  }

  fm.Widget _buildSlider(String label, double Function() getValue, fm.ValueChanged<double> onChanged) {
    return fm.StatefulBuilder(
      builder: (context, setState) {
        final double value = getValue();
        return fm.Row(
          mainAxisSize: fm.MainAxisSize.min,
          children: [
            fm.SizedBox(
              width: 80,
              child: fm.Text(label, style: const fm.TextStyle(color: fm.Colors.white70, fontSize: 12)),
            ),
            fm.SizedBox(
              width: 150,
              child: fm.Slider(
                value: value,
                min: 0,
                max: 1,
                activeColor: fm.Colors.lightGreen,
                onChanged: (val) {
                  setState(() {
                    onChanged(val);
                  });
                },
              ),
            ),
            fm.Text(value.toStringAsFixed(2), style: const fm.TextStyle(color: fm.Colors.white, fontSize: 12)),
          ],
        );
      },
    );
  }
}
