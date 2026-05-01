// ignore_for_file: file_names
import '../main_all.dart';

// ignore: camel_case_types
class TerrainScene_10 extends M3Scene {
  @override
  Future<void> load() async {
    // 1. Setup Camera
    camera.setLookat(Vector3(15, 15, 15), Vector3(0, 0, 0), Vector3(0, 0, 1));

    // 2. Add Skybox
    skybox = M3Skybox(M3Texture.createSampleCubemap());

    // 3. Create Terrain Geometry
    final terrainGeom = M3TerrainGeom(
      100.0,
      100.0,
      widthSegments: 200,
      heightSegments: 200,
      maxHeight: 8.0,
      noiseScale: 0.08,
    );

    // 4. Create Material for Terrain
    final terrainMtr = M3Material();
    terrainMtr.diffuse = Vector4(0.4, 0.6, 0.3, 1.0); // Grass green
    terrainMtr.specular = Vector3(0.1, 0.1, 0.1);
    terrainMtr.shininess = 10.0;
    terrainMtr.metallic = 0.0;
    terrainMtr.roughness = 0.1;
    terrainMtr.reflection = 0.0;

    // 5. Add Terrain Entity
    final terrainMesh = M3Mesh(terrainGeom, material: terrainMtr);
    addMesh(terrainMesh, Vector3.zero());

    // 6. Add some decorative objects
    final sphereGeom = M3Resources.unitSphere;
    final sphereMtr = M3Material();
    sphereMtr.diffuse = Vector4(1, 0.5, 0, 1);
    sphereMtr.metallic = 1.0;
    sphereMtr.roughness = 0.2;
    sphereMtr.reflection = 0.5;

    final sphereMesh = M3Mesh(sphereGeom, material: sphereMtr);
    final ball = addMesh(sphereMesh, Vector3(0, 0, 10));
    ball.scale = Vector3.all(6);

    await super.load();
  }

  @override
  void update(double delta) {
    super.update(delta);
    // Rotating the light to see terrain shadows moving
    light.setEuler(pi / 5, totalTime * 0.2, 0, distance: 30);
  }
}
