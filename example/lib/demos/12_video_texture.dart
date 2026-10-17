// ignore_for_file: unused_local_variable, file_names
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'demo_scene.dart';

// ignore: camel_case_types
class VideoTextureScene_12 extends DemoScene {
  M3ExternalTexture? videoTexture;
  M3ExternalTexture? videoTexture2;

  M3Entity? videoEntity;
  M3Entity? videoEntity2;
  final GlobalKey repaintKey = GlobalKey();

  final ValueNotifier<double> _progress = ValueNotifier(0.0);
  bool _isDragging = false;

  @override
  Future<void> load() async {
    if (isLoaded) return;
    await super.load();

    dirLight.lightViewer.setEuler(pi / 4, -pi / 4, 0);

    final video480 = 'assets/example/big-buck-bunny-480p-30sec.mp4';
    final video1080 = 'assets/example/big-buck-bunny-1080p-30sec.mp4';
    final video60fps = 'assets/example/big-buck-bunny-1080p-60fps-30sec.mp4';
    final web1 = 'https://www.w3schools.com/tags/mov_bbb.mp4';
    final web2 = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
    // Initial video source
    videoTexture2 = await M3ExternalTexture.createVideo(web1);
    videoTexture = await M3ExternalTexture.createVideo(web2);

    if (videoTexture != null) {
      videoTexture!.repaintKey = repaintKey;
    }

    // add plane to show video
    final planeMesh = M3Mesh(M3PlaneGeom(8, 4.5, uvScale: Vector2.all(1.0)));
    if (videoTexture != null) {
      planeMesh.subMeshes[0].mtr.diffuseTexture = videoTexture!;
    }

    final planeMesh2 = M3Mesh(M3PlaneGeom(10.66, 6, uvScale: Vector2.all(1.0)));
    if (videoTexture2 != null) {
      planeMesh2.subMeshes[0].mtr.diffuseTexture = videoTexture2!;
    }

    // 01: box geometry
    addMesh(M3Mesh(M3Resources.unitSphere), Vector3(1, 0, 2));

    videoEntity = addMesh(planeMesh, Vector3.zero());
    videoEntity2 = addMesh(planeMesh2, Vector3(0, 3, 3));
    videoEntity2!.rotation = Quaternion.axisAngle(Vector3(1, 0, 0), pi / 2);
    if (videoTexture == null) {
      videoEntity!.color = Vector4(0.8, 0.2, 0.2, 1); // Reddish if no video
    } else {}
  }

  @override
  Widget buildUI(BuildContext context) {
    final videoElement = videoTexture?.source;
    final videoWidth = videoTexture?.texW ?? 480;
    final videoHeight = videoTexture?.texH ?? 270;
    return Stack(
      children: [
        if (!kIsWeb)
          // On Native platforms, we use a RepaintBoundary to capture video frames for the texture.
          // Important: The widget must be part of the layout tree to be captured by toImage().
          // We position it far off-screen so it's not visible to the user while still being painted.
          Positioned(
            left: -2000, // Move far off screen to avoid being visible
            top: 0,
            child: RepaintBoundary(
              key: repaintKey,
              child: SizedBox(
                width: videoWidth.toDouble(),
                height: videoHeight.toDouble(),
                child: videoElement is VideoPlayerController ? VideoPlayer(videoElement) : const SizedBox.shrink(),
              ),
            ),
          ),

        // Video Controls UI (Visible on both Web and Native)
        Positioned(
          left: 20,
          top: 20, // Positioned above the scene switcher
          child: Row(
            children: [
              StatefulBuilder(
                builder: (context, setState) {
                  final bool isPlaying = videoTexture?.isPlaying ?? false;
                  return FloatingActionButton(
                    heroTag: 'video_play_pause',
                    backgroundColor: Colors.black54,
                    onPressed: () {
                      if (isPlaying) {
                        videoTexture?.pause();
                      } else {
                        videoTexture?.play();
                      }
                      setState(() {}); // Update local button state
                    },
                    child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  );
                },
              ),
              const SizedBox(width: 10),
              FloatingActionButton(
                heroTag: 'video_reset',
                backgroundColor: Colors.black54,
                onPressed: () {
                  videoTexture?.seekTo(Duration.zero);
                },
                child: const Icon(Icons.replay, color: Colors.white),
              ),
              const SizedBox(width: 10),
              // Playback Slider
              SizedBox(
                width: 200,
                child: ValueListenableBuilder<double>(
                  valueListenable: _progress,
                  builder: (context, value, child) {
                    return SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        activeTrackColor: Colors.lightGreen,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.lightGreenAccent,
                      ),
                      child: Slider(
                        value: value.clamp(0.0, 1.0),
                        onChanged: (newValue) {
                          _isDragging = true;
                          _progress.value = newValue;
                        },
                        onChangeEnd: (newValue) async {
                          final duration = await videoTexture?.getDuration();
                          if (duration != null) {
                            videoTexture?.seekTo(duration * newValue);
                          }
                          _isDragging = false;
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void update(double delta) {
    super.update(delta);

    videoTexture?.update();
    videoTexture2?.update();

    // Rotate the cube slowly
    if (videoEntity != null) {
      // videoEntity!.rotation = videoEntity!.rotation * Quaternion.axisAngle(Vector3(0, 1, 0), delta * 0.5);
    }

    _updateProgress();
  }

  Future<void> _updateProgress() async {
    if (_isDragging || videoTexture == null) return;

    final duration = await videoTexture!.getDuration();
    final position = await videoTexture!.getPosition();

    if (duration != null && position != null && duration.inMilliseconds > 0) {
      _progress.value = (position.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
    }
  }
}
