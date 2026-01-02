part of 'sprite_2d.dart';

/// ASCII text renderer using a monospaced font texture atlas.
class M3Text2D extends M3Sprite2D {
  static final firstChar = 32; // first char in ASCII table
  static final lastChar = 126; // last char in ASCII table
  static final String _ascii = List.generate(95, (i) {
    final char = String.fromCharCode(i + firstChar);
    return (i > 0 && i % 16 == 0) ? '\n$char' : char;
  }).join();

  M3Text2D(super.tex) : super(rowCount: 16, colCount: 6);

  static Future<M3Text2D> createText2D({double fontSize = 32}) async {
    M3Texture tex = await M3TextTexture.createFromText(_ascii, fontSize: fontSize, fontFamily: 'Courier');

    M3Text2D text2D = M3Text2D(tex);

    return text2D;
  }

  void drawText(String text, Matrix4 mvMatrix, {Vector4? color}) {
    Vector3 offset = Vector3.zero();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '\n') {
        offset.x = 0;
        offset.y += _spriteH;
      } else {
        final charIndex = char.codeUnitAt(0) - firstChar;
        final textMatrix = Matrix4.copy(mvMatrix);
        textMatrix.translateByVector3(offset);

        // draw sprite by index
        super.draw(textMatrix, index: charIndex, color: color);
        offset.x += _spriteW;
      }
    }
  }
}
