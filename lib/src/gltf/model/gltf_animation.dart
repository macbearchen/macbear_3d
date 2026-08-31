import 'dart:typed_data';
import '../gltf_document.dart';

/// glTF Animation
class GltfAnimation {
  final GltfDocument document;
  final String name;
  final List<GltfAnimationChannel> channels;
  final List<GltfAnimationSampler> samplers;

  GltfAnimation({
    required this.document,
    required this.name,
    required this.channels,
    required this.samplers,
  });

  static GltfAnimation parse(GltfDocument doc, Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Animation';

    final samplerList = json['samplers'] as List<dynamic>? ?? [];
    final samplers = samplerList.map((e) => GltfAnimationSampler.parse(doc, e as Map<String, dynamic>)).toList();

    final channelList = json['channels'] as List<dynamic>? ?? [];
    final channels = channelList.map((e) => GltfAnimationChannel.parse(doc, e as Map<String, dynamic>)).toList();

    return GltfAnimation(document: doc, name: name, channels: channels, samplers: samplers);
  }
}

/// glTF Animation Channel
class GltfAnimationChannel {
  final GltfDocument document;
  final int samplerIndex;
  final int? targetNodeIndex;
  final String targetPath; // "translation", "rotation", "scale", "weights"

  GltfAnimationChannel({
    required this.document,
    required this.samplerIndex,
    this.targetNodeIndex,
    required this.targetPath,
  });

  static GltfAnimationChannel parse(GltfDocument doc, Map<String, dynamic> json) {
    final target = json['target'] as Map<String, dynamic>;
    return GltfAnimationChannel(
      document: doc,
      samplerIndex: json['sampler'] as int,
      targetNodeIndex: target['node'] as int?,
      targetPath: target['path'] as String,
    );
  }
}

/// glTF Animation Sampler
class GltfAnimationSampler {
  final GltfDocument document;
  final int inputAccessor; // time
  final int outputAccessor; // values (TRS)
  final String interpolation; // "LINEAR", "STEP", "CUBICSPLINE"

  GltfAnimationSampler({
    required this.document,
    required this.inputAccessor,
    required this.outputAccessor,
    required this.interpolation,
  });

  static GltfAnimationSampler parse(GltfDocument doc, Map<String, dynamic> json) {
    return GltfAnimationSampler(
      document: doc,
      inputAccessor: json['input'] as int,
      outputAccessor: json['output'] as int,
      interpolation: json['interpolation'] as String? ?? 'LINEAR',
    );
  }

  Float32List getInputs() => document.getFloatAccessor(inputAccessor);
  Float32List getOutputs() => document.getFloatAccessor(outputAccessor);
}
