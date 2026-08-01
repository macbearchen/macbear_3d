import 'dart:async';
import 'package:flutter/material.dart';

// Macbear3D engine
import '../m3_internal.dart';

class M3View extends StatefulWidget {
  const M3View({super.key});

  @override
  State<M3View> createState() => _M3ViewState();
}

class _M3ViewState extends State<M3View> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initAppEngine();
    });
  }

  Future<void> initAppEngine() async {
    // wait for context ready
    if (!context.mounted) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;

    final size = await _getValidSize(context);
    final screenW = size.width.toInt();
    final screenH = size.height.toInt();
    M3Log.i('M3View', 'initState addPostFrameCallback ($mounted) ($screenW x $screenH) dpr: $dpr');

    // ticker to update and render (owned by this view; released via unmount())
    final engine = M3AppEngine.instance;
    engine.ticker = createTicker(engine.updateRender);

    // init AppEngine (skipped internally when the engine is already initialised,
    // e.g. when this M3View is a remount of a previously torn-down view)
    await engine.initApp(width: screenW, height: screenH, dpr: dpr);

    // The view may have left the tree during the async init above; if so,
    // dispose() has already run unmount() and there is nothing to resume.
    if (!mounted) return;

    setState(() {
      engine.remount();
      engine.resume();
      M3Log.s('M3View', 'setState after initAppEngine');
    });
  }

  /// 核心邏輯：在 Android 上不斷檢查直到尺寸就緒
  Future<Size> _getValidSize(BuildContext context) async {
    Size size = MediaQuery.of(context).size;

    // 如果尺寸為 0，代表 Android Surface 尚未準備好，等待下一幀
    while (size.width == 0 || size.height == 0) {
      await Future.delayed(const Duration(milliseconds: 16));
      // 必須重新獲取最新的 MediaQuery
      if (!context.mounted) break;
      size = MediaQuery.of(context).size;
    }
    return size;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel(); // Cancel timer if active
    WidgetsBinding.instance.removeObserver(this);

    // Detach from the (singleton) engine but keep it warm for a later remount.
    // Full GL teardown is an explicit, separate call: M3AppEngine.dispose().
    M3AppEngine.instance.unmount();

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    M3Log.d('M3View', '>>> didChangeMetrics');
    final engine = M3AppEngine.instance;
    engine.pause(); // pause ticker during resize
    _debounceTimer?.cancel(); // Clear existing timer
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final mq = MediaQuery.of(context);
      final screenWidth = mq.size.width.toInt();
      final screenHeight = mq.size.height.toInt();
      final dpr = mq.devicePixelRatio;
      // context resize after delay
      await engine.onResize(screenWidth, screenHeight, dpr);

      setState(() {
        engine.resume();
        M3Log.d('M3View', '<<< setState after didChangeMetrics');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // call buildAppWidget once for init app
    final appWidget = M3AppEngine.instance.buildAppWidget();
    return appWidget;
  }
}
