import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

/// A minimal TrueType parser to extract glyph paths.
class M3TrueTypeParser {
  final ByteData _data;
  final Map<String, int> _tableOFFSETS = {};

  int _numGlyphs = 0;
  int _unitsPerEm = 0;
  int _indexToLocFormat = 0; // 0 for short (16-bit), 1 for long (32-bit)

  List<int> _locaTable = [];
  Map<int, int> _cmap = {};
  List<double> _hMetrics = []; // Advance width for each glyph

  M3TrueTypeParser(Uint8List bytes) : _data = ByteData.sublistView(bytes) {
    _parseFile();
  }

  void _parseFile() {
    // 1. Offset Table
    // uint32 scalerType
    // uint16 numTables
    // uint16 searchRange
    // uint16 entrySelector
    // uint16 rangeShift
    int numTables = _data.getUint16(4);

    int offset = 12;
    for (int i = 0; i < numTables; i++) {
      String tag = _readTag(offset);
      int checkSum = _data.getUint32(offset + 4);
      int tableOffset = _data.getUint32(offset + 8);
      int length = _data.getUint32(offset + 12);
      print("Found table '$tag' at offset $tableOffset (length: $length)");
      _tableOFFSETS[tag] = tableOffset;
      offset += 16;
    }

    // 2. Head Table
    _parseHead();
    // 3. Maxp Table
    _parseMaxp();
    // 4. Loca Table
    _parseLoca();
    // 5. Cmap Table (Character to Glyph Index mapping)
    _parseCmap();
    // 6. Hmtx Table (Horizontal Metrics)
    _parseHmtx();
  }

  String _readTag(int offset) {
    List<int> chars = [];
    for (int i = 0; i < 4; i++) {
      chars.add(_data.getUint8(offset + i));
    }
    return String.fromCharCodes(chars);
  }

  void _parseHead() {
    int offset = _tableOFFSETS['head']!;
    _unitsPerEm = _data.getUint16(offset + 18);
    _indexToLocFormat = _data.getInt16(offset + 50);
  }

  void _parseMaxp() {
    int offset = _tableOFFSETS['maxp']!;
    _numGlyphs = _data.getUint16(offset + 4);
  }

  void _parseLoca() {
    int offset = _tableOFFSETS['loca']!;
    _locaTable = List.filled(_numGlyphs + 1, 0);

    for (int i = 0; i <= _numGlyphs; i++) {
      if (_indexToLocFormat == 0) {
        // Short version: offsets are divided by 2
        _locaTable[i] = _data.getUint16(offset + i * 2) * 2;
      } else {
        // Long version
        _locaTable[i] = _data.getUint32(offset + i * 4);
      }
    }
  }

  void _parseCmap() {
    int offset = _tableOFFSETS['cmap']!;
    int version = _data.getUint16(offset);
    int numberSubtables = _data.getUint16(offset + 2);

    int selectedOffset = 0;

    for (int i = 0; i < numberSubtables; i++) {
      int platformID = _data.getUint16(offset + 4 + i * 8);
      int encodingID = _data.getUint16(offset + 4 + i * 8 + 2);
      int subtableOffset = _data.getUint32(offset + 4 + i * 8 + 4);

      // Prefer Platform 3 (Windows), Encoding 1 (Unicode BMP) or 10 (Unicode full)
      // or Platform 0 (Unicode)
      if ((platformID == 3 && (encodingID == 1 || encodingID == 10)) || platformID == 0) {
        selectedOffset = offset + subtableOffset;
        break; // found a good table
      }
    }

    if (selectedOffset == 0) return; // No supported cmap found

    int format = _data.getUint16(selectedOffset);
    if (format == 4) {
      _parseCmapFormat4(selectedOffset);
    }
    // Format 12 could be added here for full unicode support
  }

  void _parseCmapFormat4(int offset) {
    int length = _data.getUint16(offset + 2);
    int segCountX2 = _data.getUint16(offset + 6);
    int segCount = segCountX2 ~/ 2;

    // Arrays location
    int endCodeOffset = offset + 14;
    int startCodeOffset = endCodeOffset + segCountX2 + 2; // +2 for reservedPad
    int idDeltaOffset = startCodeOffset + segCountX2;
    int idRangeOffsetOffset = idDeltaOffset + segCountX2;

    List<int> endCodes = [];
    List<int> startCodes = [];
    List<int> idDeltas = [];
    List<int> idRangeOffsets = [];

    for (int i = 0; i < segCount; i++) {
      endCodes.add(_data.getUint16(endCodeOffset + i * 2));
      startCodes.add(_data.getUint16(startCodeOffset + i * 2));
      idDeltas.add(_data.getUint16(idDeltaOffset + i * 2)); // Signed? Usually treated as adding
      idRangeOffsets.add(_data.getUint16(idRangeOffsetOffset + i * 2));
    }

    // This is a naive full map expander for simplicity.
    // Ideally we'd look up on demand.
    // For this MVP let's store valid map entries.
    // But since this could be large, let's keep it empty and used look up logic if needed
    // or just pre-fill a limited range (e.g. ASCII).
    // Let's implement `getGlyphIndex` instead of pre-caching everything.

    // Storing data for lookup method
    this._cmapFormat4Data = _CmapFormat4Data(
      segCount,
      endCodes,
      startCodes,
      idDeltas,
      idRangeOffsets,
      idRangeOffsetOffset,
    );
  }

  _CmapFormat4Data? _cmapFormat4Data;

  int getGlyphIndex(int charCode) {
    if (_cmapFormat4Data == null) return 0;

    var data = _cmapFormat4Data!;
    for (int i = 0; i < data.segCount; i++) {
      if (data.endCodes[i] >= charCode) {
        if (data.startCodes[i] <= charCode) {
          if (data.idRangeOffsets[i] == 0) {
            return (charCode + data.idDeltas[i]) & 0xFFFF;
          } else {
            int ptr = data.idRangeOffsetOffset + i * 2 + data.idRangeOffsets[i]; // pointer to idRangeOffset[i]
            // offset from ptr
            int offset = (charCode - data.startCodes[i]) * 2;
            int glyphId = _data.getUint16(ptr + offset);
            if (glyphId != 0) {
              return (glyphId + data.idDeltas[i]) & 0xFFFF;
            }
            return 0;
          }
        } else {
          break; // Since endCodes are sorted
        }
      }
    }
    return 0;
  }

  void _parseHmtx() {
    int offset = _tableOFFSETS['hmtx']!;
    int hheaOffset = _tableOFFSETS['hhea']!;
    int numberOfHMetrics = _data.getUint16(hheaOffset + 34);

    _hMetrics = [];
    for (int i = 0; i < numberOfHMetrics; i++) {
      int advanceWidth = _data.getUint16(offset + i * 4);
      // int lsb = _data.getInt16(offset + i * 4 + 2);
      _hMetrics.add(advanceWidth / _unitsPerEm);
    }
    // There are more LSb entries if numGlyphs > numberOfHMetrics, but we mainly need advanceWidth.
  }

  /// Returns the normalized advance width (based on unitsPerEm)
  double getAdvanceWidth(int glyphIndex) {
    if (glyphIndex >= _hMetrics.length) {
      if (_hMetrics.isNotEmpty) return _hMetrics.last;
      return 0.5; // fallback
    }
    return _hMetrics[glyphIndex];
  }

  /// Reads glyph contours. Returns a list of loops (contours).
  /// Each loop is a list of Vector2 points.
  List<List<Vector2>> getGlyphContours(int glyphIndex) {
    if (glyphIndex >= _locaTable.length - 1) return [];

    int offset = _tableOFFSETS['glyf']!;
    int glyphOffset = _locaTable[glyphIndex];
    int nextGlyphOffset = _locaTable[glyphIndex + 1];

    if (glyphOffset == nextGlyphOffset) {
      // Empty glyph (e.g. space)
      return [];
    }

    int fileOffset = offset + glyphOffset;

    // Glyph Header
    int numberOfContours = _data.getInt16(fileOffset);
    // int xMin = _data.getInt16(fileOffset + 2);
    // int yMin = _data.getInt16(fileOffset + 4);
    // int xMax = _data.getInt16(fileOffset + 6);
    // int yMax = _data.getInt16(fileOffset + 8);

    if (numberOfContours < 0) {
      // Compound glyph - NOT SUPPORTED in this minimal version
      // Return empty or placeholder
      return [];
    }

    fileOffset += 10;

    List<int> endPtsOfContours = [];
    for (int i = 0; i < numberOfContours; i++) {
      endPtsOfContours.add(_data.getUint16(fileOffset));
      fileOffset += 2;
    }

    int instructionLength = _data.getUint16(fileOffset);
    fileOffset += 2 + instructionLength; // Skip instructions

    int numPoints = endPtsOfContours.last + 1;
    List<int> flags = [];
    int i = 0;
    while (i < numPoints) {
      int flag = _data.getUint8(fileOffset++);
      flags.add(flag);
      i++;
      if ((flag & 8) != 0) {
        // Repeat flag
        int repeatCount = _data.getUint8(fileOffset++);
        for (int r = 0; r < repeatCount; r++) {
          flags.add(flag);
          i++;
        }
      }
    }

    // Read Coords
    List<int> xCoords = [];
    int x = 0;
    for (int f in flags) {
      int dx = 0;
      if ((f & 2) != 0) {
        // Short X
        int val = _data.getUint8(fileOffset++);
        dx = ((f & 16) != 0) ? val : -val;
      } else {
        if ((f & 16) == 0) {
          // Long X (same if bit 4 set means 0 delta, else int16)
          dx = _data.getInt16(fileOffset);
          fileOffset += 2;
        }
      }
      x += dx;
      xCoords.add(x);
    }

    List<int> yCoords = [];
    int y = 0;
    for (int f in flags) {
      int dy = 0;
      if ((f & 4) != 0) {
        // Short Y
        int val = _data.getUint8(fileOffset++);
        dy = ((f & 32) != 0) ? val : -val;
      } else {
        if ((f & 32) == 0) {
          // Long Y
          dy = _data.getInt16(fileOffset);
          fileOffset += 2;
        }
      }
      y += dy;
      yCoords.add(y);
    }

    // Convert to contours
    List<List<Vector2>> contours = [];
    int startIndex = 0;
    double scale = 1.0 / _unitsPerEm; // Normalize to 1.0 height-ish

    for (int end in endPtsOfContours) {
      List<Vector2> contour = [];
      int endIndex = end;

      // We are ignoring curve control points for this MVP and treating everything as straight lines (poly-lines).
      // A correct implementation would check ON_CURVE bit (bit 0 of flag) and tessellate Bezier curves.
      // But for small 3D text, polylines might be "okay" usually, or look jagged.
      // Let's at least capture the points.

      for (int k = startIndex; k <= endIndex; k++) {
        contour.add(Vector2(xCoords[k] * scale, yCoords[k] * scale));
      }
      contours.add(contour);
      startIndex = endIndex + 1;
    }

    return contours;
  }
}

class _CmapFormat4Data {
  final int segCount;
  final List<int> endCodes;
  final List<int> startCodes;
  final List<int> idDeltas;
  final List<int> idRangeOffsets;
  final int idRangeOffsetOffset; // To calculate absolute address

  _CmapFormat4Data(
    this.segCount,
    this.endCodes,
    this.startCodes,
    this.idDeltas,
    this.idRangeOffsets,
    this.idRangeOffsetOffset,
  );
}
