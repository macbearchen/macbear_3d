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
  late WebGLTexture depthTexture;

  M3Framebuffer(this.frameW, this.frameH) {
    // Create depth texture
    depthTexture = gl.createTexture();
    gl.bindTexture(WebGL.TEXTURE_2D, depthTexture);

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

    gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, WebGL.NEAREST);
    gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MIN_FILTER, WebGL.NEAREST);
    gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_WRAP_S, WebGL.CLAMP_TO_EDGE); //CLAMP_TO_BORDER
    gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_WRAP_T, WebGL.CLAMP_TO_EDGE);

    // depth-Z compare mode
    // gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_COMPARE_MODE, WebGL.COMPARE_REF_TO_TEXTURE);
    // gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_COMPARE_FUNC, WebGL.LESS);

    // Create FBO
    _fbo = gl.createFramebuffer();
    gl.bindFramebuffer(WebGL.FRAMEBUFFER, _fbo);
    gl.framebufferTexture2D(WebGL.FRAMEBUFFER, WebGL.DEPTH_ATTACHMENT, WebGL.TEXTURE_2D, depthTexture, 0);

    // We don't need a color attachment for shadow mapping, but some drivers might complain.
    // However, usually it's fine if we disable color writes or just don't read from it.
    // If needed, we can attach a dummy color texture or renderbuffer.

    // Check status (optional, but good for debugging)
    final status = gl.checkFramebufferStatus(WebGL.FRAMEBUFFER);
    if (status != WebGL.FRAMEBUFFER_COMPLETE) {
      debugPrint("Framebuffer not complete: $status");
    }
  }

  void bind() {
    gl.bindFramebuffer(WebGL.FRAMEBUFFER, _fbo);
    gl.viewport(0, 0, frameW, frameH);
  }

  void dispose() {
    gl.deleteTexture(depthTexture);
    gl.deleteFramebuffer(_fbo);
  }
}
