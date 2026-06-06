// Macbear3D engine
import '../m3_internal.dart';

/// Configures fog settings for a 3D scene.
class M3Fog {
  Vector3 color = M3Constants.colorSkyBlue;
  double depth = 30.0; // depth fog: end_z - start_z

  // Custom fog plane in world space (optional).
  // If null, standard camera-facing depth fog is used.
  Plane? customPlane;

  M3Fog({this.customPlane});
}
