//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_angle/flutter_angle_plugin.h>
#include <macbear_3d/m3_video_bridge_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterAnglePluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterAnglePlugin"));
  M3VideoBridgePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("M3VideoBridgePluginCApi"));
}
