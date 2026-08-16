// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../main_all.dart' hide Colors;

// ignore: camel_case_types
class TerrainScene_06 extends DemoScene {
  M3TiledTerrain? _tiledTerrain;
  M3Entity? _terrainEntity;
  bool _useHeightmap = true;
  bool _useTiled = true;
  bool _useLod = true;
  double _waterHeight = 0.0;

  double get _minWaterHeight => -8.0;
  double get _maxWaterHeight => 8.0;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    renderEngine.options.shader.fog = true;
    fog.planeHeight = 6.0;
    fog.start = 700;
    fog.depth = 70;

    camera.farClip = 800;
    camera.refreshProjectionMatrix();
    camera.setEuler(pi / 4, -pi / 9, 0, distance: 30);
    M3Log.i('TerrainScene', 'Camera: $camera');
    // 2. Add Skybox
    skybox = M3Skybox(M3Texture.createDefaultIBLCube());

    // 3. Setup Terrain
    await _setupTerrain();

    // 4. Add Water
    await addWater();

    // 5. Add Mesh List
    _initMeshList();

    for (int i = 0; i <= 10; i++) {
      final axisMesh = M3Resources.axisGizmoMesh.clone();
      addMesh(axisMesh, Vector3(0, 100.0 * i, 10));
    }
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
    final geomCylinder = M3CylinderGeom(topRadius: 0.5, bottomRadius: 1.5, height: 6, heightSegments: 2);
    final geomTorus = M3TorusGeom(2, 0.6);

    for (int i = 0; i <= 10; i++) {
      final double posX = i * 10 - 50;
      final double posY = 5;
      final double posZ = posX * 0.15 + 5;
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
      if (_tiledTerrain != null) {
        _tiledTerrain!.dispose();
        _tiledTerrain = null;
      } else {
        for (final subMesh in _terrainEntity!.mesh.subMeshes) {
          subMesh.geom.dispose();
        }
      }
      _terrainEntity = null;
    }

    final terrainMtr = M3Material()..setMatte();
    M3Mesh terrainMesh;

    final terrainSegments = 512;
    final terrainSize = 512.0;
    final tileSegments = 32;
    final maxHeight = 1024.0;

    if (_useHeightmap) {
      final buffer = await M3ResourceManager.loadBuffer('assets/example/Height16.png');
      final image = img.decodeImage(buffer.asUint8List());
      if (image == null) throw Exception('Failed to decode heightmap');
      final texTerrain = await M3Texture.loadTexture('example/HeightDiffuse.jpg');
      terrainMtr.diffuseTexture = texTerrain;

      final hf = M3HeightField.fromHeightmap(
        image,
        terrainSize,
        terrainSize,
        widthSegments: terrainSegments,
        heightSegments: terrainSegments,
        maxHeight: maxHeight,
      );
      if (_useTiled) {
        // Mode 1: Tiled + Heightmap

        _tiledTerrain = M3TiledTerrain.fromHeightField(
          hf,
          terrainSize,
          terrainSize,
          tileWidthSegments: tileSegments,
          tileHeightSegments: tileSegments,
          maxHeight: maxHeight,
          material: terrainMtr,
        );
        terrainMesh = _tiledTerrain!.mesh;
      } else {
        // Mode 2: Single Mesh + Heightmap
        _tiledTerrain = null;
        final terrainGeom = M3TerrainGeom.fromHeightField(hf, terrainSize, terrainSize, maxHeight: maxHeight);
        terrainMesh = M3Mesh(terrainGeom, material: terrainMtr);
      }
    } else {
      terrainMtr.diffuse = Vector4(0.4, 0.6, 0.3, 1.0); // Grass green

      if (_useTiled) {
        // Mode 3: Tiled + Procedural Noise
        _tiledTerrain = M3TiledTerrain.build(
          terrainSize,
          terrainSize,
          widthSegments: terrainSegments,
          heightSegments: terrainSegments,
          tileWidthSegments: tileSegments,
          tileHeightSegments: tileSegments,
          maxHeight: 16.0,
          noiseScale: 0.08,
          material: terrainMtr,
        );
        terrainMesh = _tiledTerrain!.mesh;
      } else {
        // Mode 4: Single Mesh + Procedural Noise
        _tiledTerrain = null;
        final terrainGeom = M3TerrainGeom(
          terrainSize,
          terrainSize,
          widthSegments: terrainSegments,
          heightSegments: terrainSegments,
          maxHeight: 16.0,
          noiseScale: 0.08,
        );
        terrainMesh = M3Mesh(terrainGeom, material: terrainMtr);
      }
    }

    if (_tiledTerrain != null) {
      _tiledTerrain!.enableLod = _useLod;
    }

    double posZ = _useHeightmap ? -21 : -9;
    _terrainEntity = addMesh(terrainMesh, Vector3(0, 0, posZ));
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

    // update Lod by camera position every frame
    if (_tiledTerrain != null) {
      _tiledTerrain!.updateLod(camera.position, worldMatrix: _terrainEntity?.worldMatrix);
    }
  }

  @override
  Widget buildUI(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setUIState) {
        return SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightGreen,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        _useHeightmap = !_useHeightmap;
                        await _setupTerrain();
                        _waterHeight = _waterHeight.clamp(_minWaterHeight, _maxWaterHeight);
                        water?.setSurfacePlane(constant: -_waterHeight);
                        setUIState(() {});
                        M3AppEngine.instance.refresh();
                      },
                      child: Text(
                        _useHeightmap ? "Heightmap" : "Noise",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_useTiled ? Colors.cyan : (_useLod ? Colors.orangeAccent : Colors.grey),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        if (!_useTiled) {
                          // Single -> Tile LOD on
                          _useTiled = true;
                          _useLod = true;
                          await _setupTerrain();
                        } else if (_useLod) {
                          // Tile LOD on -> Tile LOD off
                          _useLod = false;
                          _tiledTerrain?.enableLod = false;
                        } else {
                          // Tile LOD off -> Single
                          _useTiled = false;
                          await _setupTerrain();
                        }
                        _waterHeight = _waterHeight.clamp(_minWaterHeight, _maxWaterHeight);
                        water?.setSurfacePlane(constant: -_waterHeight);
                        setUIState(() {});
                        M3AppEngine.instance.refresh();
                      },
                      child: Text(
                        !_useTiled ? "Single" : (_useLod ? "Tile LOD on" : "Tile LOD off"),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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
      },
    );
  }
}
