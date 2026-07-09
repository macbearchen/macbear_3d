// ignore_for_file: file_names
import 'package:flutter/material.dart';
import '../main_all.dart' hide Colors;

// ignore: camel_case_types
class TerrainScene_06 extends DemoScene {
  M3Entity? _terrainEntity;
  bool _useHeightmap = true;
  double _waterHeight = 0.0;

  double get _minWaterHeight => -8.0;
  double get _maxWaterHeight => 8.0;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    renderEngine.options.shader.fog = true;
    fog.planeHeight = 6.0;

    camera.setEuler(-pi / 3, -pi / 9, 0, distance: 40);
    M3Log.i('TerrainScene', 'Camera: $camera');
    // 2. Add Skybox
    skybox = M3Skybox(M3Texture.createDefaultIBLCube());

    // 3. Setup Terrain
    await _setupTerrain();

    // 4. Add Water
    await addWater();

    // 5. Add Mesh List
    addMesh(M3Resources.axisGizmoMesh, Vector3(0, 0, 0));
    _initMeshList();
  }

  Future<void> addWater() async {
    final water = M3Water();
    water.scene = this;
    water.normalMap = M3Texture.createWaterNormalMap(size: 256, strength: 3.0);

    water.setSurfacePlane(constant: -_waterHeight);
    final waterColor = Vector3(0, 0, 1);
    // final waterColor = M3Constants.colorOcean;
    water.setWaterTint(Vector4(waterColor.x, waterColor.y, waterColor.z, 1.0));
    water.waveDistortion = 3;

    setWater(water);
  }

  void _initMeshList() {
    M3Texture texGrid = M3Texture.createCheckerboard(size: 5);
    M3Texture texGrid2 = M3Texture.createCheckerboard(size: 6);

    final geomBox = M3BoxGeom(2, 3, 6);
    final geomSphere = M3SphereGeom(2.5);
    final geomCylinder = M3CylinderGeom(1.5, 1.5, 8, heightSegments: 2);
    final geomTorus = M3TorusGeom(2, 0.6);

    for (int i = 0; i <= 10; i++) {
      final double posX = i * 10 - 50;
      final double posY = 5;
      final double posZ = posX * 0.15;
      final rot = i * pi / 15;
      // 06-2: sphere geometry
      final meshSphere = M3Mesh(geomSphere);
      meshSphere.name = 'SphereMesh';
      meshSphere.subMeshes[0].mtr
        ..diffuse = Vector4(1, 0.3, 0, 1)
        ..specular = Vector3.all(0.6)
        ..shininess = i * 10 + 8
        // ..reflection = i * 0.1
        // ..metallic = i * 0.1
        // ..roughness = 1.0 - i * 0.1
        ..diffuseTexture = texGrid2;

      addMesh(meshSphere, Vector3(posX, posY, posZ));

      // 06-3: cylinder geometry
      final mtrCylinder = M3Material()
        ..setMatte()
        ..diffuseTexture = texGrid;

      final meshCylinder = M3Mesh(geomCylinder, material: mtrCylinder);
      meshCylinder.name = 'CylinderMesh';
      final cylinder = addMesh(meshCylinder, Vector3(posX, posY + 5, posZ + 3))..color = Vector4(1, 1, 0, 1);
      cylinder.rotation.setEuler(rot, 0, 0);

      // 06-3: box geometry
      final mtrBox = M3Material()..diffuseTexture = texGrid;
      final box = addMesh(M3Mesh(geomBox, material: mtrBox), Vector3(posX / 2, posY + 10, posZ * 1.5 + 2));
      box.mesh.name = 'BoxMesh';
      box.rotation.setEuler(0, 0, rot);

      // 06-4: torus geometry
      final torus = addMesh(M3Mesh(geomTorus), Vector3(posX, posY + 15, posZ + 2));
      torus.mesh.name = 'TorusMesh';
      torus.mesh.subMeshes[0].mtr.diffuseTexture = texGrid2;
      torus.rotation.setEuler(0, rot, 0);
    }
  }

  Future<void> _setupTerrain() async {
    M3AppEngine.instance.pause();

    if (_terrainEntity != null) {
      entities.remove(_terrainEntity);
      for (final subMesh in _terrainEntity!.mesh.subMeshes) {
        subMesh.geom.dispose();
      }
      _terrainEntity = null;
    }

    final terrainMtr = M3Material();
    terrainMtr.setMatte();

    M3TerrainGeom terrainGeom;

    if (_useHeightmap) {
      // https://www.motionforgepictures.com/height-maps/
      terrainGeom = await M3TerrainGeom.fromHeightmapAsset(
        'assets/example/Height16.png',
        200.0,
        200.0,
        widthSegments: 500,
        heightSegments: 500,
        maxHeight: 400.0,
      );
      final texTerrain = await M3Texture.loadTexture('example/HeightDiffuse.jpg');
      // final texTerrain = await M3Texture.loadTexture('example/Height16.png');
      // terrainMtr.diffuse = Vector4(0.8, 0.4, 0.4, 1.0); // Terracotta color
      terrainMtr.diffuseTexture = texTerrain;
    } else {
      // Procedural noise
      terrainGeom = M3TerrainGeom(
        200.0,
        200.0,
        widthSegments: 400,
        heightSegments: 400,
        maxHeight: 16.0,
        noiseScale: 0.08,
      );
      terrainMtr.diffuse = Vector4(0.4, 0.6, 0.3, 1.0); // Grass green
    }

    final terrainMesh = M3Mesh(terrainGeom, material: terrainMtr);
    _terrainEntity = addMesh(terrainMesh, Vector3(0, 0, -13));

    M3AppEngine.instance.resume();
  }

  @override
  void update(double delta) {
    super.update(delta);

    const double rot = pi / 15;
    int indexBox = 0;
    int indexTorus = 0;
    int indexCylinder = 0;
    for (final e in entities) {
      if (e.mesh.name == 'BoxMesh') {
        e.setEuler(0, 0, totalTime + rot * indexBox * 0.3);
        indexBox++;
      }

      if (e.mesh.name == 'TorusMesh') {
        e.setEuler(0, totalTime + rot * indexTorus, 0);
        indexTorus++;
      }

      if (e.mesh.name == 'CylinderMesh') {
        e.setEuler(totalTime + rot * indexCylinder * 0.6, 0, 0);
        indexCylinder++;
      }
    }
  }

  @override
  Widget buildUI(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreen, foregroundColor: Colors.black),
              onPressed: () async {
                _useHeightmap = !_useHeightmap;
                await _setupTerrain();
                _waterHeight = _waterHeight.clamp(_minWaterHeight, _maxWaterHeight);
                water?.setSurfacePlane(constant: -_waterHeight);
                M3AppEngine.instance.refresh();
              },
              child: Text(
                _useHeightmap ? "Switch to Noise" : "Switch to Heightmap",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Water Height: ${_waterHeight.toStringAsFixed(1)}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: _waterHeight.clamp(_minWaterHeight, _maxWaterHeight),
                  min: _minWaterHeight,
                  max: _maxWaterHeight,
                  activeColor: Colors.lightGreen,
                  inactiveColor: Colors.white24,
                  onChanged: (value) {
                    _waterHeight = value;
                    water?.setSurfacePlane(constant: -_waterHeight);
                    M3AppEngine.instance.refresh();
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Wave Distortion: ${(water?.waveDistortion ?? 3.0).toStringAsFixed(1)}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: (water?.waveDistortion ?? 3.0).clamp(0.0, 20.0),
                  min: 0.0,
                  max: 20.0,
                  activeColor: Colors.lightGreen,
                  inactiveColor: Colors.white24,
                  onChanged: (value) {
                    if (water != null) {
                      water!.waveDistortion = value;
                      M3AppEngine.instance.refresh();
                    }
                  },
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Reflection",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Switch(
                    value: water?.reflectionEnabled ?? false,
                    activeThumbColor: Colors.lightGreen,
                    onChanged: (value) {
                      water?.reflectionEnabled = value;
                      M3AppEngine.instance.refresh();
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Refraction",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Switch(
                    value: water?.refractionEnabled ?? false,
                    activeThumbColor: Colors.lightGreen,
                    onChanged: (value) {
                      water?.refractionEnabled = value;
                      M3AppEngine.instance.refresh();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
