// Macbear3D engine
import '../m3_internal.dart';

class M3WaterFlowLayer {
  Vector2 offset = Vector2.zero();
  Vector2 scale = Vector2.all(1.0);
  Vector2 velocity = Vector2.zero();
}

class M3Water {
  Plane surfacePlane = Plane.components(0, 0, 1, 0);
  M3Texture normalMap = M3Resources.texNormal; // normal-map for water wave distortion
  double waveDistortion = 50.0;
  double reflectionDepthBias = 0.8;
  bool useReflection = true;
  bool useRefraction = true;

  // fog part:
  Vector4 fogColor = Vector4(0.1, 0.2, 0.3, 0.5); // water color: fog in water
  double fogDepth = 0.0; // fog depth: 0 mean no fog

  // for bump flow animation
  M3WaterFlowLayer flow0 = M3WaterFlowLayer()
    ..scale = Vector2.all(0.0012)
    ..velocity = Vector2(0.016, -0.014);
  M3WaterFlowLayer flow1 = M3WaterFlowLayer()
    ..scale = Vector2.all(0.0005)
    ..velocity = Vector2(0.025, -0.03);

  void update(double delta) {
    flow0.offset += flow0.velocity * delta;
    flow0.offset.x %= 1.0;
    flow0.offset.y %= 1.0;

    flow1.offset += flow1.velocity * delta;
    flow1.offset.x %= 1.0;
    flow1.offset.y %= 1.0;
  }

  void dispose() {
    if (normalMap != M3Resources.texNormal) {
      normalMap.dispose();
    }
  }
}
