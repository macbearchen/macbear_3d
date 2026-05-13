// ignore_for_file: file_names
import 'package:flutter/material.dart' as fm;
import '../main_all.dart';

// ignore: camel_case_types
class ObjTeapotScene_04 extends M3Scene {
  M3Entity? _teapot;
  M3Material? mtrTeapot;
  bool isDrawDebug = false;
  bool isEnableProbe = true;

  // test reflection probe
  late M3ReflectionProbe _probe;
  late M3Entity _orbit1;
  late M3Entity _orbit2;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    camera.setEuler(pi / 6, -pi / 6, 0, distance: 8);

    // 04-1: obj model - using M3Mesh.load()
    final meshTeapot = await M3Mesh.load('example/teapot.obj');
    mtrTeapot = meshTeapot.subMeshes[0].mtr;
    mtrTeapot!.reflection = 0.5;
    mtrTeapot!.metallic = 1.0;
    mtrTeapot!.roughness = 0.2;

    _teapot = addMesh(meshTeapot, Vector3(0, 0, 0));
    _teapot!.color = Vector4(1.0, 0.5, 0.0, 1);

    // 04-2: plane geometry
    final geomPlane = M3PlaneGeom(
      10,
      10,
      widthSegments: 60,
      heightSegments: 60,
      uvScale: Vector2.all(5.0),
      onVertex: (x, y) {
        double rad = pi / 2;
        return (cos(x * rad) + sin(y * rad)) / 3;
      },
    );
    final plane = addMesh(M3Mesh(geomPlane), Vector3(0, 0, -3));

    M3Texture texGround = M3Texture.createCheckerboard(
      size: 2,
      lightColor: Vector4(0.65, 0.45, 0.25, 1),
      darkColor: Vector4(0.36, 0.22, 0.12, 1),
    );
    plane.mesh!.subMeshes[0].mtr.texDiffuse = texGround;

    // 04-3: sample cubemap
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

    // 04-4: orbit around
    final meshCube = M3Mesh(M3Resources.unitCube);
    final meshTorus = M3Mesh(M3TorusGeom(0.4, 0.1));
    meshCube.subMeshes[0].mtr
      ..reflection = 0.0
      ..metallic = 0.0
      ..roughness = 1.0;

    _orbit1 = addMesh(meshCube, Vector3(5, 2, 1));
    _orbit1
      ..rotation.setEuler(0, pi / 3, 0)
      ..color = Vector4(1.0, 0, 1.0, 1.0);

    _orbit2 = addMesh(meshTorus, Vector3(0, 6, 0));
    _orbit2
      ..rotation.setEuler(0, pi / 7, 0)
      ..color = Vector4(0.0, 1.0, 0.3, 1.0);

    // 04-5: reflection probe
    _probe = M3ReflectionProbe(near: 1.0, far: 100.0);
    _probe.excludeEntity = _teapot;

    setReflectionProbe(true);
  }

  void setReflectionProbe(bool enable) {
    isEnableProbe = enable;
    if (enable) {
      _teapot!.reflectionProbe = _probe;
    } else {
      _teapot!.reflectionProbe = null;
    }
  }

  @override
  void update(double delta) {
    super.update(delta);

    double sec = totalTime;
    double orbitAngle = sec * pi / 6;

    light.setEuler(sec * pi / 18, -pi / 3, 0, distance: light.distanceToTarget); // rotate light
    // debugPrint('Light Direction: $dirLight');

    double angle = sec * pi / 9; // 45 degree per second

    _orbit1.rotation.setEuler(angle, angle * 1.2, angle * 2);
    _orbit1.position = Vector3(5 * cos(angle), 5 * sin(angle), 1);
    _orbit2.rotation.setEuler(angle * 3, angle * 5, 0);
    _orbit2.position = Vector3(3 * cos(-angle * 0.7), 2 * sin(-angle * 0.3), 3 * sin(angle * 0.7) + 1.5);

    if (_teapot != null) {
      final quatYPos90 = Quaternion.euler(0, pi / 2, 0);
      _teapot!.position = Vector3(0.5 * cos(orbitAngle), 0, 0.5 * sin(orbitAngle));
      _teapot!.rotation = quatYPos90 * Quaternion.euler(angle, 0, 0);

      if (_teapot!.reflectionProbe != null) {
        // capture reflection probe
        _probe.capture(this, _teapot!.position);
      }
    }
  }

  @override
  void renderDebug() {
    if (!isDrawDebug) return;

    // test for skybox
    Matrix4 boxMatrix = Matrix4.identity();
    boxMatrix.setRotation(M3Constants.rotXPos90);
    boxMatrix.setTranslation(Vector3(-5, 5, 5));
    boxMatrix.scaleByVector3(Vector3.all(3));

    M3Skybox.drawDebug(camera, boxMatrix, skybox!.mtr);

    if (_teapot!.reflectionProbe == null) return;
    // test for probe
    Matrix4 probeMatrix = Matrix4.identity();
    probeMatrix.setRotation(M3Constants.rotXPos90);
    probeMatrix.setTranslation(Vector3(5, 5, 5));
    probeMatrix.scaleByVector3(Vector3.all(3));

    M3Material mtr = M3Material();
    mtr.texDiffuse = _probe.texCubemap!;
    M3Skybox.drawDebug(camera, probeMatrix, mtr);
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
            _buildToggle("Debug", () => isDrawDebug, (val) => isDrawDebug = val),
            _buildToggle("Enable", () => isEnableProbe, (val) => setReflectionProbe(val)),
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
