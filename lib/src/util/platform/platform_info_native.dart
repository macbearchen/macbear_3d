import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart'; // 需要 pkg:ffi

// Macbear3D engine
import '../../m3_internal.dart';
import 'platform_info_vulkan.dart';

bool isPlatformAndroid() => Platform.isAndroid;
bool isPlatformIOS() => Platform.isIOS;
bool isPlatformMacOS() => Platform.isMacOS;
bool isPlatformWindows() => Platform.isWindows;

String getPlatformName() {
  return Platform.operatingSystem; // Android, iOS, Windows, etc.
}

/// Global flag to control ANGLE usage on Android.
/// Can be set before engine initialization.
bool useAngleAndroid = true;

void initPlatformImpl() {
  if (Platform.isAndroid) {
    bool hasVulkan = PlatformInfoVulkan.shouldInitVulkan();
    useAngleAndroid = hasVulkan;
    M3Log.i('PlatformInfo', 'Android GPU Detection (init)');
    M3Log.i('PlatformInfo', 'Vulkan Support Detected: $hasVulkan');
    M3Log.i('PlatformInfo', 'Current useAngle setting: $useAngleAndroid');
  }
}

Int32List getGLCapability(int pname, {int count = 1}) {
  final Pointer<Int32> resultPtr = calloc<Int32>(count);
  try {
    _glGetIntegerv(pname, resultPtr);
    return Int32List.fromList(resultPtr.asTypedList(count));
  } finally {
    calloc.free(resultPtr);
  }
}

void getGLExtensions() {
  final gl = M3AppEngine.instance.renderEngine.gl;
  if (!kIsWeb) {
    int numExt = gl.getIntegerv(0x821D);
    for (int i = 0; i < numExt; i++) {
      final s0 = gl.getStringi(WebGL.EXTENSIONS, i);
      M3Log.i('GLext', '$i = $s0');
    }
  }
}

// ------------------------------
// EGL function signatures
// ------------------------------
typedef EglGetCurrentDisplayC = Pointer<Void> Function();
typedef EglGetCurrentDisplayDart = Pointer<Void> Function();

typedef EglQueryStringC = Pointer<Uint8> Function(Pointer<Void> display, Int32 name);
typedef EglQueryStringDart = Pointer<Uint8> Function(Pointer<Void> display, int name);
/*
typedef _ClipControlC = Void Function(Uint32, Uint32);
typedef _ClipControlDart = void Function(int, int);
_ClipControlDart? clipControl;

void initClipControl(DynamicLibrary egl) {
  final getProc = egl.lookupFunction<Pointer<Void> Function(Pointer<Utf8>), Pointer<Void> Function(Pointer<Utf8>)>(
    'eglGetProcAddress',
  );
  // Use `using` so the native UTF-8 string is freed after the call.
  final p = using((arena) => getProc('glClipControlEXT'.toNativeUtf8(allocator: arena)));
  if (p != nullptr) {
    clipControl = p.cast<NativeFunction<_ClipControlC>>().asFunction<_ClipControlDart>();
  }
}
*/
void getEGLExtensions() {
  final eglLib = _loadEGLLib();
  if (eglLib == null) {
    M3Log.e('EGL', 'EGL library not found');
    return;
  }

  // ignore: constant_identifier_names
  const int EGL_EXTENSIONS = 0x3055;
  try {
    final EglGetCurrentDisplayDart eglGetCurrentDisplay = eglLib
        .lookup<NativeFunction<EglGetCurrentDisplayC>>('eglGetCurrentDisplay')
        .asFunction();
    final EglQueryStringDart eglQueryString = eglLib
        .lookup<NativeFunction<EglQueryStringC>>('eglQueryString')
        .asFunction();
    /*
    // clip control — must be done before eglLib.close()
    initClipControl(eglLib);
    if (clipControl != null) {
      // GL_LOWER_LEFT=0x8CA1, GL_ZERO_TO_ONE=0x935F (EXT_clip_control values)
      clipControl!(0x8CA1, 0x935F);
      M3Log.i('EGL', 'glClipControlEXT applied (lower-left, zero-to-one)');
    } else {
      M3Log.w('EGL', 'glClipControlEXT not found — clip control not applied');
    }
*/
    final display = eglGetCurrentDisplay();
    M3Log.i('EGL', 'EGL Display: $display');

    // 1. Client Extensions (Display is EGL_NO_DISPLAY = nullptr)
    final clientExtsPtr = eglQueryString(nullptr, EGL_EXTENSIONS);
    if (clientExtsPtr.address != 0) {
      M3Log.i('EGL', 'EGL Client Extensions:');
      _printExtensionList(clientExtsPtr.cast<Utf8>().toDartString());
    }

    // 2. Display Extensions
    if (display.address != 0) {
      final displayExtsPtr = eglQueryString(display, EGL_EXTENSIONS);
      if (displayExtsPtr.address != 0) {
        M3Log.i('EGL', 'EGL Display Extensions:');
        _printExtensionList(displayExtsPtr.cast<Utf8>().toDartString());
      }
    }
  } catch (e) {
    M3Log.e('EGL', 'Error querying EGL extensions: $e');
  } finally {
    eglLib.close();
  }
}

void _printExtensionList(String extensions) {
  final list = extensions.split(' ');
  for (var i = 0; i < list.length; i++) {
    final ext = list[i].trim();
    if (ext.isNotEmpty) {
      M3Log.d('EGLext', '$i = $ext');
    }
  }
}

DynamicLibrary? _loadGLESv2Lib() {
  if (Platform.isMacOS || Platform.isIOS) {
    try {
      return DynamicLibrary.open('libGLESv2.framework/libGLESv2');
    } catch (e) {
      return DynamicLibrary.open('libGLESv2');
    }
  } else if (Platform.isAndroid) {
    if (useAngleAndroid) {
      try {
        return DynamicLibrary.open('libGLESv2_angle.so');
      } catch (e) {
        // Fallback to native
        return DynamicLibrary.open('libGLESv2.so');
      }
    } else {
      return DynamicLibrary.open('libGLESv2.so');
    }
  } else if (Platform.isWindows) {
    try {
      return DynamicLibrary.open('libGLESv2.dll');
    } catch (e) {
      return DynamicLibrary.open('libGLESv2_angle.dll');
    }
  }

  return null;
}

DynamicLibrary? _loadEGLLib() {
  if (Platform.isMacOS || Platform.isIOS) {
    try {
      return DynamicLibrary.open('libEGL.framework/libEGL');
    } catch (e) {
      return DynamicLibrary.open('libEGL');
    }
  } else if (Platform.isAndroid) {
    if (useAngleAndroid) {
      try {
        return DynamicLibrary.open('libEGL_angle.so');
      } catch (e) {
        return DynamicLibrary.open('libEGL.so');
      }
    } else {
      return DynamicLibrary.open('libEGL.so');
    }
  } else if (Platform.isWindows) {
    try {
      return DynamicLibrary.open('libEGL.dll');
    } catch (e) {
      return DynamicLibrary.open('libEGL_angle.dll');
    }
  }
  return null;
}

// ------------------------------
// OpenGL function signatures
// ------------------------------
typedef GLGetStringC = Pointer<Uint8> Function(Uint32 name);
typedef GLGetStringDart = Pointer<Uint8> Function(int name);

typedef GLGetIntegervC = Void Function(Uint32 name, Pointer<Int32> data);
typedef GLGetIntegervDart = void Function(int pname, Pointer<Int32> data);
late GLGetIntegervDart _glGetIntegerv;

String safeGetString(Pointer<Uint8> ptr) {
  if (ptr.address == 0) return "Unknown";
  return ptr.cast<Utf8>().toDartString();
}

GraphicsInfo getGpuInfo() {
  if (Platform.isAndroid) {
    M3Log.i('Android GPU', 'Current useAngle setting: $useAngleAndroid');
  }

  final glesLib = _loadGLESv2Lib();
  if (glesLib == null) {
    return const GraphicsInfo(vendor: "None", renderer: "None", version: "None", shadingVersion: "None");
  }
  final GLGetStringDart glGetString = glesLib.lookup<NativeFunction<GLGetStringC>>('glGetString').asFunction();
  _glGetIntegerv = glesLib.lookup<NativeFunction<GLGetIntegervC>>('glGetIntegerv').asFunction<GLGetIntegervDart>();

  Pointer<Uint8> vendorPtr = glGetString(WebGL.VENDOR);
  Pointer<Uint8> rendererPtr = glGetString(WebGL.RENDERER);
  Pointer<Uint8> versionPtr = glGetString(WebGL.VERSION);
  Pointer<Uint8> shaderPtr = glGetString(WebGL.SHADING_LANGUAGE_VERSION);

  // 將 C 指標轉為 Dart String
  String vendor = safeGetString(vendorPtr);
  String renderer = safeGetString(rendererPtr);
  String version = safeGetString(versionPtr);
  String glslVer = safeGetString(shaderPtr);
  GraphicsInfo ret = GraphicsInfo(vendor: vendor, renderer: renderer, version: version, shadingVersion: glslVer);

  // glesLib.close();
  return ret;
}
