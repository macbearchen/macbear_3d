import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

// Macbear3D engine
import '../m3_internal.dart' hide Colors;
import 'ktx_info.dart';
import '../util/video/video_helper.dart';
import '../video_bridge/video_bridge.dart';

// parts for texture
part 'text_texture.dart';
part 'external_texture.dart';

/// WebGL texture wrapper supporting 2D and cubemap textures.
///
/// Provides methods for loading from assets, creating solid colors, and checkerboard patterns.
class M3Texture {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  // default white pixel 1x1
  static final List<int> _cubeMapFaceTargets = [
    WebGL.TEXTURE_CUBE_MAP_POSITIVE_X,
    WebGL.TEXTURE_CUBE_MAP_NEGATIVE_X,
    WebGL.TEXTURE_CUBE_MAP_POSITIVE_Y,
    WebGL.TEXTURE_CUBE_MAP_NEGATIVE_Y,
    WebGL.TEXTURE_CUBE_MAP_POSITIVE_Z,
    WebGL.TEXTURE_CUBE_MAP_NEGATIVE_Z,
  ];

  String name = "noname";
  late WebGLTexture _texture;
  WebGLTexture get glTexture => _texture;
  final bool isCubemap; // true: for cubemap, false: for 2D
  final bool generateMipmaps;
  int texW = 32;
  int texH = 32;
  int get target {
    if (isCubemap) return WebGL.TEXTURE_CUBE_MAP;
    return WebGL.TEXTURE_2D;
  }

  M3Texture({this.isCubemap = false, this.generateMipmaps = true}) {
    _texture = gl.createTexture();

    setParameters();
  }

  void setParameters() {
    final int warpMode = isCubemap ? WebGL.CLAMP_TO_EDGE : WebGL.REPEAT;

    bind();
    gl.texParameteri(target, WebGL.TEXTURE_WRAP_S, warpMode);
    gl.texParameteri(target, WebGL.TEXTURE_WRAP_T, warpMode);
    if (isCubemap) {
      gl.texParameteri(target, WebGL.TEXTURE_WRAP_R, warpMode);
    }

    final minFilter = generateMipmaps ? WebGL.LINEAR_MIPMAP_LINEAR : WebGL.LINEAR;
    gl.texParameteri(target, WebGL.TEXTURE_MIN_FILTER, minFilter); // NEAREST, GL_LINEAR_MIPMAP_LINEAR
    gl.texParameteri(target, WebGL.TEXTURE_MAG_FILTER, WebGL.LINEAR); // NEAREST
    gl.pixelStorei(WebGL.UNPACK_ALIGNMENT, 1);
  }

  void dispose() {
    gl.deleteTexture(_texture);
  }

  void bind() {
    gl.bindTexture(target, _texture);
  }

  static final WebGLTexture _textureNone = WebGLTexture(kIsWeb ? null : 0);
  void unbind() {
    return;
    // ignore: dead_code
    gl.bindTexture(target, _textureNone); // seems not necessary
  }

  M3Texture.fromWebGLTexture(this._texture, {this.texW = 1024, this.texH = 1024, this.generateMipmaps = false})
    : isCubemap = false;

  @override
  String toString() {
    return 'Texture${isCubemap ? 'Cubemap' : '2D'} ($texW x $texH): "$name"';
  }

  static M3Texture createSolidColor(Vector4 color) {
    M3Texture tex = M3Texture();
    tex.name = "solid_color";
    tex._initColorPixel(color);
    return tex;
  }

  static M3Texture createSolidColorCube(Vector4 color) {
    M3Texture tex = M3Texture(isCubemap: true);
    tex.name = "solid_color_cube";
    for (int i = 0; i < 6; i++) {
      tex._initColorPixel(color, faceTarget: _cubeMapFaceTargets[i]);
    }
    return tex;
  }

  /// Create a default IBL cubemap with simple sky/ground gradient colors.
  static M3Texture createDefaultIBLCube() {
    M3Texture tex = M3Texture(isCubemap: true);
    tex.name = "default_ibl_cube";

    final colorSky = Vector4(0.5, 0.7, 0.9, 1.0); // Light bluish sky
    final colorGround = Vector4(0.2, 0.2, 0.2, 1.0); // Dark neutral gray ground
    final colorHorizon = Vector4(0.5, 0.5, 0.5, 1.0); // Neutral gray horizon

    // Faces: +X, -X, +Y, -Y, +Z, -Z
    tex._initColorPixel(colorHorizon, faceTarget: _cubeMapFaceTargets[0]); // Right
    tex._initColorPixel(colorHorizon, faceTarget: _cubeMapFaceTargets[1]); // Left
    tex._initColorPixel(colorSky, faceTarget: _cubeMapFaceTargets[2]); // Top (+Y)
    tex._initColorPixel(colorGround, faceTarget: _cubeMapFaceTargets[3]); // Bottom (-Y)
    tex._initColorPixel(colorHorizon, faceTarget: _cubeMapFaceTargets[4]); // Back
    tex._initColorPixel(colorHorizon, faceTarget: _cubeMapFaceTargets[5]); // Front

    return tex;
  }

  static M3Texture createEmptyCubemap(int size) {
    M3Texture tex = M3Texture(isCubemap: true, generateMipmaps: true);
    tex.name = "empty_cubemap_${size}x$size";
    tex.texW = size;
    tex.texH = size;
    for (int i = 0; i < 6; i++) {
      tex._initEmptyTarget(faceTarget: _cubeMapFaceTargets[i]);
    }
    return tex;
  }

  void _initColorPixel(Vector4 color, {int faceTarget = WebGL.TEXTURE_2D}) {
    texW = 1;
    texH = 1;

    // Fill the texture with a 1x1 white pixel.
    final pixel = Uint8List.fromList([
      (color.r * 255).round().clamp(0, 255),
      (color.g * 255).round().clamp(0, 255),
      (color.b * 255).round().clamp(0, 255),
      (color.a * 255).round().clamp(0, 255),
    ]);
    gl.texImage2D(faceTarget, 0, WebGL.RGBA, 1, 1, 0, WebGL.RGBA, WebGL.UNSIGNED_BYTE, pixel);
    if (generateMipmaps && !isCubemap) gl.generateMipmap(target);
  }

  void _initEmptyTarget({int faceTarget = WebGL.TEXTURE_2D}) {
    bind();
    gl.texImage2D(faceTarget, 0, WebGL.RGBA, texW, texH, 0, WebGL.RGBA, WebGL.UNSIGNED_BYTE, null);
  }

  void _initCheckerboard(int gridCount, Vector4 lightColor, Vector4 darkColor, {int faceTarget = WebGL.TEXTURE_2D}) {
    texW = gridCount;
    texH = gridCount;

    gl.texParameteri(target, WebGL.TEXTURE_MIN_FILTER, WebGL.NEAREST); // NEAREST, GL_LINEAR_MIPMAP_LINEAR
    gl.texParameteri(target, WebGL.TEXTURE_MAG_FILTER, WebGL.NEAREST); // NEAREST

    // Fill the texture with a checkerboard pattern.
    final lightPixel = Uint8List.fromList([
      (lightColor.r * 255).round().clamp(0, 255),
      (lightColor.g * 255).round().clamp(0, 255),
      (lightColor.b * 255).round().clamp(0, 255),
      (lightColor.a * 255).round().clamp(0, 255),
    ]);
    final darkPixel = Uint8List.fromList([
      (darkColor.r * 255).round().clamp(0, 255),
      (darkColor.g * 255).round().clamp(0, 255),
      (darkColor.b * 255).round().clamp(0, 255),
      (darkColor.a * 255).round().clamp(0, 255),
    ]);

    final data = Uint8List.fromList(List.generate(gridCount * gridCount * 4, (index) => 0));
    for (int i = 0; i < gridCount; i++) {
      for (int j = 0; j < gridCount; j++) {
        final pixel = (i + j) % 2 == 0 ? lightPixel : darkPixel;
        final index = (i * gridCount + j) * 4;
        data[index] = pixel[0];
        data[index + 1] = pixel[1];
        data[index + 2] = pixel[2];
        data[index + 3] = pixel[3];
      }
    }

    gl.texImage2D(faceTarget, 0, WebGL.RGBA, gridCount, gridCount, 0, WebGL.RGBA, WebGL.UNSIGNED_BYTE, data);
    if (generateMipmaps && !isCubemap) gl.generateMipmap(target);
  }

  static M3Texture createCheckerboard({
    int size = 4,
    Vector4? lightColor,
    Vector4? darkColor,
    int faceTarget = WebGL.TEXTURE_2D,
  }) {
    M3Texture tex = M3Texture();
    lightColor ??= Vector4(0.8, 0.8, 0.8, 1);
    darkColor ??= Vector4(0.5, 0.5, 0.5, 1);
    tex.name = 'checkerboard';
    tex._initCheckerboard(size, lightColor, darkColor, faceTarget: faceTarget);
    return tex;
  }

  static M3Texture createSampleCubemap({int gridCount = 8}) {
    M3Texture tex = M3Texture(isCubemap: true);
    tex.name = 'sample_cubemap';

    List<Vector4> colors = [
      Vector4(0.8, 0.3, 0.3, 1),
      Vector4(0.6, 0.4, 0.4, 1),
      Vector4(0.3, 0.8, 0.3, 1),
      Vector4(0.4, 0.6, 0.4, 1),
      Vector4(0.3, 0.3, 0.8, 1),
      Vector4(0.4, 0.4, 0.6, 1),
    ];

    for (int i = 0; i < 6; i++) {
      tex._initCheckerboard(
        gridCount,
        colors[i],
        i % 2 == 0 ? Vector4(0.6, 0.6, 0.6, 1) : Vector4(0.5, 0.5, 0.5, 1),
        faceTarget: _cubeMapFaceTargets[i],
      );
    }
    return tex;
  }

  static Future<M3Texture> loadTexture(String url) async {
    M3Texture tex = M3Texture();
    tex.name = url;
    await tex._loadTarget(url);

    debugPrint(tex.toString());
    return tex;
  }

  static Future<M3Texture> loadCubemap(
    String urlPosX,
    String urlNegX,
    String urlPosY,
    String urlNegY,
    String urlPosZ,
    String urlNegZ,
  ) async {
    M3Texture tex = M3Texture(isCubemap: true);
    List<String> urls = [urlPosX, urlNegX, urlPosY, urlNegY, urlPosZ, urlNegZ];

    // 6 faces for cubemap
    for (int i = 0; i < 6; i++) {
      await tex._loadTarget(urls[i], faceTarget: _cubeMapFaceTargets[i]);
      debugPrint(tex.toString());
    }
    if (tex.generateMipmaps) {
      tex.bind();
      tex.gl.generateMipmap(WebGL.TEXTURE_CUBE_MAP);
    }
    tex.unbind();
    return tex;
  }

  static Future<M3Texture> createFromBytes(Uint8List bytes, String name) async {
    M3Texture tex = M3Texture();
    tex.name = name;

    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    final img = frameInfo.image;

    await tex._loadTargetFromImage(img);
    debugPrint(tex.toString());
    return tex;
  }

  Future<void> _loadTarget(String url, {int faceTarget = WebGL.TEXTURE_2D}) async {
    final filename = 'assets/$url';
    if (!await M3Utility.isAssetExists(filename)) {
      debugPrint('*** ERROR assets: $filename');
      _initCheckerboard(8, Vector4(0.8, 0.3, 0.3, 1), Vector4(0.7, 0.7, 0.3, 1), faceTarget: faceTarget);
      return;
    }

    final lowerName = filename.toLowerCase();
    name = filename;

    if (lowerName.endsWith('.ktx') || lowerName.endsWith('.ktx2') || lowerName.endsWith('.astc')) {
      // KTX compressed texture: ASTC
      final ktxInfo = await KtxInfo.parseKtx(filename);
      name = filename;
      texW = ktxInfo.width;
      texH = ktxInfo.height;
      Uint8List byteData = Uint8List.fromList(ktxInfo.texData);

      final pixelFormat = ktxInfo.glFormat;
      bind();
      gl.compressedTexImage2D(faceTarget, 0, pixelFormat, texW, texH, 0, byteData);
      if (generateMipmaps && !isCubemap) gl.generateMipmap(target);
      // } else if (lowerName.endsWith('.pvr')) {
      // PVR compressed texture
    } else {
      ui.Image img = await gl.loadImageFromAsset(filename);
      await _loadTargetFromImage(img, faceTarget: faceTarget);
    }
  }

  Future<void> _loadTargetFromImage(ui.Image image, {int faceTarget = WebGL.TEXTURE_2D}) async {
    texW = image.width;
    texH = image.height;

    final pixelFormat = WebGL.RGBA;
    // Macbear note: texImage2DfromImage not working on web
    // await gl.texImage2DfromImage(
    //   faceTarget,
    //   image,
    //   format: pixelFormat,
    //   internalformat: pixelFormat,
    //   type: WebGL.UNSIGNED_BYTE,
    // );

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      debugPrint('*** ERROR: M3Texture.toByteData returned null');
      return;
    }
    final pixels = Uint8List.fromList(byteData.buffer.asUint8List());

    bind();
    gl.texImage2D(faceTarget, 0, pixelFormat, texW, texH, 0, pixelFormat, WebGL.UNSIGNED_BYTE, pixels);
    if (generateMipmaps && !isCubemap) gl.generateMipmap(target);
  }

  static Future<M3Texture> createWoodTexture({int size = 512}) async {
    M3Texture tex = M3Texture();
    final img = await _generateWoodImage(size: size);
    await tex._loadTargetFromImage(img);
    return tex;
  }

  // 生成高品質木紋紋理 (Advanced Procedural Wood)
  static Future<ui.Image> _generateWoodImage({int size = 512}) async {
    final Uint8List pixels = Uint8List(size * size * 4);

    // 核心噪點函數 (Deterministic Hash)
    double noise(double x, double y) {
      int n = (x.toInt() * 12345 + y.toInt() * 67890);
      n = (n << 13) ^ n;
      return (1.0 - ((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) / 1073741824.0);
    }

    // 平滑插值噪點
    double smoothNoise(double x, double y) {
      double corners = (noise(x - 1, y - 1) + noise(x + 1, y - 1) + noise(x - 1, y + 1) + noise(x + 1, y + 1)) / 16;
      double sides = (noise(x - 1, y) + noise(x + 1, y) + noise(x, y - 1) + noise(x, y + 1)) / 8;
      double center = noise(x, y) / 4;
      return corners + sides + center;
    }

    // 擾動 (Turbulence)
    double getTurbulence(double x, double y, double size) {
      double value = 0.0, initialSize = size;
      while (size >= 1) {
        value += smoothNoise(x / size, y / size) * size;
        size /= 2;
      }
      return (128.0 * value / initialSize);
    }

    // Wood Colors (更好的木質感配色)
    final colBase = [160, 110, 60]; // 中等木色
    final colDark = [70, 35, 10]; // 深色紋路
    final colLight = [200, 160, 110]; // 亮部

    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        double nx = x.toDouble();
        double ny = y.toDouble();

        // 1. 取得擾動值
        double turb = getTurbulence(nx, ny, 64.0);

        // 2. 核心紋路邏輯：歪斜的 Sine 波
        // 模擬木材縱向生長，增加橫向的隨機偏移
        double dist = (nx * 0.1) + (ny * 0.02) + (turb * 0.1);
        double val = (sin(dist * pi * 0.2) + 1.0) / 2.0;

        // 3. 調整曲線讓紋路更銳利一點
        val = pow(val, 0.5).toDouble();

        // 4. 三色插值
        double r, g, b;
        if (val < 0.5) {
          double t = val * 2.0;
          r = colDark[0] * (1 - t) + colBase[0] * t;
          g = colDark[1] * (1 - t) + colBase[1] * t;
          b = colDark[2] * (1 - t) + colBase[2] * t;
        } else {
          double t = (val - 0.5) * 2.0;
          r = colBase[0] * (1 - t) + colLight[0] * t;
          g = colBase[1] * (1 - t) + colLight[1] * t;
          b = colBase[2] * (1 - t) + colLight[2] * t;
        }

        // 5. 疊加垂直導管 (Pores) 與表面細紋
        double pores = smoothNoise(nx * 5, ny * 0.2);
        if (pores > 0.7) {
          double pVal = (pores - 0.7) * 2.0;
          r *= (1.0 - pVal * 0.3);
          g *= (1.0 - pVal * 0.3);
          b *= (1.0 - pVal * 0.3);
        }

        // 6. 微觀隨機噪點
        double grain = 1.0 + (noise(nx, ny) * 0.03);
        r *= grain;
        g *= grain;
        b *= grain;

        final int index = (y * size + x) * 4;
        pixels[index] = r.toInt().clamp(0, 255);
        pixels[index + 1] = g.toInt().clamp(0, 255);
        pixels[index + 2] = b.toInt().clamp(0, 255);
        pixels[index + 3] = 255;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, size, size, ui.PixelFormat.rgba8888, (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }
}
