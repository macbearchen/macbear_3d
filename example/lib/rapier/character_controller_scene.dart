// ignore_for_file: unused_local_variable, unused_field
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' as fm;
import 'package:flutter/services.dart';

import 'base_scene.dart';

/// Demo scene showcasing [KinematicCharacterController].
///
/// A capsule character walks autonomously on a flat ground, up a ramp, and
/// over two steps — demonstrating slope-climbing, auto-stepping, and ground-
/// snapping. Gravity is applied manually each frame; the controller handles
/// collision resolution.
class CharacterControllerScene extends BaseScene {
  // ── Meshes ──────────────────────────────────────────────────────────────────
  final _capsuleMesh = M3Mesh(M3CapsuleGeom(radius: 0.25, height: 0.6, axis: M3Axis.z));
  final _rampMesh = M3Mesh(M3BoxGeom(8, 6, 0.6));
  final _boxMesh = M3Mesh(M3BoxGeom(3, 3, 0.3));

  // ── Physics ─────────────────────────────────────────────────────────────────
  // rapier types — obtained directly from the RapierWorld
  late RigidBody _characterBody;
  late Collider _characterCollider;
  late M3Entity _characterEntity;
  late KinematicCharacterController _ctrl;

  Vector3 moveCtrl = Vector3.zero();
  late CharControllerKeyboardInput _inputCtrl;

  // ── State ───────────────────────────────────────────────────────────────────
  // Z-up world: gravity is -Z, up is +Z
  static const double _gravity = -9.8; // m/s² in -Z
  static const double _moveSpeed = 4.0; // m/s horizontal
  static const double _jumpSpeed = 1.0; // m/s upward

  double _verticalVelocity = 0.0;
  bool _grounded = false;
  bool _onWall = false;
  bool _onCeiling = false;

  CharacterControllerScene({required super.physics});

  // ── Load ────────────────────────────────────────────────────────────────────
  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    _inputCtrl = CharControllerKeyboardInput(this);
    inputController = _inputCtrl;

    M3AppEngine.backgroundColor = Vector3(0.06, 0.08, 0.18);
    camera.setEuler(math.pi / 8, -math.pi / 5, 0, distance: 20);

    _buildObstacles();
    _buildCharacter();

    addBoxes(8);

    // axis gizmo
    addMesh(M3Resources.axisGizmoMesh, Vector3(0, 0, 0));
  }

  // ── Obstacles ────────────────────────────────────────────────────────────────
  void _buildObstacles() {
    // The base scene addGround() already provides a floor at z = 0.

    // Ramp — tilted around Y so it slopes in the XZ plane (~22.5°).
    final rampRb = physicsSystem.addBox(
      4,
      3,
      0.3,
      desc: M3RigidBodyDesc.fixed()
        ..position = Vector3(5, 0, 0.6)
        ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 8),
    );
    final rampEntity = addMesh(_rampMesh, Vector3(5, 0, 0.6));
    rampEntity.color = Colors.orange;
    physicsSystem.attachEntity(rampEntity, rampRb);

    // Step ladder
    for (int i = 0; i < 8; i++) {
      final pos = Vector3(-6, 6 - 2.0 * i, 0.15 + i * 0.3);
      final step1Rb = physicsSystem.addBox(1.5, 1.5, 0.15, desc: M3RigidBodyDesc.fixed()..position = pos);
      final step1 = addMesh(_boxMesh, pos);
      step1.color = Colors.lightBlue;
      physicsSystem.attachEntity(step1, step1Rb);
    }
  }

  // ── Character ────────────────────────────────────────────────────────────────
  void _buildCharacter() {
    // Create a kinematic body directly on the rapier world so we get back a
    // rapier.RigidBody reference needed by the character controller.
    _characterBody = world.createRigidBody(RigidBodyDesc.kinematicPositionBased()..position.setValues(0, 2, 1.5));

    // Capsule collider: half-height 0.3 m, radius 0.25 m
    final colDesc = ColliderDesc.capsuleZ(halfHeight: 0.3, radius: 0.25);
    colDesc.density = 6.0;
    _characterCollider = world.createCollider(_characterBody, colDesc);

    // Visual mesh — updated manually in update() since we bypassed attachEntity.
    _characterEntity = addMesh(_capsuleMesh, Vector3(0, 2, 1.5));
    _characterEntity.color = Colors.red;

    // Character controller
    _ctrl = world.createCharacterController(_characterBody, _characterCollider, offset: 0.01);

    // Z-up configuration
    _ctrl.upAxis = Vector3(0, 0, 1);
    _ctrl.maxSlopeAngle = math.pi / 4; // 45°
    _ctrl.minSlopeAngle = math.pi / 20; // 9°
    _ctrl.snapToGround = 0.3;
    _ctrl.setAutoStep(maxHeight: 0.35, minWidth: 0.1, includeDynamicBodies: false);
  }

  void addBoxes(int count) {
    for (int i = 0; i < count; i++) {
      for (int j = 0; j < count; j++) {
        final pos = Vector3((i - count * 0.5) * 2, j * 2 - 5, 5);
        // cube
        final rb = physicsSystem.addBox(0.5, 0.5, 0.5, desc: M3RigidBodyDesc.dynamic()..position = pos);
        // final rb = physicsSystem.addSphere(0.5, M3RigidBodyDesc.dynamic()..position = pos);
        final box = addMesh(M3Mesh(M3Resources.unitCube), pos);
        box.color = Vector4(1.0, 1.0, 0.3, 1);
        physicsSystem.attachEntity(box, rb);

        if (rb is M3RapierRigidBody) {
          for (final c in rb.colliders) {
            c.restitution = 0.6;
            c.density = 0.1;
            c.friction = 0.05;
          }
        }
      }
    }
  }

  // ── Update ───────────────────────────────────────────────────────────────────
  @override
  void update(double delta) {
    super.update(delta);

    final dt = delta.clamp(0.0, 0.05);

    final desiredMovement = moveCtrl;

    final result = _ctrl.move(desiredMovement, dt);
    _grounded = result.isGrounded;
    _onWall = result.isOnWall;
    _onCeiling = result.isOnCeiling;

    _characterEntity.position = _characterBody.position;
  }

  void jump() {
    if (_grounded) {
      _grounded = false;
      _verticalVelocity = CharacterControllerScene._jumpSpeed;

      final handle = world.groundBody.handle;
      debugPrint('RapierWorld: groundHandle: $handle');
    }
  }

  @override
  fm.Widget buildUI(fm.BuildContext context) {
    final joystickCenter = _inputCtrl._joystickCenter;
    final joystickDelta = _inputCtrl._joystickDelta;
    final isTouched = _inputCtrl._joystickTouchId != null;

    final children = <fm.Widget>[];

    // Virtual Joystick indicator
    if (isTouched && joystickCenter != null) {
      final knobOffset = joystickDelta * CharControllerKeyboardInput._joystickRadius;
      final radius = CharControllerKeyboardInput._joystickRadius;
      children.add(
        fm.Positioned(
          left: joystickCenter.dx - radius,
          top: joystickCenter.dy - radius,
          child: fm.IgnorePointer(
            child: _buildJoystickCircle(isTouched: true, knobOffset: knobOffset, radius: radius),
          ),
        ),
      );
    }

    // Jump button on the right center position
    children.add(
      fm.Align(
        alignment: fm.Alignment.centerRight,
        child: fm.Padding(
          padding: const fm.EdgeInsets.only(right: 24.0),
          child: fm.Material(
            color: fm.Colors.transparent,
            child: fm.InkWell(
              borderRadius: fm.BorderRadius.circular(32),
              onTap: jump,
              child: fm.Container(
                width: 64,
                height: 64,
                decoration: fm.BoxDecoration(
                  shape: fm.BoxShape.circle,
                  color: fm.Colors.blueAccent.withValues(alpha: 0.7),
                  border: fm.Border.all(color: fm.Colors.white, width: 2),
                  boxShadow: const [fm.BoxShadow(color: fm.Colors.black38, blurRadius: 6, spreadRadius: 1)],
                ),
                child: const fm.Icon(fm.Icons.arrow_upward, color: fm.Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ),
    );

    return fm.Stack(children: children);
  }

  fm.Widget _buildJoystickCircle({required bool isTouched, required fm.Offset knobOffset, required double radius}) {
    return fm.Opacity(
      opacity: isTouched ? 0.85 : 0.45,
      child: fm.Container(
        width: radius * 2,
        height: radius * 2,
        decoration: fm.BoxDecoration(
          shape: fm.BoxShape.circle,
          color: fm.Colors.black.withValues(alpha: 0.35),
          border: fm.Border.all(color: fm.Colors.white70, width: 2),
        ),
        child: fm.Center(
          child: fm.Transform.translate(
            offset: knobOffset,
            child: fm.Container(
              width: 44,
              height: 44,
              decoration: fm.BoxDecoration(
                shape: fm.BoxShape.circle,
                color: isTouched ? fm.Colors.lightBlueAccent : fm.Colors.white,
                boxShadow: const [fm.BoxShadow(color: fm.Colors.black26, blurRadius: 4, spreadRadius: 1)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}

class CharControllerKeyboardInput extends M3InputController {
  final CharacterControllerScene scene;
  late final M3CameraOrbitController _cameraOrbitCtrl;

  CharControllerKeyboardInput(this.scene) {
    _cameraOrbitCtrl = M3CameraOrbitController(scene.camera);
  }

  @override
  void onKeyDown(KeyDownEvent e) {
    M3Log.d('Character', 'KeyDown: ${e.logicalKey}');
    if (e.logicalKey == LogicalKeyboardKey.keyX) {
      scene.jump();
    }
  }

  @override
  void onKeyUp(KeyUpEvent e) {
    M3Log.d('Character', 'KeyUp: ${e.logicalKey}');
  }

  @override
  void onKeyRepeat(PhysicalKeyboardKey key) {
    _cameraOrbitCtrl.onKeyRepeat(key);
  }

  @override
  void onScroll(double scrollDelta) {
    _cameraOrbitCtrl.onScroll(scrollDelta);
  }

  // Virtual joystick touch state
  int? _joystickTouchId;
  Offset? _joystickCenter;
  Offset _joystickDelta = Offset.zero;
  static const double _joystickRadius = 60.0;

  @override
  void onTouchDown(M3Touch touch) {
    final screenW = scene.camera.viewportW.toDouble();
    final isLeftSide = touch.x < (screenW > 0 ? screenW * 0.25 : 120);

    // If joystick isn't active and touch is on the left half of the screen
    if (_joystickTouchId == null && isLeftSide) {
      _joystickTouchId = touch.id;
      _joystickCenter = Offset(touch.x, touch.y);
      _joystickDelta = Offset.zero;
      M3AppEngine.instance.refresh();
    } else {
      _cameraOrbitCtrl.onTouchDown(touch);
    }
  }

  @override
  void onTouchMove(M3Touch touch) {
    if (touch.id == _joystickTouchId && _joystickCenter != null) {
      final pos = Offset(touch.x, touch.y);
      final diff = pos - _joystickCenter!;
      if (diff.distance > _joystickRadius) {
        _joystickDelta = diff / diff.distance;
      } else {
        _joystickDelta = diff / _joystickRadius;
      }
      M3AppEngine.instance.refresh();
    } else {
      _cameraOrbitCtrl.onTouchMove(touch);
    }
  }

  @override
  void onTouchUp(M3Touch touch) {
    if (touch.id == _joystickTouchId) {
      _joystickTouchId = null;
      _joystickCenter = null;
      _joystickDelta = Offset.zero;
      M3AppEngine.instance.refresh();
    } else {
      _cameraOrbitCtrl.onTouchUp(touch);
    }
  }

  @override
  void update(double dt) {
    final keyboard = M3AppEngine.instance.keyboard;
    Vector3 moveDelta = Vector3.zero();
    final speed = 20.0 * dt; // move speed units per second

    // Gravity (-Z)
    if (scene._grounded) {
      scene._verticalVelocity = 0.0;
    } else {
      scene._verticalVelocity += CharacterControllerScene._gravity * dt;
    }
    // Cancel upward velocity if we hit a ceiling
    if (scene._onCeiling && scene._verticalVelocity > 0) scene._verticalVelocity = 0;

    if (keyboard.isPressed(LogicalKeyboardKey.keyW) || keyboard.isPressed(LogicalKeyboardKey.arrowUp)) {
      moveDelta += Vector3(0, speed, 0);
    }
    if (keyboard.isPressed(LogicalKeyboardKey.keyS) || keyboard.isPressed(LogicalKeyboardKey.arrowDown)) {
      moveDelta += Vector3(0, -speed, 0);
    }
    if (keyboard.isPressed(LogicalKeyboardKey.keyA) || keyboard.isPressed(LogicalKeyboardKey.arrowLeft)) {
      moveDelta += Vector3(-speed, 0, 0);
    }
    if (keyboard.isPressed(LogicalKeyboardKey.keyD) || keyboard.isPressed(LogicalKeyboardKey.arrowRight)) {
      moveDelta += Vector3(speed, 0, 0);
    }

    // Add joystick input (X -> +X right/-X left, Y -> -Y up in screen coords maps to +Y forward)
    if (_joystickDelta != Offset.zero) {
      moveDelta += Vector3(_joystickDelta.dx * speed, -_joystickDelta.dy * speed, 0);
    }

    moveDelta.z = scene._verticalVelocity;
    scene.moveCtrl.setFrom(moveDelta);
  }
}
