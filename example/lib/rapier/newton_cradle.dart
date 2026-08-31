import 'package:material_ui/material_ui.dart' as fm;
import 'base_scene.dart';

/// Newton's Cradle demo.
///
/// Coordinate system: gravity = (0, 0, -9.8)  →  Z is UP.
///   • Balls hang below the pivot rail along -Z.
///   • Swinging happens in the XZ plane.
///   • Hinge axis = Y  →  rotation around Y allows XZ-plane swing.
class NewtonCradleScene extends BaseScene {
  double _cradleYOffset = 0.0;

  // constructor
  NewtonCradleScene({required super.physics});

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    // addCradle();
  }

  void addCradle({int count = 5, double length = 4.0}) {
    _addNewtonCradle(count: count, length: length, yCenter: _cradleYOffset);
    _cradleYOffset += 4.0;
  }

  M3Mesh _createFrameMesh(double frameW, double yOff, double cradleZ) {
    // ── Visual-only frame (no physics body needed for a static frame) ─────────
    final halfW = frameW / 2.0;
    final frameMesh = M3Mesh(null);

    // Two horizontal rails at the top (front and back)
    final railGeom = M3BoxGeom(frameW, 0.12, 0.12);
    final subRail = M3SubMesh(railGeom);
    final subRail2 = M3SubMesh(railGeom);
    subRail.localMatrix.translateByVector3(Vector3(0, yOff, cradleZ));
    subRail2.localMatrix.translateByVector3(Vector3(0, -yOff, cradleZ));
    frameMesh.subMeshes.add(subRail);
    frameMesh.subMeshes.add(subRail2);

    // Four vertical corner legs
    final legGeom = M3BoxGeom(0.12, 0.12, cradleZ);
    final posArray = [
      Vector3(-halfW, -yOff, cradleZ / 2),
      Vector3(halfW, -yOff, cradleZ / 2),
      Vector3(-halfW, yOff, cradleZ / 2),
      Vector3(halfW, yOff, cradleZ / 2),
    ];
    for (final pos in posArray) {
      final subMesh = M3SubMesh(legGeom);
      subMesh.localMatrix.translateByVector3(pos);
      frameMesh.subMeshes.add(subMesh);
    }

    // Bottom crossbars connecting front / back legs at ground level
    final crossGeom = M3BoxGeom(0.12, yOff * 2, 0.12);
    final subCross = M3SubMesh(crossGeom);
    final subCross2 = M3SubMesh(crossGeom);
    subCross.localMatrix.translateByVector3(Vector3(-halfW, 0, 0.06));
    subCross2.localMatrix.translateByVector3(Vector3(halfW, 0, 0.06));
    frameMesh.subMeshes.add(subCross);
    frameMesh.subMeshes.add(subCross2);

    return frameMesh;
  }

  // ── Newton's Cradle ─────────────────────────────────────────────────────────
  void _addNewtonCradle({required int count, required double length, double yCenter = 0.0}) {
    const spacing = 1.07; // tiny gap between balls
    final cradleZ = length + 1.0; // Z height of the top pivot rail
    final frameW = (count - 1) * spacing + 2.0; // rail length
    const yOff = 0.9; // front / back rail offset

    // ── Visual-only frame (no physics body needed for a static frame) ─────────
    final frameMesh = _createFrameMesh(frameW, yOff, cradleZ);
    addMesh(frameMesh, Vector3(0, yCenter, 0));

    // ── Balls + hinge (revolute) joints ──────────────────────────────────────
    //
    // addRevoluteJointToWorld(body, worldAxis, localAnchor, worldAnchor)
    //
    //   worldAxis   = (0, 1, 0)         → rotate around Y → ball swings in XZ plane
    //   localAnchor = (0, 0, length)    → from ball centre UP to the pivot,
    //                                      in the ball's own local frame
    //   worldAnchor = (x, yCenter, cradleZ)  → the fixed pivot position in world space

    final ballMesh = createPendulum(0.5, length);
    final restZ = cradleZ - length; // ball centre height when hanging at rest

    RigidBody? rb0;

    for (int i = 0; i < count; i++) {
      final x = (i - (count - 1) / 2.0) * spacing;
      final pos = Vector3(x, yCenter, restZ);

      final entity = addMesh(ballMesh, pos)..color = Colors.skyBlue;
      final rb = physicsSystem.addSphere(0.5, desc: M3RigidBodyDesc.dynamic()..position = pos);
      physicsSystem.attachEntity(entity, rb);

      if (rb is M3RapierRigidBody) {
        for (final c in rb.colliders) {
          c.restitution = 1.0;
          c.friction = 0.0;
        }

        rb.setCCD(true);
        rb.wakeUp();

        // Every ball (including ball 0) must have a joint
        // world.addRevoluteJointToWorld(
        //   rb,
        //   Vector3(0, 1, 0), // hinge axis = Y
        //   Vector3(0, 0, length), // local anchor: pivot is `length` above ball centre
        //   Vector3(x, yCenter, cradleZ), // world anchor: pivot position on the rail
        // );

        if (rbGround is M3RapierRigidBody) {
          world.addRevoluteJoint(
            rb,
            rbGround as RigidBody,
            Vector3(0, 1, 0), // hinge axis = Y
            Vector3(0, 0, length), // local anchor: pivot is `length` above ball centre
            Vector3(x, yCenter, cradleZ), // world anchor: pivot position on the rail
          );
        }
        if (i == 0) {
          rb0 = rb;
        }
      }
    }

    // Pull the leftmost ball back 60° to kick off the cradle motion.
    // Arc formula: newPos = pivot + length * (−sin θ along X,  −cos θ along Z)
    final pivotX = -(count - 1) / 2.0 * spacing;
    const pullAngle = pi / 3; // 60°
    rb0?.setPosition(Vector3(pivotX - length * sin(pullAngle), yCenter, cradleZ - length * cos(pullAngle)));
  }

  @override
  fm.Widget buildUI(fm.BuildContext context) {
    return fm.Stack(
      children: [
        fm.Align(
          alignment: fm.Alignment.topLeft,
          child: fm.Padding(
            padding: const fm.EdgeInsets.only(right: 24.0, bottom: 32.0),
            child: fm.ElevatedButton.icon(
              style: fm.ElevatedButton.styleFrom(
                backgroundColor: fm.Colors.blueAccent,
                foregroundColor: fm.Colors.white,
                padding: const fm.EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: fm.RoundedRectangleBorder(borderRadius: fm.BorderRadius.circular(12)),
              ),
              onPressed: () => addCradle(),
              icon: const fm.Icon(fm.Icons.add, size: 22),
              label: const fm.Text(
                'Add Newton Cradle',
                style: fm.TextStyle(fontSize: 15, fontWeight: fm.FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
