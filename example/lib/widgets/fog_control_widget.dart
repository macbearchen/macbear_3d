import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import 'package:macbear_3d/macbear_3d.dart';

/// Fog & auxiliary lighting controls toolbar (Fog toggle & density slider, Point Lights, Spot Lights)
class M3FogControlWidget extends StatefulWidget {
  const M3FogControlWidget({super.key});

  @override
  State<M3FogControlWidget> createState() => _M3FogControlWidgetState();
}

class _M3FogControlWidgetState extends State<M3FogControlWidget> {
  static const separateWidget = SizedBox(width: 2, height: 2);

  @override
  void initState() {
    super.initState();
    M3AppEngine.instance.addListener(_onEngineChanged);
  }

  @override
  void dispose() {
    M3AppEngine.instance.removeListener(_onEngineChanged);
    super.dispose();
  }

  void _onEngineChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final shaderOptions = renderEngine.options.shader;
    final scene = M3AppEngine.instance.activeScene;
    if (scene == null) return const SizedBox.shrink();

    final far = scene.camera.farClip;
    final fogStartPct = far > 0 ? (scene.fog.start / far * 100.0).clamp(10.0, 95.0) : 10.0;
    final lightBrightness = ((scene.dirLight.color.x + scene.dirLight.color.y + scene.dirLight.color.z) / 3.0).clamp(
      0.0,
      1.0,
    );
    final ambientBrightness = ((M3Light.ambient.x + M3Light.ambient.y + M3Light.ambient.z) / 3.0).clamp(0.0, 1.0);
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shaderOptions.fog) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "fog=${fogStartPct.toStringAsFixed(0)}%",
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                  SizedBox(
                    width: 50,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                      ),
                      child: Slider(
                        value: fogStartPct,
                        min: 10.0,
                        max: 95.0,
                        activeColor: Colors.lime,
                        inactiveColor: Colors.white24,
                        onChanged: (val) {
                          setState(() {
                            final far = scene.camera.farClip;
                            final depthPct = min(100.0 - val, 25.0);
                            scene.fog.start = far * (val / 100.0);
                            scene.fog.depth = far * (depthPct / 100.0);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          FloatingActionButton.small(
            heroTag: 'fog',
            backgroundColor: shaderOptions.fog ? Colors.lime : null,
            onPressed: () {
              setState(() {
                shaderOptions.fog = !shaderOptions.fog;
              });
            },
            child: Icon(shaderOptions.fog ? Icons.cloud : Icons.cloud_queue),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'point_lights',
            backgroundColor: shaderOptions.pointLights ? Colors.amber : null,
            onPressed: () {
              setState(() {
                shaderOptions.pointLights = !shaderOptions.pointLights;
              });
            },
            child: const Icon(Icons.lightbulb_circle),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'spot_lights',
            backgroundColor: shaderOptions.spotLights ? Colors.amber : null,
            onPressed: () {
              setState(() {
                shaderOptions.spotLights = !shaderOptions.spotLights;
              });
            },
            child: const Icon(Icons.highlight),
          ),
          separateWidget,
          // ── Directional light color slider ──
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u2600', style: TextStyle(fontSize: 10, color: Colors.amber)),
                SizedBox(
                  width: 50,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 4),
                    ),
                    child: Slider(
                      value: lightBrightness,
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.amber,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        setState(() {
                          scene.dirLight.color = Vector3.all(val);
                        });
                      },
                    ),
                  ),
                ),
                Text(lightBrightness.toStringAsFixed(2), style: const TextStyle(fontSize: 9, color: Colors.white70)),
              ],
            ),
          ),
          separateWidget,
          // ── Ambient light color slider ──
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wb_twilight, size: 10, color: Colors.lightBlueAccent),
                SizedBox(
                  width: 50,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 4),
                    ),
                    child: Slider(
                      value: ambientBrightness,
                      min: 0.0,
                      max: 1.0,
                      activeColor: Colors.lightBlueAccent,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        setState(() {
                          M3Light.ambient = Vector3.all(val);
                        });
                      },
                    ),
                  ),
                ),
                Text(ambientBrightness.toStringAsFixed(2), style: const TextStyle(fontSize: 9, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
