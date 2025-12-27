import 'dart:ui' as ui;

// Macbear3D engine
import '../../macbear_3d.dart';
import 'ktx_info.dart';

class M3Texture {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  // default white pixel 1x1
  static final texWhite = M3Texture.createWhitePixel();

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

  static M3Texture createWhitePixel() {
    M3Texture tex = M3Texture();
    tex.name = "white";
    tex._initPixel(Colors.white);
    return tex;
  }

  void _initPixel(Vector4 color, {int faceTarget = WebGL.TEXTURE_2D}) {
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
    List<int> targets = [
      WebGL.TEXTURE_CUBE_MAP_POSITIVE_X,
      WebGL.TEXTURE_CUBE_MAP_NEGATIVE_X,
      WebGL.TEXTURE_CUBE_MAP_POSITIVE_Y,
      WebGL.TEXTURE_CUBE_MAP_NEGATIVE_Y,
      WebGL.TEXTURE_CUBE_MAP_POSITIVE_Z,
      WebGL.TEXTURE_CUBE_MAP_NEGATIVE_Z,
    ];
    // 6 faces for cubemap
    for (int i = 0; i < 6; i++) {
      await tex._loadTarget(urls[i], faceTarget: targets[i]);
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
      _initPixel(Colors.red, faceTarget: faceTarget);
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
