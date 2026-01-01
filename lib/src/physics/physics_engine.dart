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

  oimo.RigidBody addGround(double sizeW, double sizeH, double sizeD) {
    final groundConfig = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), sizeW, sizeH, sizeD)],
      position: Vector3(0.0, 0.0, -sizeD / 2.0),
    );
    // ignore: unused_local_variable
    final rbGround = _world?.add(groundConfig) as oimo.RigidBody;
    return rbGround;
  }

  void addFence(double sizeW, double sizeH, double sizeD) {
    final fencePosX = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), sizeD, sizeH, sizeD)],
      position: Vector3((sizeW + sizeD) / 2, 0, 0),
    );
    _world?.add(fencePosX);

    final fenceNegX = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), sizeD, sizeH, sizeD)],
      position: Vector3((sizeW + sizeD) / -2, 0, 0),
    );
    _world?.add(fenceNegX);

    final fencePosY = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), sizeW, sizeD, sizeD)],
      position: Vector3(0, (sizeW + sizeD) / 2, 0),
    );
    _world?.add(fencePosY);
    final fenceNegY = oimo.ObjectConfigure(
      shapes: [oimo.Box(oimo.ShapeConfig(geometry: oimo.Shapes.box), sizeW, sizeD, sizeD)],
      position: Vector3(0, (sizeW + sizeD) / -2, 0),
    );
    _world?.add(fenceNegY);
  }
}
