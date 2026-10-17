import 'package:material_ui/material_ui.dart';
import 'package:macbear_3d/macbear_3d.dart';

/// Shader controls toolbar (CSM, Shadow, PCF, CSM FS/VS, Per-Pixel, Toon, PBR, IBL)
class M3ShaderControlWidget extends StatefulWidget {
  final void Function(int mode)? onShadowModeChanged;

  const M3ShaderControlWidget({super.key, this.onShadowModeChanged});

  @override
  State<M3ShaderControlWidget> createState() => _M3ShaderControlWidgetState();
}

class _M3ShaderControlWidgetState extends State<M3ShaderControlWidget> {
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

  void _updateShadowMode(int mode) {
    if (widget.onShadowModeChanged != null) {
      widget.onShadowModeChanged!(mode);
    } else {
      final renderEngine = M3AppEngine.instance.renderEngine;
      final scene = M3AppEngine.instance.activeScene;
      if (scene == null) return;

      final bool enableShadow = mode >= 0;
      renderEngine.options.useShadow = enableShadow;

      if (enableShadow) {
        final csm = mode.clamp(0, 4);
        scene.camera.csmCount = csm;
        renderEngine.options.shader.csmCount = csm;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final shaderOptions = renderEngine.options.shader;
    final scene = M3AppEngine.instance.activeScene;
    final csmCount = scene?.camera.csmCount ?? 0;

    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (scene != null && renderEngine.options.useShadow) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "CSM=$csmCount",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 56,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                      ),
                      child: Slider(
                        value: csmCount.toDouble().clamp(0.0, 4.0),
                        min: 0,
                        max: 4,
                        divisions: 4,
                        activeColor: Colors.amber,
                        inactiveColor: Colors.white24,
                        onChanged: (val) {
                          setState(() {
                            _updateShadowMode(val.toInt());
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            separateWidget,
          ],
          FloatingActionButton.small(
            heroTag: 'shadow',
            backgroundColor: renderEngine.options.useShadow ? Colors.tealAccent.shade700 : null,
            onPressed: () {
              setState(() {
                if (renderEngine.options.useShadow) {
                  _updateShadowMode(-1); // turn off
                } else {
                  _updateShadowMode(scene?.camera.csmCount ?? 4); // turn on with current or default csm
                }
              });
            },
            child: Icon(renderEngine.options.useShadow ? Icons.light_mode : Icons.light_mode_outlined),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'pcf',
            backgroundColor: shaderOptions.pcf > 0 ? Colors.amber : null,
            onPressed: () {
              setState(() {
                shaderOptions.pcf = (shaderOptions.pcf + 1) % 4;
              });
            },
            child: Text('PCF ${shaderOptions.pcf}', style: const TextStyle(fontSize: 10)),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'csm_vs_fs',
            backgroundColor: shaderOptions.csmOnFS ? Colors.amber : null,
            onPressed: () {
              setState(() {
                shaderOptions.csmOnFS = !shaderOptions.csmOnFS;
              });
            },
            child: Text(shaderOptions.csmOnFS ? 'CSM FS' : 'CSM VS', style: const TextStyle(fontSize: 10)),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'per_pixel',
            backgroundColor: shaderOptions.perPixel ? Colors.amber : null,
            onPressed: () {
              setState(() {
                shaderOptions.perPixel = !shaderOptions.perPixel;
              });
            },
            child: const Icon(Icons.draw),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'cartoon',
            backgroundColor: shaderOptions.cartoon ? Colors.amber : null,
            onPressed: () {
              setState(() {
                shaderOptions.cartoon = !shaderOptions.cartoon;
              });
            },
            child: const Text('toon'),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'pbr',
            backgroundColor: shaderOptions.pbr ? Colors.amber : null,
            onPressed: () {
              setState(() {
                shaderOptions.pbr = !shaderOptions.pbr;
              });
            },
            child: const Text('PBR'),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'ibl',
            backgroundColor: shaderOptions.ibl ? Colors.amber : null,
            onPressed: () {
              setState(() {
                shaderOptions.ibl = !shaderOptions.ibl;
              });
            },
            child: const Text('IBL'),
          ),
        ],
      ),
    );
  }
}
