import 'package:flutter/foundation.dart';
import 'package:flutter_angle/flutter_angle.dart';

import 'app_engine.dart';

/// A WebGL framebuffer object for off-screen rendering (e.g., shadow maps).
///
/// Creates and manages a depth texture attached to a framebuffer.
class M3Framebuffer {
  RenderingContext get gl => M3AppEngine.instance.renderEngine.gl;

  int frameW = 1024;
  int frameH = 1024;

  late Framebuffer _fbo;
  WebGLTexture? _depthTexture;
  Renderbuffer? _depthRenderbuffer;

  WebGLTexture get depthTexture => _depthTexture!;

  M3Framebuffer(this.frameW, this.frameH, {bool useDepthTexture = true}) {
    // Create FBO
    _fbo = gl.createFramebuffer();
    gl.bindFramebuffer(WebGL.FRAMEBUFFER, _fbo);

    if (useDepthTexture) {
      // Create depth texture
      _depthTexture = gl.createTexture();
      gl.bindTexture(WebGL.TEXTURE_2D, _depthTexture!);

      // Use DEPTH_COMPONENT16 for compatibility if needed, but DEPTH_COMPONENT is standard for texImage2D
      gl.texImage2D(
        WebGL.TEXTURE_2D,
        0,
        WebGL.DEPTH_COMPONENT16, // DEPTH_COMPONENT16, DEPTH_COMPONENT24, DEPTH_COMPONENT32F
        frameW,
        frameH,
        0,
        WebGL.DEPTH_COMPONENT,
        WebGL.UNSIGNED_SHORT, // UNSIGNED_SHORT, UNSIGNED_INT, FLOAT
        null,
      );

      gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, WebGL.LINEAR);
      gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MIN_FILTER, WebGL.LINEAR);
      gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_WRAP_S, WebGL.CLAMP_TO_EDGE);
      gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_WRAP_T, WebGL.CLAMP_TO_EDGE);

      // depth-Z compare mode
      gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_COMPARE_MODE, WebGL.COMPARE_REF_TO_TEXTURE);
      gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_COMPARE_FUNC, WebGL.LESS);

      gl.framebufferTexture2D(WebGL.FRAMEBUFFER, WebGL.DEPTH_ATTACHMENT, WebGL.TEXTURE_2D, _depthTexture!, 0);
    } else {
      // Create depth renderbuffer
      _depthRenderbuffer = gl.createRenderbuffer();
      gl.bindRenderbuffer(WebGL.RENDERBUFFER, _depthRenderbuffer!);
      gl.renderbufferStorage(WebGL.RENDERBUFFER, WebGL.DEPTH_COMPONENT16, frameW, frameH);
      gl.framebufferRenderbuffer(WebGL.FRAMEBUFFER, WebGL.DEPTH_ATTACHMENT, WebGL.RENDERBUFFER, _depthRenderbuffer!);
    }

    // Check status
    _checkStatus();
  }

  void _checkStatus() {
    assert(() {
      final status = gl.checkFramebufferStatus(WebGL.FRAMEBUFFER);
      if (status != WebGL.FRAMEBUFFER_COMPLETE) {
        debugPrint("FBO error: $status");
      }

      return true;
    }());
  }

  void bindFace(int faceTarget, WebGLTexture colorTexture) {
    bind();
    gl.framebufferTexture2D(WebGL.FRAMEBUFFER, WebGL.COLOR_ATTACHMENT0, faceTarget, colorTexture, 0);
  }

  void bind() {
    gl.bindFramebuffer(WebGL.FRAMEBUFFER, _fbo);
    gl.viewport(0, 0, frameW, frameH);
    _checkStatus();
  }

  void dispose() {
    if (_depthTexture != null) gl.deleteTexture(_depthTexture!);
    if (_depthRenderbuffer != null) gl.deleteRenderbuffer(_depthRenderbuffer!);
    gl.deleteFramebuffer(_fbo);
  }
}
