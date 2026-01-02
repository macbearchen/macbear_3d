import 'dart:ui' as ui;

// Macbear3D engine
import '../../macbear_3d.dart';
import 'ktx_info.dart';

/// WebGL texture wrapper supporting 2D and cubemap textures.
///
/// Provides methods for loading from assets, creating solid colors, and checkerboard patterns.
class M3Texture {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  // default white pixel 1x1
  static final texWhite = M3Texture.createSolidColor(Vector4(1, 1, 1, 1));
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
  final bool isCubemap; // true: for cubemap, false: for 2D
  int texW = 32;
  int texH = 32;
  int get target => isCubemap ? WebGL.TEXTURE_CUBE_MAP : WebGL.TEXTURE_2D;

  M3Texture({this.isCubemap = false}) {
    _texture = gl.createTexture();
    bind();

    setParameters();
    gl.pixelStorei(WebGL.UNPACK_ALIGNMENT, 1);
  }

  void setParameters() {
    final int warpMode = isCubemap ? WebGL.CLAMP_TO_EDGE : WebGL.REPEAT;
    gl.texParameteri(target, WebGL.TEXTURE_WRAP_S, warpMode);
    gl.texParameteri(target, WebGL.TEXTURE_WRAP_T, warpMode);

    gl.texParameteri(target, WebGL.TEXTURE_MIN_FILTER, WebGL.LINEAR); // NEAREST, GL_LINEAR_MIPMAP_LINEAR
    gl.texParameteri(target, WebGL.TEXTURE_MAG_FILTER, WebGL.LINEAR); // NEAREST
  }

  void dispose() {
    gl.deleteTexture(_texture);
  }

  void bind() {
    gl.bindTexture(target, _texture);
  }

  static final WebGLTexture _textureNone = WebGLTexture(0);
  void unbind() {
    gl.bindTexture(target, _textureNone);
  }

  M3Texture.fromWebGLTexture(this._texture, {this.texW = 1024, this.texH = 1024}) : isCubemap = false;

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

  void _initColorPixel(Vector4 color, {int faceTarget = WebGL.TEXTURE_2D}) {
    texW = 1;
    texH = 1;

    // Fill the texture with a 1x1 white pixel.
    final pixel = Uint8Array.fromList([
      (color.r * 255).round().clamp(0, 255),
      (color.g * 255).round().clamp(0, 255),
      (color.b * 255).round().clamp(0, 255),
      (color.a * 255).round().clamp(0, 255),
    ]);
    gl.texImage2D(faceTarget, 0, WebGL.RGBA, 1, 1, 0, WebGL.RGBA, WebGL.UNSIGNED_BYTE, pixel);
  }

  void _initCheckerboard(int gridCount, Vector4 lightColor, Vector4 darkColor, {int faceTarget = WebGL.TEXTURE_2D}) {
    texW = gridCount;
    texH = gridCount;

    gl.texParameteri(target, WebGL.TEXTURE_MIN_FILTER, WebGL.NEAREST); // NEAREST, GL_LINEAR_MIPMAP_LINEAR
    gl.texParameteri(target, WebGL.TEXTURE_MAG_FILTER, WebGL.NEAREST); // NEAREST

    // Fill the texture with a checkerboard pattern.
    final lightPixel = Uint8Array.fromList([
      (lightColor.r * 255).round().clamp(0, 255),
      (lightColor.g * 255).round().clamp(0, 255),
      (lightColor.b * 255).round().clamp(0, 255),
      (lightColor.a * 255).round().clamp(0, 255),
    ]);
    final darkPixel = Uint8Array.fromList([
      (darkColor.r * 255).round().clamp(0, 255),
      (darkColor.g * 255).round().clamp(0, 255),
      (darkColor.b * 255).round().clamp(0, 255),
      (darkColor.a * 255).round().clamp(0, 255),
    ]);

    final data = Uint8Array.fromList(List.generate(gridCount * gridCount * 4, (index) => 0));
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

  static M3Texture createSampleCubemap({int gridCount = 9}) {
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
      tex._initCheckerboard(gridCount, colors[i], Vector4(0.6, 0.6, 0.6, 1), faceTarget: _cubeMapFaceTargets[i]);
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
    tex.unbind();
    return tex;
  }

  static Future<M3Texture> createFromBytes(Uint8List bytes, String name) async {
    M3Texture tex = M3Texture();
    tex.name = name;

    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    final img = frameInfo.image;

    tex.texW = img.width;
    tex.texH = img.height;

    final pixelFormat = WebGL.RGBA;
    await tex.gl.texImage2DfromImage(
      tex.target,
      img,
      format: pixelFormat,
      internalformat: pixelFormat,
      type: WebGL.UNSIGNED_BYTE,
    );

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
      Uint8Array byteData = Uint8Array.fromList(ktxInfo.texData);

      final pixelFormat = ktxInfo.glFormat;
      gl.compressedTexImage2D(faceTarget, 0, pixelFormat, texW, texH, 0, byteData);
      // } else if (lowerName.endsWith('.pvr')) {
      // PVR compressed texture
    } else {
      final data = await gl.loadImageFromAsset(filename);
      texW = data.width;
      texH = data.height;

      final pixelFormat = WebGL.RGBA;
      await gl.texImage2DfromImage(
        faceTarget,
        data,
        format: pixelFormat,
        internalformat: pixelFormat,
        type: WebGL.UNSIGNED_BYTE,
      );
    }
  }
}
