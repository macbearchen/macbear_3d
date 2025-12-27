import 'package:oimo_physics/oimo_physics.dart' as oimo;
import 'package:vector_math/vector_math.dart';

class M3PhysicsEngine {
  // physics
  late oimo.World? _world;

  M3PhysicsEngine() {
    final worldConfig = oimo.WorldConfigure(gravity: Vector3(0, 0, -9.81), isStat: true, scale: 1.0);
    final world = oimo.World(worldConfig);
    _world = world;
  }

  oimo.World? get world => _world;

  void update(double sec) {
    if (_world == null) return;
    _world!.step();
  }
}
