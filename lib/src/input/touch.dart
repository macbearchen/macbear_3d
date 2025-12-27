import 'dart:math';
import 'package:flutter/services.dart';

// Macbear3D engine
import '../../macbear_3d.dart';

part 'input_controller.dart';

class M3TouchPoint {
  final Vector2 position;
  final int buttons; // 1: left, 2: right, 4: middle
  final double time; // 秒
  M3TouchPoint(this.position, this.buttons, this.time);

  String toString() {
    return 'M3TouchPoint(${position.x.toStringAsFixed(2)}, ${position.y.toStringAsFixed(2)}, buttons: $buttons, time: $time)';
  }
}

class M3PinchInfo {
  final double scale; // 縮放比例
  final Vector2 center; // 兩指中心點
  final double distance; // 當前距離

  M3PinchInfo(this.scale, this.center, this.distance);

  @override
  String toString() {
    return 'M3PinchInfo(scale: ${scale.toStringAsFixed(2)}, center: $center, distance: ${distance.toStringAsFixed(2)})';
  }
}

class M3Touch {
  final int id;
  final List<M3TouchPoint> path = [];
  bool isActive = false;
  final int smoothWindow;

  M3Touch(this.id, {this.smoothWindow = 3});

  // touch data: last point and offset
  double get x => path.last.position.x;
  double get y => path.last.position.y;
  Vector2 get offset => path.length > 1 ? path.last.position - path[path.length - 2].position : Vector2.zero();
  int get buttons => path.last.buttons;

  void touchDown(M3TouchPoint point) {
    path.clear();
    path.add(point);
    isActive = true;
  }

  void touchMove(M3TouchPoint point) {
    if (isActive) path.add(point);
  }

  void touchUp(M3TouchPoint point) {
    if (isActive) {
      path.add(point);
      isActive = false;
    }
  }

  void clear() {
    path.clear();
    isActive = false;
  }

  Vector2? smoothedVelocity() {
    if (path.length < 2) return null;
    int start = path.length - smoothWindow - 1;
    if (start < 0) start = 0;
    Vector2 total = Vector2.zero();
    double totalTime = 0.0;

    for (int i = start; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];
      final dt = p2.time - p1.time;
      if (dt == 0) continue;
      total = Vector2(total.x + (p2.position.x - p1.position.x) / dt, total.y + (p2.position.y - p1.position.y) / dt);
      totalTime += 1;
    }
    if (totalTime == 0) return Vector2.zero();
    return Vector2(total.x / totalTime, total.y / totalTime);
  }

  double? smoothedDirection() {
    final vel = smoothedVelocity();
    if (vel == null) return null;
    return atan2(vel.y, vel.x);
  }
}

class M3TouchManager {
  final Map<int, M3Touch> touches = {};
  // 用來記錄上一次 pinch 的距離
  double? _prevPinchDistance;

  /// 返回剛創建或正在操作的 M3Touch
  M3Touch onTouchDown(int pointer, M3TouchPoint point) {
    final touch = M3Touch(pointer)..touchDown(point);
    touches[pointer] = touch;
    return touch;
  }

  M3Touch? onTouchMove(int pointer, M3TouchPoint point) {
    final touch = touches[pointer];
    touch?.touchMove(point);
    return touch;
  }

  M3Touch? onTouchUp(int pointer, M3TouchPoint point) {
    final touch = touches[pointer];
    touch?.touchUp(point);
    return touch;
  }

  /// 🔥 核心：取得 pinch（兩指捏合）資訊
  M3PinchInfo? getPinch() {
    if (touches.length != 2) {
      _prevPinchDistance = null;
      return null;
    }
    final keys = touches.keys.toList();
    final t1 = touches[keys[0]]!;
    final t2 = touches[keys[1]]!;

    final p1 = t1.path.last.position;
    final p2 = t2.path.last.position;

    // 當前距離
    final distance = (p2 - p1).length;

    // 中心點
    final center = Vector2((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);

    // 如果之前沒有資料 → 初始化，不回傳 pinch（避免跳動）
    if (_prevPinchDistance == null) {
      _prevPinchDistance = distance;
      return null;
    }

    // 計算縮放比
    final scale = distance / _prevPinchDistance!;

    // 更新上一次距離
    _prevPinchDistance = distance;

    return M3PinchInfo(scale, center, distance);
  }

  Vector2 getFingerDelta(int fingerCount) {
    if (touches.length != fingerCount) return Vector2.zero();

    final keys = touches.keys.toList();
    Vector2 offset = Vector2.zero();
    for (final key in keys) {
      final touch = touches[key];
      if (touch != null) {
        offset += touch.offset;
      }
    }
    offset /= touches.length.toDouble();
    return offset;
  }

  void clearAll() {
    touches.clear();
  }

  /// 清除所有 inactive touches (已結束的手指)
  void clearInactive() {
    touches.removeWhere((key, touch) => !touch.isActive);
  }
}
