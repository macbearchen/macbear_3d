// Macbear3D engine
import '../m3_internal.dart';

class M3RenderTarget {
  late M3Framebuffer _framebuffer;

  /// get reflection pixel size
  int get width => texture.texW;
  int get height => texture.texH;
  final bool _useMipmaps;
  final int _colorFormat;
  M3Texture get texture => _framebuffer.colorTexture;
  double _renderScale;

  final bool hasDepth;

  M3RenderTarget(
    int width,
    int height, {
    required bool mipmaps,
    int format = WebGL.RGBA8,
    double renderScale = 0.5,
    this.hasDepth = true,
  }) : _useMipmaps = mipmaps,
       _colorFormat = format,
       _renderScale = renderScale {
    assert(renderScale > 0 && renderScale <= 1.0);
    width = max((width * _renderScale).toInt(), 2);
    height = max((height * _renderScale).toInt(), 2);
    _framebuffer = M3Framebuffer(width, height)..createColorTexture(mipmaps: mipmaps, format: _colorFormat);
    if (hasDepth) {
      _framebuffer.createDepthRenderbuffer();
    }
  }

  void setRenderScale(double scale) {
    assert(scale > 0 && scale <= 1.0);
    _renderScale = scale;

    resize(M3AppEngine.instance.appWidth, M3AppEngine.instance.appHeight);
  }

  /// Resize reflection image, size is based on display size
  void resize(int width, int height) {
    width = max((width * _renderScale).toInt(), 2);
    height = max((height * _renderScale).toInt(), 2);
    if (width == this.width && height == this.height) return;

    dispose();
    _framebuffer = M3Framebuffer(width, height)..createColorTexture(mipmaps: _useMipmaps, format: _colorFormat);
    if (hasDepth) {
      _framebuffer.createDepthRenderbuffer();
    }
  }

  void bind() {
    _framebuffer.bind();
  }

  void dispose() {
    _framebuffer.dispose();
  }
}

/// render target manager
class M3RenderTargetManager {
  final Map<String, M3RenderTarget> _targets = {};

  int _viewportWidth = 0;
  int _viewportHeight = 0;

  /// 初始化或視窗 Resize 時統一更新所有 RenderTarget
  void resize(int width, int height) {
    if (_viewportWidth == width && _viewportHeight == height) return;
    _viewportWidth = width;
    _viewportHeight = height;

    // 1. Scene Target (全解析度 HDR): RGBA16F, R11F_G11F_B10F
    const sceneFormat = WebGL.RGBA16F;
    _getOrCreate('scene', width, height, mipmaps: false, hasDepth: true, format: sceneFormat);

    // 2. Mirror/Reflection/Refraction Target (0.5x 降採樣)
    _getOrCreate('mirror', width, height, mipmaps: true, hasDepth: true, renderScale: 0.5);
    _getOrCreate('reflection', width, height, mipmaps: false, hasDepth: true, renderScale: 0.5);
    _getOrCreate('refraction', width, height, mipmaps: false, hasDepth: true, renderScale: 0.5);

    // 3. Bloom Ping-Pong Targets (0.5x 降採樣, HDR)
    _getOrCreate('bloom_ping', width, height, mipmaps: false, hasDepth: false, format: sceneFormat, renderScale: 0.5);
    _getOrCreate('bloom_pong', width, height, mipmaps: false, hasDepth: false, format: sceneFormat, renderScale: 0.5);

    // 4. Post Process Target (全解析度 HDR)
    _getOrCreate('composite', width, height, mipmaps: false, hasDepth: false, format: sceneFormat);

    // 5. Post Process LDR Target (for FXAA input/output: 全解析度 RGBA8)
    _getOrCreate('ldr_post', width, height, mipmaps: false, hasDepth: false, format: WebGL.RGBA8);
    _getOrCreate('fxaa', width, height, mipmaps: false, hasDepth: false, format: WebGL.RGBA8);
  }

  M3RenderTarget get(String key) {
    final rt = _targets[key];
    assert(rt != null, 'RenderTarget $key not initialized.');
    return rt!;
  }

  void _getOrCreate(
    String key,
    int w,
    int h, {
    required bool mipmaps,
    required bool hasDepth,
    int format = WebGL.RGBA8,
    double renderScale = 1.0,
  }) {
    if (_targets.containsKey(key)) {
      _targets[key]!.resize(w, h);
    } else {
      _targets[key] = M3RenderTarget(
        w,
        h,
        mipmaps: mipmaps,
        format: format,
        hasDepth: hasDepth,
        renderScale: renderScale,
      );
    }
  }

  void dispose() {
    for (var rt in _targets.values) {
      rt.dispose();
    }
    _targets.clear();
  }
}
