import 'dart:async';
import 'package:build/build.dart';

/// @nodoc
class ShaderBuilder implements Builder {
  @override
  final buildExtensions = const {
    '^lib/src/shaders/{{}}.vert': ['lib/src/shaders_gen/{{}}.vert.g.dart'],
    '^lib/src/shaders/{{}}.frag': ['lib/src/shaders_gen/{{}}.frag.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final contents = await buildStep.readAsString(inputId);
    final escaped = _escapeDartString(contents);

    // Calculate output path: replace 'lib/src/shaders' with 'lib/src/shaders_gen'
    // and append '.g.dart'
    String newPath = inputId.path.replaceFirst('lib/src/shaders', 'lib/src/shaders_gen');
    newPath += '.g.dart';
    final outputId = AssetId(inputId.package, newPath);

    final name = _makeConstName(inputId.path);

    final output =
        '''
// Generated file – do not edit.
// ignore: constant_identifier_names
const String $name = r"""
$escaped
""";
''';

    await buildStep.writeAsString(outputId, output);
  }

  String _escapeDartString(String input) {
    return input.replaceAll(r'$', r'\$');
  }

  String _makeConstName(String path) {
    return path.split('/').last.replaceAll('.', '_').replaceAll('-', '_');
  }
}

Builder shaderBuilder(BuilderOptions options) => ShaderBuilder();
