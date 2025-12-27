import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// Macbear3D engine
import '../../macbear_3d.dart' hide Colors;
import '../input/keyboard.dart';
import '../physics/physics_engine.dart';

class M3AppEngine {
  static final M3AppEngine instance = M3AppEngine._internal();

  String version = "macbear3d-lib v0.1.0 powered by ANGLE ";
  final FlutterAngle _angle = FlutterAngle();
  late FlutterAngleTexture _sourceTexture; // main framebuffer
  bool _didContextInit = false; // context initialized

  final M3RenderEngine renderEngine = M3RenderEngine();
  int initTick = 0;
  int _frameCounter = 0;

  final M3TouchManager touchManager = M3TouchManager();
  final M3KeyboardManager keyboard = M3KeyboardManager();

  // update elspsed
  final Stopwatch _stopwatch = Stopwatch();

  late Ticker ticker;
  bool _updating = false;
  int _totalTime = 0;
  int _iterationCount = 60;
  int _framesOver = 0;

  // FPS counter
  int _fpsFrameCount = 0;
  int _fpsLastTime = 0;
  double _currentFps = 0.0;
  double get fps => _currentFps;

  // app windows size
  int appWidth = 64;
  int appHeight = 64;
  double devicePixelRatio = 1.0; // Device Pixel Ratio

  // inset edges
  int edgeInsetLeft = 0;
  int edgeInsetTop = 0;
  int edgeInsetRight = 0;
  int edgeInsetBottom = 0;

  // scene
  M3Scene? activeScene;

  // physics
  final physicsEngine = M3PhysicsEngine();

  // This named constructor is the "real" constructor
  // It'll be called exactly once, by the static property assignment above
  // it's also private, so it can only be called in this class
  M3AppEngine._internal();

  Future<void> initApp({int width = 100, int height = 100, double dpr = 1.0}) async {
    if (_didContextInit) {
      debugPrint("--- initApp: context already initialized ---");
      return;
    }
    initTick = DateTime.now().millisecondsSinceEpoch;

    debugPrint("--- Macbear: $version ---");
    debugPrint("--- initApp: ($width x $height)  dpr: $dpr ---");

    initKeyboard();

    // init angle: ANGLE by Google
    await _angle.init();
    final options = AngleOptions(width: width, height: height, dpr: dpr, useSurfaceProducer: true);
    _sourceTexture = await _angle.createTexture(options);

    // init render engine
    renderEngine.gl = _sourceTexture.getContext();
    debugPrint("--- ANGLE context ready ---");
    appWidth = width;
    appHeight = height;
    devicePixelRatio = dpr;

    // await _onSize(width, height, dpr, isResize: false);
    await renderEngine.initProgram();
    renderEngine.setViewport(width, height, dpr);

    debugPrint("*** initApp done ***");
    _didContextInit = true;
  }

  void initKeyboard() {
    keyboard.start();
    keyboard.onKeyDown = (e) {
      debugPrint("KeyDown: ${e.logicalKey}");
      activeScene?.inputController?.onKeyDown(e);
    };

    keyboard.onKeyRepeat = (key) {
      debugPrint("Repeat: ${key.debugName}");
      activeScene?.inputController?.onKeyRepeat(key);
    };

    keyboard.onKeyUp = (e) {
      debugPrint("KeyUp: ${e}");
      activeScene?.inputController?.onKeyUp(e);
    };

    keyboard.onActionDown = (action) {
      debugPrint("Action: $action");
    };
  }

  // dispose app
  void dispose() {
    // for keyboard
    keyboard.stop();

    // for ticker
    ticker.stop(canceled: true);
    ticker.dispose();

    // for render engine
    renderEngine.dispose();

    // for angle
    _angle.deleteTexture(_sourceTexture);
    _angle.dispose([_sourceTexture]);
  }

  Future<void> setScene(M3Scene scene) async {
    pause();

    // free original scene
    if (M3AppEngine.instance.activeScene != null) {
      M3AppEngine.instance.activeScene!.dispose();
      M3AppEngine.instance.activeScene = null;
    }

    await scene.load();
    activeScene = scene;
    renderEngine.setViewport(appWidth, appHeight, devicePixelRatio);

    resume();
  }

  void pause() {
    if (!_didContextInit) {
      return;
    }
    if (ticker.isActive) {
      ticker.stop();
    }
    debugPrint("--- app pause ---");
  }

  void resume() {
    if (!_didContextInit) {
      return;
    }
    if (!ticker.isActive) {
      ticker.start();
    }
    debugPrint("+++ app resume +++");
  }

  double _getTime() => DateTime.now().millisecondsSinceEpoch / 1000.0;

  Widget getAppWidget() {
    debugPrint("--- getAppWidget ---");
    if (!_didContextInit) {
      return Container(
        color: Colors.yellow,
        child: Center(child: Text('Prepare ANGLE...')),
      );
    }

    Widget textureSurface = kIsWeb
        ? HtmlElementView(viewType: _sourceTexture.textureId.toString())
        : _didContextInit
        ? _flipY(Texture(textureId: _sourceTexture.textureId))
        : Container(
            color: Colors.lightGreen.shade600,
            child: Center(child: Text('Macbear3D loading...')),
          );

    return Listener(
      onPointerDown: (event) {
        M3TouchPoint point = M3TouchPoint(
          Vector2(event.localPosition.dx, event.localPosition.dy),
          event.buttons,
          _getTime(),
        );
        debugPrint("Pointer(${event.pointer}: down at ${point.toString()}");
        final touch = touchManager.onTouchDown(event.pointer, point);
        activeScene?.inputController?.onTouchDown(touch);
      },
      onPointerMove: (event) {
        M3TouchPoint point = M3TouchPoint(
          Vector2(event.localPosition.dx, event.localPosition.dy),
          event.buttons,
          _getTime(),
        );
        // debugPrint("Pointer(${event.pointer}: move at ${point.toString()}");
        final touch = touchManager.onTouchMove(event.pointer, point);
        if (touch != null) {
          activeScene?.inputController?.onTouchMove(touch);
        }
      },
      onPointerUp: (event) {
        M3TouchPoint point = M3TouchPoint(
          Vector2(event.localPosition.dx, event.localPosition.dy),
          event.buttons,
          _getTime(),
        );
        debugPrint("Pointer(${event.pointer}: up at ${point.toString()}");
        final touch = touchManager.onTouchUp(event.pointer, point);
        if (touch != null) {
          activeScene?.inputController?.onTouchUp(touch);
        }
        touchManager.clearInactive();
      },
      onPointerCancel: (event) {
        final Vector2 posTouch = Vector2(event.localPosition.dx, event.localPosition.dy);
        debugPrint("Pointer(${event.pointer}) cancel at: $posTouch");
        touchManager.touches.remove(event.pointer);
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          debugPrint("Pointer(${event.pointer}) scroll: ${event.scrollDelta.dy}");
          activeScene?.inputController?.onScroll(event.scrollDelta.dy);
        }
      },
      child: textureSurface,
    );
  }

  Future<bool> onResize(int width, int height, double dpr) async {
    debugPrint("--- onResize: ($width x $height) dpr: $dpr (init=$_didContextInit) ---");
    if (!_didContextInit) {
      return false;
    }

    if (width == appWidth && height == appHeight && dpr == devicePixelRatio) {
      debugPrint("*** onResize: ignore ***");
      return false;
    }

    // so resize it
    final options = AngleOptions(width: width, height: height, dpr: dpr, useSurfaceProducer: true);
    if (Platform.isAndroid) {
      await _angle.deleteTexture(_sourceTexture);
      _sourceTexture = await _angle.createTexture(options);
      // M3RenderEngine.gl = _sourceTexture.getContext();
    } else {
      await _angle.resize(_sourceTexture, options);
    }

    appWidth = width;
    appHeight = height;
    devicePixelRatio = dpr;

    renderEngine.setViewport(width, height, dpr);

    // touch manager reset
    touchManager.clearAll();
    return true;
  }

  // application update and render
  Future<void> updateRender(Duration elapsed) async {
    if (!_updating && _didContextInit) {
      _updating = true;
      _stopwatch.reset();
      _stopwatch.start();

      // application update then render
      _update(elapsed);
      await _render();

      _stopwatch.stop();
      _totalTime += _stopwatch.elapsedMilliseconds;
      if (_stopwatch.elapsedMilliseconds > 16) {
        _framesOver++;
      }
      if (--_iterationCount == 0) {
        // debugPrint('Time: ${totalTime / 60} - Framesover $framesOver');
        _totalTime = 0;
        _iterationCount = 60;
        _framesOver = 0;
      }

      // FPS calculation
      _fpsFrameCount++;
      int now = DateTime.now().millisecondsSinceEpoch;
      if (now - _fpsLastTime >= 1000) {
        _currentFps = _fpsFrameCount * 1000.0 / (now - _fpsLastTime);
        _fpsLastTime = now;
        _fpsFrameCount = 0;
      }

      _updating = false;
    } else {
      debugPrint('Too slow');
    }
  }

  // application update
  void _update(Duration elapsed) {
    // debugPrint('update= $elapsed');
    if (activeScene != null) {
      double sec = elapsed.inMilliseconds / 1000.0;
      physicsEngine.update(sec);
      activeScene!.update(elapsed);
    }
  }

  // application render
  Future<void> _render() async {
    _sourceTexture.activate();

    int current = DateTime.now().millisecondsSinceEpoch;
    double blue = sin((current - initTick) / 500) * 0.3;

    final gl = renderEngine.gl;
    gl.clearColor(0, 0.3, blue, 1.0);
    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);

    // render active scene
    if (activeScene != null) {
      renderEngine.renderScene(activeScene!);
    }
    // render 2D: UI, text etc.
    renderEngine.render2D();

    gl.flush();
    // gl.finish();

    // increase counter
    _frameCounter++;

    await _sourceTexture.signalNewFrameAvailable();
  }

  Widget _flipY(Widget widgetSrc) {
    // Flip Y only for Metal/iOS
    if (Platform.isIOS || Platform.isMacOS) {
      return Transform.scale(scaleY: -1.0, child: widgetSrc);
    } else {
      return widgetSrc;
    }
  }
}
