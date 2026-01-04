import 'dart:io';
import 'dart:typed_data';

// Copy of minimal parser parts or import if possible.
// For speed, let's just use the file path relative to execution.
// plain relative import

// It's safer to reproduce the logic or rely on relative imports if running from 'example/'

import 'lib/src/util/ttf_parser.dart';

void main() {
  final file = File('example/assets/example/test.ttf');
  if (!file.existsSync()) {
    print("File not found: ${file.path}");
    return;
  }

  final bytes = file.readAsBytesSync();
  print("File size: ${bytes.length}");

  try {
    final parser = M3TrueTypeParser(bytes);
    print("Parser initialized.");

    // Test a char
    int charCode = 'A'.codeUnitAt(0);
    print("Getting glyph for char code: $charCode");

    int glyphIndex = parser.getGlyphIndex(charCode);
    print("Glyph Index: $glyphIndex");

    print("Getting contours...");
    var contours = parser.getGlyphContours(glyphIndex);
    print("Contours found: ${contours.length}");
  } catch (e, stack) {
    print("Error: $e");
    print(stack);
  }
}
