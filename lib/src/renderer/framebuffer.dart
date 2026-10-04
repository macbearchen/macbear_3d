import 'dart:typed_data';

// Macbear3D engine
import '../m3_internal.dart';

/// A WebGL framebuffer object for off-screen rendering (e.g., shadow maps).
///
/// Creates and manages a depth texture attached to a framebuffer.
class M3Framebuffer {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  int frameW = 1024;
  int frameH = 1024;

  late Framebuffer _fbo;
  Renderbuffer? _depthRenderbuffer;
  M3Texture? _colorTexture;
  M3Texture? _depthTexture;

  M3Texture get depthTexture => _depthTexture!;
  M3Texture get colorTexture => _colorTexture!;

  M3Framebuffer(this.frameW, this.frameH) {
    // Create FBO
    _fbo = gl.createFramebuffer();
    gl.bindFramebuffer(WebGL.FRAMEBUFFER, _fbo);
  }

  /// Create color texture
  M3Texture? createColorTexture({int target = WebGL.TEXTURE_2D}) {
    final isCubemap = target == WebGL.TEXTURE_CUBE_MAP;
    final texTarget = isCubemap ? WebGL.TEXTURE_CUBE_MAP_POSITIVE_X : WebGL.TEXTURE_2D;
    final texName = isCubemap ? 'RT_Cube' : 'RT_2d';
    M3Texture tex = M3Texture(target: target, wrap: WebGL.CLAMP_TO_EDGE, internalFormat: WebGL.SRGB8_ALPHA8)
      ..name = "${texName}_${frameW}x$frameH"
      ..allocateStorage(frameW, frameH)
      ..attachToFramebuffer(WebGL.COLOR_ATTACHMENT0, texTarget);

    _colorTexture = tex;
    _checkStatus();
    return tex;
  }

  /// Create depth texture
  /// internal format: DEPTH_COMPONENT16, (DEPTH_COMPONENT24), DEPTH_COMPONENT32F
  /// with stencil format: DEPTH24_STENCIL8
  M3Texture createDepthTexture({int depthFormat = WebGL.DEPTH_COMPONENT24}) {
    final attachment = switch (depthFormat) {
      WebGL.DEPTH24_STENCIL8 => WebGL.DEPTH_STENCIL_ATTACHMENT,
      _ => WebGL.DEPTH_ATTACHMENT,
    };

    M3Texture tex = M3Texture(useMipmaps: false, wrap: WebGL.CLAMP_TO_EDGE, internalFormat: depthFormat)
      ..name = 'RT_depth_${frameW}x$frameH'
      ..allocateStorage(frameW, frameH)
      ..attachToFramebuffer(attachment, WebGL.TEXTURE_2D);

    // depth-Z compare mode
    gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_COMPARE_MODE, WebGL.COMPARE_REF_TO_TEXTURE);
    gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_COMPARE_FUNC, WebGL.LESS);

    _depthTexture = tex;
    _checkStatus();
    return tex;
  }

  /// Create depth renderbuffer: DEPTH_COMPONENT24, (DEPTH24_STENCIL8)
  void createDepthRenderbuffer({int depthFormat = WebGL.DEPTH24_STENCIL8}) {
    _depthRenderbuffer = gl.createRenderbuffer();
    gl.bindRenderbuffer(WebGL.RENDERBUFFER, _depthRenderbuffer!);
    gl.renderbufferStorage(WebGL.RENDERBUFFER, depthFormat, frameW, frameH);

    final attachment = switch (depthFormat) {
      WebGL.DEPTH24_STENCIL8 => WebGL.DEPTH_STENCIL_ATTACHMENT,
      _ => WebGL.DEPTH_ATTACHMENT,
    };
    gl.framebufferRenderbuffer(WebGL.FRAMEBUFFER, attachment, WebGL.RENDERBUFFER, _depthRenderbuffer!);

    _checkStatus();
  }

  void _checkStatus() {
    assert(() {
      final status = gl.checkFramebufferStatus(WebGL.FRAMEBUFFER);
      if (status != WebGL.FRAMEBUFFER_COMPLETE) {
        String msg = 'n/a';
        switch (status) {
          case WebGL.FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
            msg = 'missing attachment';
            break;
          case WebGL.FRAMEBUFFER_INCOMPLETE_DIMENSIONS:
            msg = 'incomplete dimensions';
            break;
          case WebGL.FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
            msg = 'incomplete missing attachment';
            break;
          case WebGL.FRAMEBUFFER_UNSUPPORTED:
            msg = 'unsupported';
            break;
          default:
            msg = '0x${status.toRadixString(16).toUpperCase()} unknown';
            break;
        }
        M3Log.e('Framebuffer', 'FBO error: $msg');
      }

      return true;
    }());
  }

  /// Bind this FBO and set viewport size
  void bind() {
    gl.bindFramebuffer(WebGL.FRAMEBUFFER, _fbo);
    gl.viewport(0, 0, frameW, frameH);

    if (_colorTexture == null) {
      gl.drawBuffers(Uint32List.fromList([WebGL.NONE]));
    }
    _checkStatus();
  }

  void dispose() {
    _colorTexture?.dispose();
    _depthTexture?.dispose();
    if (_depthRenderbuffer != null) gl.deleteRenderbuffer(_depthRenderbuffer!);
    gl.deleteFramebuffer(_fbo);
  }
}
