import 'dart:async';
import 'package:build/build.dart';

class ShaderBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.vert': ['.vert.dart'],
    '.frag': ['.frag.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final contents = await buildStep.readAsString(inputId);
    final escaped = _escapeDartString(contents);

    final outputId = inputId.changeExtension('.dart');

    final name = _makeConstName(inputId.path);

    final output =
        '''
// Generated file – do not edit.
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
