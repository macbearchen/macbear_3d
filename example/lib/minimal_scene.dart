import 'dart:math';

import 'package:macbear_3d/macbear_3d.dart';

class MinimalScene extends M3Scene {
  final _geomCube = M3BoxGeom(1.0, 1.0, 1.0);
  M3Entity? _cube;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    // Set up camera
    camera.setLookat(Vector3(0, 3, 5), Vector3(0, 0, 0), Vector3(0, 0, 1));
    camera.setEuler(0, -pi / 6, 0, distance: 8);

    // Add a simple cube
    _cube = addMesh(M3Mesh(_geomCube), Vector3(0, 0, 0));
    _cube!.color = Colors.blue;
  }

  @override
  void update(Duration elapsed) {
    super.update(elapsed);

    double sec = elapsed.inMilliseconds / 1000.0;
    double angle = sec * pi / 2; // 90 degrees per second

    if (_cube != null) {
      _cube!.rotation.setEuler(0, 0, angle);
    }
  }
}
