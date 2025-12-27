part of 'touch.dart';

abstract class M3InputController {
  // touch events
  void onTouchDown(M3Touch touch);
  void onTouchMove(M3Touch touch);
  void onTouchUp(M3Touch touch);

  // mouse wheel events
  void onScroll(double scrollDelta);

  // keyboard events
  void onKeyDown(KeyDownEvent e);
  void onKeyUp(KeyUpEvent e);
  void onKeyRepeat(PhysicalKeyboardKey key);
}

class M3CameraOrbitController extends M3InputController {
  final M3Camera camera;
  M3CameraOrbitController(this.camera);

  // user custom touch events
  @override
  void onTouchDown(M3Touch touch) {}

  @override
  void onTouchUp(M3Touch touch) {}

  @override
  void onTouchMove(M3Touch touch) {
    // 1 touch move, 2 touch pinch
    final touchMgr = M3AppEngine.instance.touchManager;
    final touchCount = touchMgr.touches.length;
    if (touchCount <= 2) {
      final pinch = touchMgr.getPinch();
      if (pinch != null) {
        applyZoom(pinch);
        debugPrint("Scale: ${pinch.scale}, Center: ${pinch.center}");
      } else {
        if (touch.buttons == 1) {
          applyOrbit(touch);
        } else if (touch.buttons == 2) {
          applyPan(touch.offset);
        }
      }
    } else {
      final offset = touchMgr.getFingerDelta(3);
      applyPan(offset);
    }
  }

  @override
  void onScroll(double scrollDelta) {
    final pinch = M3PinchInfo(1 + scrollDelta / 1000, Vector2.zero(), 0);
    applyZoom(pinch);
  }

  void applyZoom(M3PinchInfo pinch) {
    final euler = camera.euler;
    double distance = camera.distanceToTarget / pinch.scale;
    distance = distance.clamp(2, 100);
    camera.setEuler(euler.yaw, euler.pitch, euler.roll, distance: distance);
  }

  void applyOrbit(M3Touch touch) {
    // double radYaw = touch.x * pi / 180;
    // double radPitch = touch.y * pi / 180;
    double radYaw = touch.offset.x * pi / 180;
    double radPitch = touch.offset.y * pi / 180;
    final euler = camera.euler;
    euler.yaw -= radYaw;
    euler.pitch -= radPitch;
    camera.setEuler(euler.yaw, euler.pitch, euler.roll, distance: camera.distanceToTarget);
  }

  void applyPan(Vector2 offset) {
    double distance = camera.distanceToTarget;
    offset = offset * distance / 200;
    final moveTo = camera.cameraToWorldMatrix.getRotation() * Vector3(-offset.x, offset.y, 0);
    camera.target += moveTo;
    // debugPrint("Offset: $offset, MoveTo: $moveTo, Target: ${camera.target}");

    final euler = camera.euler;
    camera.setEuler(euler.yaw, euler.pitch, euler.roll, distance: distance);
  }

  @override
  void onKeyDown(KeyDownEvent e) {}

  @override
  void onKeyUp(KeyUpEvent e) {}

  @override
  void onKeyRepeat(PhysicalKeyboardKey key) {}
}
