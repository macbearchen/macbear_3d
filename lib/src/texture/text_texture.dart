import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';

import 'texture.dart';

class M3TextTexture extends M3Texture {
  String text;
  final String _fontFamily;
  final double _fontSize;
  Color color = const Color(0xFFFFFFFF);

  M3TextTexture._(this.text, {double fontSize = 32, String fontFamily = 'Arial'})
    : _fontFamily = fontFamily,
      _fontSize = fontSize,
      super(isCubemap: false) {
    name = "font($_fontSize, $_fontFamily): [$text]";
    _updateTexture();
  }

  static Future<M3TextTexture> createFixed(
    String text, {
    int width = 256,
    int height = 256,
    double fontSize = 32,
    String fontFamily = 'Arial',
  }) async {
    final tex = M3TextTexture._(text, fontSize: fontSize, fontFamily: fontFamily);
    tex.name = "createFixed: ${tex.name}";
    tex.texW = width;
    tex.texH = height;
    await tex._updateTexture();
    debugPrint(tex.toString());
    return tex;
  }

  /// 更新文字內容
  Future<void> updateText(String newText) async {
    text = newText;
    await _updateTexture();
  }

  /// 內部生成貼圖像素並上傳 GPU
  Future<void> _updateTexture() async {
    // 使用 dart:ui Canvas 繪製文字
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, texW.toDouble(), texH.toDouble()));

    // 背景透明
    final paint = Paint()..color = Color(0x00000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, texW.toDouble(), texH.toDouble()), paint);

    // 畫文字
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: _fontSize, fontFamily: _fontFamily),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: texW.toDouble());
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(texW, texH);

    gl.texImage2DfromImage(target, img, format: WebGL.RGBA, internalformat: WebGL.RGBA, type: WebGL.UNSIGNED_BYTE);
  }

  // size depends on text content
  static Future<M3TextTexture> createFromText(String text, {double fontSize = 32, String fontFamily = 'Arial'}) async {
    final tex = M3TextTexture._(text, fontSize: fontSize, fontFamily: fontFamily);
    tex.name = "createFromText: ${tex.name}";
    await tex._createTextureFromLabel(text);
    debugPrint(tex.toString());
    return tex;
  }

  Future<ui.Image> _makeLabelImage(
    String text, {
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: _fontFamily, // Courier, RobotoMono
          fontSize: _fontSize,
          color: Colors.white,
          letterSpacing: 1.1, // 這裡設定字距，數值越大間隔越開
          height: 1.1,
          // shadows: const [Shadow(blurRadius: 1, offset: Offset(1, 1))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final w = (textPainter.width + padding.horizontal).ceil();
    final h = (textPainter.height + padding.vertical).ceil();

    final bgPaint = Paint()..color = Colors.transparent;
    canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), bgPaint);

    textPainter.paint(canvas, Offset(padding.left, padding.top));

    final picture = recorder.endRecording();
    return picture.toImage(w, h);
  }

  Future<void> _createTextureFromLabel(String text) async {
    final img = await _makeLabelImage(text);

    texW = img.width;
    texH = img.height;

    await gl.texImage2DfromImage(
      WebGL.TEXTURE_2D,
      img,
      format: WebGL.RGBA,
      internalformat: WebGL.RGBA,
      type: WebGL.UNSIGNED_BYTE,
    );
  }
}
