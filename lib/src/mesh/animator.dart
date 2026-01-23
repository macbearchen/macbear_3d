import 'dart:math';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import '../gltf/gltf_parser.dart';

/// Handles skeletal animation playback and keyframe interpolation.
class M3Animator {
  final List<GltfAnimation> animations;
  final Map<int, GltfNode> nodes; // target node index to node

  int _currentAnimationIndex = 0;
  double _currentTime = 0.0;
  bool isPlaying = false;
  bool loop = true;

  M3Animator(this.animations, this.nodes);

  void play(int index) {
    _currentAnimationIndex = index;
    _currentTime = 0.0;
    isPlaying = true;
  }

  void update(double deltaTime) {
    if (animations.isEmpty) {
      _updateHierarchy();
      return;
    }

    if (isPlaying) {
      final anim = animations[_currentAnimationIndex];
      _currentTime += deltaTime;

      // Get max duration
      double maxTime = 0;
      for (final sampler in anim.samplers) {
        final inputs = sampler.getInputs();
        if (inputs.isNotEmpty && inputs.last > maxTime) {
          maxTime = inputs.last;
        }
      }

      if (_currentTime > maxTime) {
        if (loop) {
          _currentTime %= maxTime;
        } else {
          _currentTime = maxTime;
          isPlaying = false;
        }
      }

      // Apply channels
      for (final channel in anim.channels) {
        if (channel.targetNodeIndex == null) continue;
        final node = nodes[channel.targetNodeIndex!];
        if (node == null) continue;

        final sampler = anim.samplers[channel.samplerIndex];
        _applySampler(node, sampler, channel.targetPath, _currentTime);
      }
    }

    _updateHierarchy();
  }

  void _updateHierarchy() {
    if (nodes.isEmpty) return;
    final doc = nodes.values.first.document;
    final identity = Matrix4.identity();
    for (final rootIndex in doc.rootNodes) {
      doc.nodes[rootIndex].computeWorldMatrix(identity);
    }
  }

  void _applySampler(GltfNode node, GltfAnimationSampler sampler, String path, double time) {
    final times = sampler.getInputs();
    final values = sampler.getOutputs();

    if (times.isEmpty) return;

    // Find keyframe interval
    int prevIndex = 0;
    int nextIndex = 0;
    for (int i = 0; i < times.length - 1; i++) {
      if (time >= times[i] && time <= times[i + 1]) {
        prevIndex = i;
        nextIndex = i + 1;
        break;
      }
    }

    // If time is beyond last keyframe
    if (time >= times.last) {
      prevIndex = nextIndex = times.length - 1;
    }

    double t = 0.0;
    if (prevIndex != nextIndex) {
      t = (time - times[prevIndex]) / (times[nextIndex] - times[prevIndex]);
    }

    if (path == 'translation') {
      final v1 = _getVector3(values, prevIndex);
      final v2 = _getVector3(values, nextIndex);
      node.translation.setValues(v1.x + (v2.x - v1.x) * t, v1.y + (v2.y - v1.y) * t, v1.z + (v2.z - v1.z) * t);
    } else if (path == 'rotation') {
      final q1 = _getQuaternion(values, prevIndex);
      final q2 = _getQuaternion(values, nextIndex);

      // Manual Slerp
      double dot = q1.x * q2.x + q1.y * q2.y + q1.z * q2.z + q1.w * q2.w;

      if (dot < 0.0) {
        q2.scale(-1.0);
        dot = -dot;
      }

      if (dot > 0.9995) {
        // NLerp
        node.rotation.setValues(
          q1.x + (q2.x - q1.x) * t,
          q1.y + (q2.y - q1.y) * t,
          q1.z + (q2.z - q1.z) * t,
          q1.w + (q2.w - q1.w) * t,
        );
      } else {
        double angle = acos(dot);
        double sinTotal = sin(angle);
        double ratioA = sin((1 - t) * angle) / sinTotal;
        double ratioB = sin(t * angle) / sinTotal;
        node.rotation.setValues(
          q1.x * ratioA + q2.x * ratioB,
          q1.y * ratioA + q2.y * ratioB,
          q1.z * ratioA + q2.z * ratioB,
          q1.w * ratioA + q2.w * ratioB,
        );
      }
      node.rotation.normalize();
    } else if (path == 'scale') {
      final v1 = _getVector3(values, prevIndex);
      final v2 = _getVector3(values, nextIndex);
      node.scale.setValues(v1.x + (v2.x - v1.x) * t, v1.y + (v2.y - v1.y) * t, v1.z + (v2.z - v1.z) * t);
    }
  }

  Vector3 _getVector3(Float32List list, int index) {
    return Vector3(list[index * 3], list[index * 3 + 1], list[index * 3 + 2]);
  }

  Quaternion _getQuaternion(Float32List list, int index) {
    return Quaternion(list[index * 4], list[index * 4 + 1], list[index * 4 + 2], list[index * 4 + 3]);
  }
}
