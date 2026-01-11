// ignore_for_file: unused_field, unused_local_variable, prefer_final_fields, prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures
import 'package:flutter/services.dart';

// Macbear3D engine
import '../../../macbear_3d.dart';

/// A minimal TrueType (TTF) and OpenType (OTF) font parser to extract glyph paths for 3D reconstruction.
///
/// This parser extracts glyph outlines (contours) from font files and provides
/// them as sets of path commands for the geometry generators.
///
/// Key tables processed:
/// - `head`: Header info (units per EM, index to loc format).
/// - `maxp`: Maximum profile (number of glyphs).
/// - `loca`: Index to location (TTF only).
/// - `glyf`: Glyph data (TTF only).
/// - `cmap`: Character to glyph index mapping.
/// - `hmtx`: Horizontal metrics (advance widths).
/// - `CFF `/`CFF2`: PostScript outlines (OTF only).
class M3TrueTypeParser {
  /// The raw font file data.
  final ByteData _data;

  /// Offsets for various tables in the font file.
  final Map<String, int> _tableOFFSETS = {};

  int _numGlyphs = 0;
  int _unitsPerEm = 0;
  int _indexToLocFormat = 0; // 0 for short (16-bit), 1 for long (32-bit)

  List<int> _locaTable = [];
  Map<int, int> _cmap = {};
  List<double> _hMetrics = []; // Advance width for each glyph

  bool _isOTF = false;

  /// Returns true if the loaded font is in OpenType (CFF/CFF2) format.
  bool get isOTF => _isOTF;

  /// Returns true if the loaded font is in TrueType (glyf) format.
  bool get isTTF => !_isOTF;

  List<Uint8List> _charStrings = [];
  List<Uint8List> _globalSubrs = [];
  List<Uint8List> _localSubrs = [];

  /// Creates a font parser from raw [ByteData].
  M3TrueTypeParser(ByteData data) : _data = data {
    _parseFile();
  }

  /// Helper factory to load a font from a Flutter asset path.
  static Future<M3TrueTypeParser> loadFromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return M3TrueTypeParser(data);
  }

  /// Entry point for parsing the font file structure.
  void _parseFile() {
    try {
      _parseFileInternal();
    } catch (e, st) {
      debugPrint("FATAL ERROR in M3TrueTypeParser: $e\n$st");
      rethrow;
    }
  }

  void _parseFileInternal() {
    // 1. Offset Table
    // uint32 scalerType: 'true' (0x74727565), 0x00010000, or 'OTTO' (0x4F54544F)
    if (_data.lengthInBytes < 12) {
      debugPrint("Font file too small: ${_data.lengthInBytes}");
      return;
    }
    int scalerType = _data.getUint32(0);
    _isOTF = (scalerType == 0x4F54544F);

    int numTables = _data.getUint16(4);
    debugPrint("Scaler Type: ${scalerType.toRadixString(16)}, Tables: $numTables");

    int offset = 12;
    for (int i = 0; i < numTables; i++) {
      if (offset + 16 > _data.lengthInBytes) break;
      String tag = _readTag(offset);
      int checkSum = _data.getUint32(offset + 4);
      int tableOffset = _data.getUint32(offset + 8);
      int length = _data.getUint32(offset + 12);
      debugPrint("Found table '$tag' at offset $tableOffset (length: $length)");
      _tableOFFSETS[tag] = tableOffset;
      offset += 16;
    }

    // 2. Head Table
    _parseHead();
    // 3. Maxp Table
    _parseMaxp();
    // 4. Loca Table (only for TTF)
    if (!_isOTF && _tableOFFSETS.containsKey('loca')) {
      _parseLoca();
    }
    // 5. Cmap Table (Character to Glyph Index mapping)
    if (_tableOFFSETS.containsKey('cmap')) {
      _parseCmap();
    }
    // 6. Hmtx Table (Horizontal Metrics)
    if (_tableOFFSETS.containsKey('hmtx')) {
      _parseHmtx();
    }

    // 7. CFF2 Table (for OTF)
    if (_isOTF && _tableOFFSETS.containsKey('CFF2')) {
      _parseCFF2();
    }
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

    if (selectedOffset == 0 || selectedOffset + 2 > _data.lengthInBytes) return; // No supported cmap found

    int format = _data.getUint16(selectedOffset);
    if (format == 4) {
      _parseCmapFormat4(selectedOffset);
    } else if (format == 12) {
      _parseCmapFormat12(selectedOffset);
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
    _cmapFormat4Data = _CmapFormat4Data(segCount, endCodes, startCodes, idDeltas, idRangeOffsets, idRangeOffsetOffset);
  }

  void _parseCmapFormat12(int offset) {
    if (offset + 16 > _data.lengthInBytes) return;
    int numGroups = _data.getUint32(offset + 12);
    _cmapFormat12Data = [];
    for (int i = 0; i < numGroups; i++) {
      int groupOffset = offset + 16 + i * 12;
      if (groupOffset + 12 > _data.lengthInBytes) break;
      int start = _data.getUint32(groupOffset);
      int end = _data.getUint32(groupOffset + 4);
      int startGID = _data.getUint32(groupOffset + 8);
      _cmapFormat12Data!.add(_CmapGroup(start, end, startGID));
    }
  }

  _CmapFormat4Data? _cmapFormat4Data;
  List<_CmapGroup>? _cmapFormat12Data;

  int getGlyphIndex(int charCode) {
    if (_cmapFormat12Data != null) {
      for (var group in _cmapFormat12Data!) {
        if (charCode >= group.start && charCode <= group.end) {
          return group.startGID + (charCode - group.start);
        }
      }
    }
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

  void _parseCFF2() {
    int offset = _tableOFFSETS['CFF2']!;
    debugPrint("Parsing CFF2 at file offset $offset. File length: ${_data.lengthInBytes}");

    // CFF2 Header (5 bytes)
    // uint8 major (2)
    // uint8 minor (0)
    // uint8 headerSize (5+)
    // uint16 topDictLength
    int headerSize = _data.getUint8(offset + 2);
    int topDictLength = _data.getUint16(offset + 3);
    debugPrint("CFF2 HeaderSize: $headerSize, TopDictLength: $topDictLength");

    String hHex = "";
    for (int i = 0; i < 16 && i < _data.lengthInBytes - offset; i++) {
      hHex += _data.getUint8(offset + i).toRadixString(16).padLeft(2, '0') + " ";
    }
    debugPrint("CFF2 Header HEX: $hHex");

    int topDictOffset = offset + headerSize;
    if (topDictOffset + topDictLength > _data.lengthInBytes) {
      debugPrint("Top DICT out of bounds!");
      return;
    }
    var topDict = _readDICT(topDictOffset, topDictLength, isCFF2: true);
    debugPrint("Top DICT keys: ${topDict.keys.toList()}");

    // Diagnostic: Dump Top DICT
    String tdHex = "";
    for (int i = 0; i < topDictLength; i++) {
      tdHex += _data.getUint8(topDictOffset + i).toRadixString(16).padLeft(2, '0') + " ";
    }
    debugPrint("Top DICT HEX: $tdHex");

    // Global Subrs (immediately follows Top DICT)
    int globalSubrsOffset = topDictOffset + topDictLength;
    if (globalSubrsOffset < _data.lengthInBytes) {
      debugPrint("Reading Global Subrs at file offset $globalSubrsOffset");
      // Diagnostic
      if (globalSubrsOffset + 4 <= _data.lengthInBytes) {
        int rawCount = _data.getUint32(globalSubrsOffset);
        debugPrint("Global Subrs raw 4-byte count: $rawCount");
      }
      _globalSubrs = _readINDEX(globalSubrsOffset, isCFF2: true);
      debugPrint("Global Subrs count: ${_globalSubrs.length}");
    }

    // CharStrings
    if (topDict.containsKey(17)) {
      // 17 is CharStrings offset in Top DICT
      var vals = topDict[17]!;
      if (vals.isNotEmpty) {
        int charStringsOffset = offset + vals[0].toInt();
        debugPrint("CharStrings at offset $charStringsOffset");
        _charStrings = _readINDEX(charStringsOffset, isCFF2: true);
        _numGlyphs = _charStrings.length;
        debugPrint("CharStrings count: ${_charStrings.length}");
      }
    }

    // Local Subrs (via FDArray/FDSelect for CID fonts, or Private DICT)
    if (topDict.containsKey(0x0C24)) {
      // FDArray (12 36)
      // ItemVariationStore (24)
      if (topDict.containsKey(24)) {
        int varStoreOffset = offset + topDict[24]![0].toInt();
        _parseVarStore(varStoreOffset);
      }

      var vals = topDict[0x0C24]!;
      if (vals.isNotEmpty) {
        int fdArrayOffset = offset + vals[0].toInt();
        debugPrint("FDArray at offset $fdArrayOffset");
        var fdArray = _readINDEX(fdArrayOffset, isCFF2: true);
        _fdArray = fdArray;
        debugPrint("FDArray count: ${_fdArray.length}");
        if (_fdArray.isNotEmpty) {
          debugPrint("FDArray parsed, count: ${_fdArray.length}. Subrs will be lazy loaded.");
        }
      }
    } else if (topDict.containsKey(18)) {
      // Simple Private DICT (non-CID)
      var vals = topDict[18]!;
      if (vals.isNotEmpty) {
        int privateSize = vals[0].toInt();
        int privateOffset = offset + vals[1].toInt();
        var privateDict = _readDICT(privateOffset, privateSize, isCFF2: true);
        if (privateDict.containsKey(19)) {
          var sVals = privateDict[19]!;
          if (sVals.isNotEmpty) {
            int localSubrsOffset = privateOffset + sVals[0].toInt();
            _localSubrs = _readINDEX(localSubrsOffset, isCFF2: true);
            debugPrint("Non-CID Local Subrs loaded: ${_localSubrs.length}");
          }
        }
      }
    }

    // Parse FDSelect if present
    if (topDict.containsKey(3109)) {
      int fdSelectOffset = offset + topDict[3109]![0].toInt();
      _parseFDSelect(fdSelectOffset);
    }

    // Store FDArray entries for later lookup
    if (topDict.containsKey(3108)) {
      int fdArrayOffset = offset + topDict[3108]![0].toInt();
      debugPrint("Reading FDArray at offset $fdArrayOffset (CFF2 format)");

      // Diagnostic: Dump FDArray header
      String fdaHex = "";
      for (int j = 0; j < 16; j++) {
        fdaHex += _data.getUint8(fdArrayOffset + j).toRadixString(16).padLeft(2, '0') + " ";
      }
      debugPrint("FDArray Header HEX: $fdaHex");

      _fdArray = _readINDEX(fdArrayOffset, isCFF2: true);
      debugPrint("FDArray count: ${_fdArray.length}");
    }
  }

  Map<int, List<Uint8List>> _fdLocalSubrs = {};
  List<Uint8List> _fdArray = [];
  Map<int, int> _fdSelect = {}; // glyphIndex -> fdIndex
  Map<int, int> _regionIndexCounts = {}; // ivs -> regionIndexCount (k)

  void _parseVarStore(int offset) {
    if (offset + 10 >= _data.lengthInBytes) return;
    // CFF2 Variation Store starts with a 2-byte length
    int vstoreLength = _data.getUint16(offset);
    int ivsOffset = offset + 2; // Standard ItemVariationStore follows length

    int format = _data.getUint16(ivsOffset);
    int regionListOffset = _data.getUint32(ivsOffset + 2) + ivsOffset;
    int itemVariationDataCount = _data.getUint16(ivsOffset + 6);

    debugPrint("CFF2 VarStore total length: $vstoreLength, format: $format, count=$itemVariationDataCount");

    if (regionListOffset + 4 <= _data.lengthInBytes) {
      int axisCount = _data.getUint16(regionListOffset);
      int regionCount = _data.getUint16(regionListOffset + 2);
      debugPrint("CFF2 VarStore Config: Axes=$axisCount, Regions=$regionCount");
    }

    int pos = ivsOffset + 8;
    for (int i = 0; i < itemVariationDataCount; i++) {
      if (pos + 4 > _data.lengthInBytes) break;
      int ivdOffset = _data.getUint32(pos) + ivsOffset;
      pos += 4;

      if (ivdOffset + 6 <= _data.lengthInBytes) {
        int itemCount = _data.getUint16(ivdOffset);
        int shortDeltaCount = _data.getUint16(ivdOffset + 2);
        int regionIndexCount = _data.getUint16(ivdOffset + 4);

        debugPrint(
          "IVD $i: itemCount=$itemCount, shortDeltaCount=$shortDeltaCount, regionIndexCount (k) = $regionIndexCount",
        );

        // k is the number of regions used by this IVD
        _regionIndexCounts[i] = regionIndexCount;
      }
    }
  }

  void _parseFDSelect(int offset) {
    if (offset >= _data.lengthInBytes) return;
    int format = _data.getUint8(offset);
    debugPrint("FDSelect format $format at $offset");
    if (format == 0) {
      for (int i = 0; i < _numGlyphs; i++) {
        if (offset + 1 + i < _data.lengthInBytes) {
          _fdSelect[i] = _data.getUint8(offset + 1 + i);
        }
      }
      debugPrint("FDSelect (Format 0) loaded for $_numGlyphs glyphs");
    } else if (format == 3) {
      int numRanges = _data.getUint16(offset + 1);
      int pos = offset + 3;
      int count = 0;
      for (int i = 0; i < numRanges; i++) {
        if (pos + 3 > _data.lengthInBytes) break;
        int first = _data.getUint16(pos);
        int fd = _data.getUint8(pos + 2);
        int nextFirst = _data.getUint16(pos + 3);
        for (int g = first; g < nextFirst; g++) {
          _fdSelect[g] = fd;
        }
        count += (nextFirst - first);
        pos += 3;
      }
      debugPrint("FDSelect (Format 3) loaded $count mappings (ranges: $numRanges)");
    }
  }

  List<Uint8List> _getLocalSubrsForGlyph(int glyphIndex) {
    int fdIndex = _fdSelect[glyphIndex] ?? 0;
    if (_fdLocalSubrs.containsKey(fdIndex)) return _fdLocalSubrs[fdIndex]!;

    if (fdIndex < _fdArray.length) {
      debugPrint("Loading Local Subrs for FD $fdIndex (Glyph $glyphIndex)...");
      var fontDict = _readDICT(0, 0, dataOverride: _fdArray[fdIndex], isCFF2: true);
      if (fontDict.containsKey(18)) {
        var pVals = fontDict[18]!;
        if (pVals.length >= 2) {
          int privateSize = pVals[0].toInt();
          int privateOffset = _tableOFFSETS['CFF2']! + pVals[1].toInt();

          debugPrint("  Private DICT at $privateOffset (size $privateSize)");

          // Diagnostic: Dump Private DICT
          String pdHex = "";
          for (int j = 0; j < (privateSize < 64 ? privateSize : 64); j++) {
            pdHex += _data.getUint8(privateOffset + j).toRadixString(16).padLeft(2, '0') + " ";
          }
          debugPrint("  Private DICT HEX: $pdHex");

          var privateDict = _readDICT(privateOffset, privateSize, isCFF2: true);

          if (privateDict.containsKey(19)) {
            int localSubrsOffset = privateOffset + privateDict[19]![0].toInt();
            var subrs = _readINDEX(localSubrsOffset, isCFF2: true);
            debugPrint("  Local Subrs at $localSubrsOffset: count ${subrs.length}");
            _fdLocalSubrs[fdIndex] = subrs;
            return subrs;
          } else {
            debugPrint("  No Local Subrs in Private DICT for FD $fdIndex");
            _fdLocalSubrs[fdIndex] = [];
            return [];
          }
        }
      }
    }

    // Fallback?
    if (fdIndex > 0) {
      debugPrint("Warning: No Local Subrs found for FD $fdIndex (Glyph $glyphIndex). Fallback to empty.");
    }
    return _localSubrs;
  }

  List<Uint8List> _readINDEX(int fileOffset, {bool isCFF2 = false}) {
    if (fileOffset + (isCFF2 ? 5 : 3) > _data.lengthInBytes) {
      debugPrint("INDEX file offset out of bounds: $fileOffset");
      return [];
    }

    int count;
    int offSize;
    int pos;

    if (isCFF2) {
      // In CFF2, INDEX count is 4 bytes (Card32)
      count = _data.getUint32(fileOffset);
      offSize = _data.getUint8(fileOffset + 4);
      pos = fileOffset + 5;
    } else {
      // In CFF1, INDEX count is 2 bytes (Card16)
      count = _data.getUint16(fileOffset);
      if (count == 0) return [];
      offSize = _data.getUint8(fileOffset + 2);
      pos = fileOffset + 3;
    }

    if (count == 0 || count > 0x1000000) {
      // Safety cap
      if (count != 0) debugPrint("INDEX count too large or invalid: $count");
      return [];
    }

    if (offSize < 1 || offSize > 4) {
      debugPrint("INDEX invalid offSize: $offSize");
      return [];
    }
    int offsetArraySize = (count + 1) * offSize;
    if (pos + offsetArraySize > _data.lengthInBytes) {
      debugPrint("INDEX offset array out of bounds (pos $pos, size $offsetArraySize)");
      return [];
    }

    List<int> offsets = [];
    for (int i = 0; i <= count; i++) {
      int val = 0;
      for (int j = 0; j < offSize; j++) {
        val = (val << 8) | _data.getUint8(pos++);
      }
      offsets.add(val);
    }

    // The offsets are 1-based relative to the byte preceding the first data byte.
    // So dataStart = pos - 1.
    int dataBase = pos - 1;
    List<Uint8List> objects = [];

    for (int i = 0; i < count; i++) {
      int start = offsets[i];
      int end = offsets[i + 1];
      int len = end - start;

      if (len < 0) {
        debugPrint("INDEX invalid object length at $i: $len");
        continue;
      }

      int absoluteStart = dataBase + start;
      if (absoluteStart + len > _data.lengthInBytes) {
        debugPrint(
          "INDEX object $i data out of bounds (absStart $absoluteStart, len $len, total ${_data.lengthInBytes})",
        );
        break;
      }

      if (len == 0) {
        objects.add(Uint8List(0));
      } else {
        // Create a copy to be safe and avoid view issues
        final bytes = Uint8List(len);
        for (int k = 0; k < len; k++) {
          bytes[k] = _data.getUint8(absoluteStart + k);
        }
        objects.add(bytes);
      }
    }
    return objects;
  }

  Map<int, List<double>> _readDICT(int offset, int length, {Uint8List? dataOverride, bool isCFF2 = false}) {
    Map<int, List<double>> dict = {};
    List<double> stack = [];
    int dictK = _regionIndexCounts[0] ?? 0;

    if (offset < 0 || (dataOverride == null && offset + length > _data.lengthInBytes)) {
      debugPrint("Invalid DICT range: offset $offset, length $length");
      return dict;
    }

    ByteData d;
    int start = 0;
    int end = 0;

    if (dataOverride != null) {
      if (dataOverride.isEmpty) return dict;
      d = ByteData.sublistView(dataOverride);
      start = 0;
      end = dataOverride.length;
    } else {
      d = _data;
      start = offset;
      end = offset + length;
    }

    int pos = start;
    while (pos < end) {
      int b0 = d.getUint8(pos++);
      if (b0 <= 27) {
        // CFF2 operators are 0-27
        int key = b0;
        if (b0 == 12) {
          if (pos >= end) break;
          key = (b0 << 8) | d.getUint8(pos++);
        }

        if (isCFF2) {
          if (key == 23) {
            // blend
            if (stack.isNotEmpty) {
              int n = stack.removeLast().toInt();
              int totalArgs = n + n * dictK;
              if (stack.length >= totalArgs) {
                // Simplified blend: keep default values
                List<double> defaults = stack.sublist(stack.length - totalArgs, stack.length - (n * dictK));
                stack.removeRange(stack.length - totalArgs, stack.length);
                stack.addAll(defaults);
              }
            }
            continue;
          } else if (key == 22) {
            // vsindex
            if (stack.isNotEmpty) {
              int ivs = stack.removeLast().toInt();
              dictK = _regionIndexCounts[ivs] ?? 0;
            }
            continue;
          }
        }

        dict[key] = List.from(stack);
        stack.clear();
      } else if (b0 == 28) {
        if (pos + 2 > end) {
          pos = end;
          break;
        }
        stack.add(d.getInt16(pos).toDouble());
        pos += 2;
      } else if (b0 == 29) {
        if (pos + 4 > end) {
          pos = end;
          break;
        }
        stack.add(d.getInt32(pos).toDouble());
        pos += 4;
      } else if (b0 == 30) {
        pos = _readReal(d, pos, end, stack);
      } else if (b0 >= 32 && b0 <= 246) {
        stack.add((b0 - 139).toDouble());
      } else if (b0 >= 247 && b0 <= 250) {
        if (pos >= end) {
          pos = end;
          break;
        }
        stack.add(((b0 - 247) * 256 + d.getUint8(pos++) + 108).toDouble());
      } else if (b0 >= 251 && b0 <= 254) {
        if (pos >= end) {
          pos = end;
          break;
        }
        stack.add((-(b0 - 251) * 256 - d.getUint8(pos++) - 108).toDouble());
      }
    }
    return dict;
  }

  int _readReal(ByteData d, int pos, int end, List<double> stack) {
    String s = "";
    bool terminated = false;
    while (pos < end && !terminated) {
      int b = d.getUint8(pos++);
      for (int i = 0; i < 2; i++) {
        int nibble = (i == 0) ? (b >> 4) : (b & 0x0F);
        if (nibble <= 9)
          s += nibble.toString();
        else if (nibble == 10)
          s += ".";
        else if (nibble == 11)
          s += "E";
        else if (nibble == 12)
          s += "E-";
        else if (nibble == 13) {
        } // reserved
        else if (nibble == 14)
          s += "-";
        else if (nibble == 15) {
          terminated = true;
          break;
        }
      }
    }
    if (s.isNotEmpty) {
      try {
        stack.add(double.parse(s));
      } catch (e) {
        debugPrint("Error parsing CFF real: $s");
      }
    }
    return pos;
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
  /// [subdivisions] is the number of segments for each Bezier curve.
  List<List<Vector2>> getGlyphContours(int glyphIndex, {int subdivisions = 4}) {
    if (_isOTF) {
      return _getGlyphContoursCFF(glyphIndex, subdivisions: subdivisions);
    }

    if (glyphIndex >= _locaTable.length - 1) return [];

    int offset = _tableOFFSETS['glyf']!;
    int glyphOffset = _locaTable[glyphIndex];
    int nextGlyphOffset = _locaTable[glyphIndex + 1];

    if (glyphOffset == nextGlyphOffset) {
      // Empty glyph (e.g. space)
      return [];
    }

    int fileOffset = offset + glyphOffset;
    if (fileOffset + 10 > _data.lengthInBytes) {
      // Check for glyph header bounds
      debugPrint("Glyph header out of bounds for glyph $glyphIndex at offset $fileOffset");
      return [];
    }

    // Glyph Header
    int numberOfContours = _data.getInt16(fileOffset);
    if (numberOfContours < 0) {
      // Compound glyph - NOT SUPPORTED in this minimal version
      debugPrint("Compound glyph $glyphIndex not supported.");
      return [];
    }

    fileOffset += 10;

    List<int> endPtsOfContours = [];
    for (int i = 0; i < numberOfContours; i++) {
      if (fileOffset + 2 > _data.lengthInBytes) {
        debugPrint("EndPtsOfContours read out of bounds for glyph $glyphIndex at offset $fileOffset");
        return [];
      }
      endPtsOfContours.add(_data.getUint16(fileOffset));
      fileOffset += 2;
    }

    if (fileOffset + 2 > _data.lengthInBytes) {
      debugPrint("InstructionLength read out of bounds for glyph $glyphIndex at offset $fileOffset");
      return [];
    }
    int instructionLength = _data.getUint16(fileOffset);
    if (fileOffset + 2 + instructionLength > _data.lengthInBytes) {
      debugPrint("Instructions out of bounds for glyph $glyphIndex at offset $fileOffset (length $instructionLength)");
      return [];
    }
    fileOffset += 2 + instructionLength; // Skip instructions

    if (endPtsOfContours.isEmpty) {
      debugPrint("Glyph $glyphIndex has 0 contours but numberOfContours was $numberOfContours.");
      return [];
    }
    int numPoints = endPtsOfContours.last + 1;
    List<int> flags = [];
    int i = 0;
    while (i < numPoints) {
      if (fileOffset >= _data.lengthInBytes) {
        debugPrint("Flags read out of bounds for glyph $glyphIndex at offset $fileOffset (point $i/$numPoints)");
        return [];
      }
      int flag = _data.getUint8(fileOffset++);
      flags.add(flag);
      i++;
      if ((flag & 8) != 0) {
        // Repeat flag
        if (fileOffset >= _data.lengthInBytes) {
          debugPrint("Repeat count read out of bounds for glyph $glyphIndex at offset $fileOffset");
          return [];
        }
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
        if (fileOffset >= _data.lengthInBytes) {
          debugPrint("X-coordinate byte read out of bounds for glyph $glyphIndex at offset $fileOffset");
          return [];
        }
        int val = _data.getUint8(fileOffset++);
        dx = ((f & 16) != 0) ? val : -val;
      } else {
        if ((f & 16) == 0) {
          if (fileOffset + 2 > _data.lengthInBytes) {
            debugPrint("X-coordinate short read out of bounds for glyph $glyphIndex at offset $fileOffset");
            return [];
          }
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
        if (fileOffset >= _data.lengthInBytes) {
          debugPrint("Y-coordinate byte read out of bounds for glyph $glyphIndex at offset $fileOffset");
          return [];
        }
        int val = _data.getUint8(fileOffset++);
        dy = ((f & 32) != 0) ? val : -val;
      } else {
        if ((f & 32) == 0) {
          if (fileOffset + 2 > _data.lengthInBytes) {
            debugPrint("Y-coordinate short read out of bounds for glyph $glyphIndex at offset $fileOffset");
            return [];
          }
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
      int endIndex = end;
      int count = endIndex - startIndex + 1;
      if (count < 2) {
        startIndex = endIndex + 1;
        continue;
      }

      List<Vector2> pts = [];
      List<bool> onCurve = [];
      for (int k = startIndex; k <= endIndex; k++) {
        if (k >= xCoords.length || k >= yCoords.length || k >= flags.length) {
          debugPrint(
            "Coordinate or flag index out of bounds for glyph $glyphIndex at point $k (startIndex $startIndex, endIndex $endIndex)",
          );
          return []; // Critical error
        }
        pts.add(Vector2(xCoords[k] * scale, yCoords[k] * scale));
        onCurve.add((flags[k] & 1) != 0);
      }

      List<Vector2> contour = [];

      // Find first on-curve point
      int startIdx = -1;
      for (int k = 0; k < count; k++) {
        if (onCurve[k]) {
          startIdx = k;
          break;
        }
      }

      void addQuad(Vector2 p0, Vector2 p1, Vector2 p2) {
        if (subdivisions <= 1) {
          contour.add(p2);
          return;
        }
        for (int s = 1; s <= subdivisions; s++) {
          double t = s / subdivisions;
          double invT = 1.0 - t;
          double tx = invT * invT * p0.x + 2 * invT * t * p1.x + t * t * p2.x;
          double ty = invT * invT * p0.y + 2 * invT * t * p1.y + t * t * p2.y;
          contour.add(Vector2(tx, ty));
        }
      }

      if (startIdx == -1) {
        // All points are off-curve (uncommon but possible in some fonts)
        // Treat as a closed sequence of quadratics with midpoints as on-curve
        for (int k = 0; k < count; k++) {
          Vector2 p1 = pts[k];
          Vector2 p2 = (pts[k] + pts[(k + 1) % count]) * 0.5;
          Vector2 p0 = (pts[(k - 1 + count) % count] + pts[k]) * 0.5;
          addQuad(p0, p1, p2);
        }
      } else {
        // Rotate to start with on-curve point
        List<Vector2> rotatedPts = [];
        List<bool> rotatedOn = [];
        for (int k = 0; k < count; k++) {
          int idx = (startIdx + k) % count;
          rotatedPts.add(pts[idx]);
          rotatedOn.add(onCurve[idx]);
        }

        contour.add(rotatedPts[0]);
        for (int k = 1; k < count; k++) {
          if (rotatedOn[k]) {
            contour.add(rotatedPts[k]);
          } else {
            Vector2 p0 = contour.last;
            Vector2 p1 = rotatedPts[k];
            Vector2 p2;
            if (k + 1 < count && rotatedOn[k + 1]) {
              p2 = rotatedPts[k + 1];
              k++; // Skip next since it's the end of this cubic
            } else if (k + 1 < count) {
              // Consecutive off-curve points
              p2 = (rotatedPts[k] + rotatedPts[k + 1]) * 0.5;
              // Don't skip k+1, it's the control point for the next segment
            } else {
              // Last point is off-curve, connects back to start (which is on-curve)
              p2 = rotatedPts[0];
            }
            addQuad(p0, p1, p2);
          }
        }
        // Final edge back to start if needed (already handled by rotated logic mostly)
      }

      contours.add(contour);
      startIndex = endIndex + 1;
    }

    return contours;
  }

  List<List<Vector2>> _getGlyphContoursCFF(int glyphIndex, {int subdivisions = 4}) {
    if (glyphIndex >= _charStrings.length) {
      debugPrint("CFF: Glyph index $glyphIndex out of bounds for charStrings (length: ${_charStrings.length})");
      return [];
    }
    Uint8List charString = _charStrings[glyphIndex];
    List<Uint8List> localSubrs = _getLocalSubrsForGlyph(glyphIndex);

    List<List<Vector2>> contours = [];

    // Debug: Dump CharString for analysis
    if (contours.isEmpty && glyphIndex > 0) {
      // Limit spam, maybe trigger on error?
      String hex = charString.take(50).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      debugPrint("Glyph $glyphIndex CharString Head: $hex");
      debugPrint("Local Subrs count: ${localSubrs.length}, Global Subrs count: ${_globalSubrs.length}");
    }
    List<Vector2> currentContour = [];
    Vector2 currentPos = Vector2(0, 0);

    List<double> stack = [];
    double scale = 1.0 / _unitsPerEm;

    // TEMPORARY: Force k=0 to render static glyphs without variations.
    // This makes blend a no-op, keeping default values only.
    // Track stem hints for hintmask/cntrmask
    int numStemHints = 0;

    // Initial k from VarStore Data 0
    int k = _regionIndexCounts[0] ?? 0;

    void interpret(Uint8List data, {int depth = 0}) {
      if (depth > 20) {
        debugPrint("CFF CharString: Recursive call limit reached.");
        return;
      }
      int pos = 0;
      while (pos < data.length) {
        int b0 = data[pos++];
        if (glyphIndex == 63243) {
          debugPrint("  [CS Trace] pos ${pos - 1}: 0x${b0.toRadixString(16)} stack: $stack");
        }

        if (b0 >= 32) {
          double val;
          if (b0 <= 246) {
            val = (b0 - 139).toDouble();
          } else if (b0 <= 250) {
            val = ((b0 - 247) * 256 + data[pos++] + 108).toDouble();
          } else if (b0 <= 254) {
            val = (-(b0 - 251) * 256 - data[pos++] - 108).toDouble();
          } else {
            // 255
            final bd = ByteData.sublistView(data, pos, 4);
            val = bd.getInt32(0) / 65536.0;
            pos += 4;
          }
          stack.add(val);
          continue; // Operand pushed, next byte.
        }

        if (b0 == 28) {
          final bd = ByteData.sublistView(data, pos, 2);
          stack.add(bd.getInt16(0).toDouble());
          pos += 2;
          continue;
        }

        if (b0 == 10) {
          if (stack.isNotEmpty) {
            int subrIndex = stack.removeLast().toInt();
            int bias = localSubrs.length < 1240 ? 107 : (localSubrs.length < 33900 ? 1131 : 32768);
            int idx = subrIndex + bias;
            if (idx >= 0 && idx < localSubrs.length) {
              interpret(localSubrs[idx], depth: depth + 1);
            }
          }
          continue;
        }

        if (b0 == 29) {
          if (stack.isNotEmpty) {
            int subrIndex = stack.removeLast().toInt();
            int bias = _globalSubrs.length < 1240 ? 107 : (_globalSubrs.length < 33900 ? 1131 : 32768);
            int idx = subrIndex + bias;
            if (idx >= 0 && idx < _globalSubrs.length) {
              interpret(_globalSubrs[idx], depth: depth + 1);
            }
          }
          continue;
        }

        // Operator
        int op = b0;
        if (op == 12) {
          op = (12 << 8) | data[pos++];
        }

        if (op == 3094) {
          // vsindex (12 22)
          if (stack.isNotEmpty) {
            int ivs = stack.removeLast().toInt();
            k = _regionIndexCounts[ivs] ?? k;
            debugPrint("CFF CharString: vsindex set to $ivs (k=$k)");
          }
          continue;
        }

        if (op == 1 || op == 3 || op == 18 || op == 23) {
          numStemHints += stack.length ~/ 2;
          stack.clear();
          continue;
        }

        if (op == 19 || op == 20) {
          numStemHints += stack.length ~/ 2;
          stack.clear();
          if (numStemHints > 0) pos += (numStemHints + 7) ~/ 8;
          continue;
        }

        switch (op) {
          case 21: // rmoveto
            if (stack.length >= 2) {
              if (currentContour.isNotEmpty) contours.add(List.from(currentContour));
              currentContour = [];
              currentPos += Vector2(stack[stack.length - 2] * scale, stack[stack.length - 1] * scale);
              currentContour.add(Vector2(currentPos.x, currentPos.y));
            } else {
              debugPrint("CFF CharString: rmoveto underflow at pos ${pos - 1}");
            }
            stack.clear();
            break;
          case 4: // vmoveto
            if (stack.isNotEmpty) {
              if (currentContour.isNotEmpty) contours.add(List.from(currentContour));
              currentContour = [];
              currentPos.y += stack.removeLast() * scale;
              currentContour.add(Vector2(currentPos.x, currentPos.y));
            }
            stack.clear();
            break;
          case 22: // hmoveto
            if (stack.isNotEmpty) {
              if (currentContour.isNotEmpty) contours.add(List.from(currentContour));
              currentContour = [];
              currentPos.x += stack.removeLast() * scale;
              currentContour.add(Vector2(currentPos.x, currentPos.y));
            }
            stack.clear();
            break;
          case 5: // rlineto
            for (int i = 0; i + 1 < stack.length; i += 2) {
              currentPos += Vector2(stack[i] * scale, stack[i + 1] * scale);
              currentContour.add(Vector2(currentPos.x, currentPos.y));
            }
            stack.clear();
            break;
          case 6: // hlineto
          case 7: // vlineto
            bool horizontal = (op == 6);
            for (int i = 0; i < stack.length; i++) {
              if (horizontal)
                currentPos.x += stack[i] * scale;
              else
                currentPos.y += stack[i] * scale;
              currentContour.add(Vector2(currentPos.x, currentPos.y));
              horizontal = !horizontal;
            }
            stack.clear();
            break;
          case 8: // rrcurveto
            for (int i = 0; i + 5 < stack.length; i += 6) {
              Vector2 p0 = Vector2(currentPos.x, currentPos.y);
              Vector2 p1 = p0 + Vector2(stack[i] * scale, stack[i + 1] * scale);
              Vector2 p2 = p1 + Vector2(stack[i + 2] * scale, stack[i + 3] * scale);
              Vector2 p3 = p2 + Vector2(stack[i + 4] * scale, stack[i + 5] * scale);
              _addCubic(currentContour, p0, p1, p2, p3, subdivisions);
              currentPos = p3;
            }
            stack.clear();
            break;
          case 24: // rcurveline
            int i = 0;
            for (; i + 5 < stack.length - 2; i += 6) {
              Vector2 p0 = Vector2(currentPos.x, currentPos.y);
              Vector2 p1 = p0 + Vector2(stack[i] * scale, stack[i + 1] * scale);
              Vector2 p2 = p1 + Vector2(stack[i + 2] * scale, stack[i + 3] * scale);
              Vector2 p3 = p2 + Vector2(stack[i + 4] * scale, stack[i + 5] * scale);
              _addCubic(currentContour, p0, p1, p2, p3, subdivisions);
              currentPos = p3;
            }
            if (i + 1 < stack.length) {
              currentPos += Vector2(stack[i] * scale, stack[i + 1] * scale);
              currentContour.add(Vector2(currentPos.x, currentPos.y));
            }
            stack.clear();
            break;
          case 25: // rlinecurve
            int i = 0;
            for (; i + 1 < stack.length - 6; i += 2) {
              currentPos += Vector2(stack[i] * scale, stack[i + 1] * scale);
              currentContour.add(Vector2(currentPos.x, currentPos.y));
            }
            if (i + 5 < stack.length) {
              Vector2 p0 = Vector2(currentPos.x, currentPos.y);
              Vector2 p1 = p0 + Vector2(stack[i] * scale, stack[i + 1] * scale);
              Vector2 p2 = p1 + Vector2(stack[i + 2] * scale, stack[i + 3] * scale);
              Vector2 p3 = p2 + Vector2(stack[i + 4] * scale, stack[i + 5] * scale);
              _addCubic(currentContour, p0, p1, p2, p3, subdivisions);
              currentPos = p3;
            }
            stack.clear();
            break;
          case 26: // vvcurveto
            int i = 0;
            if (stack.length % 4 == 1) currentPos.x += stack[i++] * scale;
            for (; i + 3 < stack.length; i += 4) {
              Vector2 p0 = Vector2(currentPos.x, currentPos.y);
              Vector2 p1 = p0 + Vector2(0, stack[i] * scale);
              Vector2 p2 = p1 + Vector2(stack[i + 1] * scale, stack[i + 2] * scale);
              Vector2 p3 = p2 + Vector2(0, stack[i + 3] * scale);
              _addCubic(currentContour, p0, p1, p2, p3, subdivisions);
              currentPos = p3;
            }
            stack.clear();
            break;
          case 27: // hhcurveto
            int i = 0;
            if (stack.length % 4 == 1) currentPos.y += stack[i++] * scale;
            for (; i + 3 < stack.length; i += 4) {
              Vector2 p0 = Vector2(currentPos.x, currentPos.y);
              Vector2 p1 = p0 + Vector2(stack[i] * scale, 0);
              Vector2 p2 = p1 + Vector2(stack[i + 1] * scale, stack[i + 2] * scale);
              Vector2 p3 = p2 + Vector2(stack[i + 3] * scale, 0);
              _addCubic(currentContour, p0, p1, p2, p3, subdivisions);
              currentPos = p3;
            }
            stack.clear();
            break;
          case 30: // vhcurveto
          case 31: // hvcurveto
            bool verticalFirst = (op == 30);
            int i = 0;
            while (i + 3 < stack.length) {
              Vector2 p0 = Vector2(currentPos.x, currentPos.y);
              Vector2 p1, p2, p3;
              if (verticalFirst) {
                p1 = p0 + Vector2(0, stack[i++] * scale);
                p2 = p1 + Vector2(stack[i++] * scale, stack[i++] * scale);
                p3 = p2 + Vector2(stack[i++] * scale, 0);
                if (i == stack.length - 1) p3.y += stack[i++] * scale;
              } else {
                p1 = p0 + Vector2(stack[i++] * scale, 0);
                p2 = p1 + Vector2(stack[i++] * scale, stack[i++] * scale);
                p3 = p2 + Vector2(0, stack[i++] * scale);
                if (i == stack.length - 1) p3.x += stack[i++] * scale;
              }
              _addCubic(currentContour, p0, p1, p2, p3, subdivisions);
              currentPos = p3;
              verticalFirst = !verticalFirst;
            }
            stack.clear();
            break;
          case 11: // return
            return;
          case 14: // endchar
            if (currentContour.isNotEmpty) contours.add(List.from(currentContour));
            currentContour = [];
            stack.clear();
            return;
          case 16: // blend
            if (stack.isNotEmpty) {
              int n = stack.removeLast().toInt();
              int totalDeltas = n * k;
              debugPrint("CFF CharString: blend (n=$n, k=$k) stack size: ${stack.length}");
              if (stack.length < totalDeltas && n > 0) {
                // heuristic: if we have n + some deltas, maybe k is different
                int available = stack.length - n;
                if (available >= 0 && available % n == 0)
                  totalDeltas = available;
                else
                  totalDeltas = available > 0 ? available : 0;
              }
              if (stack.length >= totalDeltas) {
                stack.removeRange(stack.length - totalDeltas, stack.length);
              } else {
                stack.clear();
              }
            }
            break;
          default:
            stack.clear();
            break;
        }
      }
    }

    interpret(charString);
    if (currentContour.isNotEmpty) contours.add(List.from(currentContour));

    if (contours.isEmpty) return contours;

    return contours;
  }

  void _addCubic(List<Vector2> contour, Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3, int subdivisions) {
    if (subdivisions <= 1) {
      contour.add(p3);
      return;
    }
    for (int s = 1; s <= subdivisions; s++) {
      double t = s / subdivisions;
      double invT = 1.0 - t;
      double tx = invT * invT * invT * p0.x + 3 * invT * invT * t * p1.x + 3 * invT * t * t * p2.x + t * t * t * p3.x;
      double ty = invT * invT * invT * p0.y + 3 * invT * invT * t * p1.y + 3 * invT * t * t * p2.y + t * t * t * p3.y;
      contour.add(Vector2(tx, ty));
    }
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

class _CmapGroup {
  final int start;
  final int end;
  final int startGID;
  _CmapGroup(this.start, this.end, this.startGID);
}
