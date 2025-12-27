import 'package:flutter/services.dart';

class M3Utility {
  static Future<bool> isAssetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }
}
