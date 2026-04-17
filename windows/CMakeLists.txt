cmake_minimum_required(VERSION 3.14)
project(macbear_3d_plugin LANGUAGES CXX)

add_library(${PROJECT_NAME} SHARED
  "m3_video_bridge_plugin.cpp"
  "m3_video_bridge_plugin.h"
  "m3_video_bridge_plugin_c_api.cpp"
)

apply_standard_settings(${PROJECT_NAME})

target_compile_definitions(${PROJECT_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PROJECT_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PROJECT_NAME} PRIVATE flutter flutter_wrapper_plugin)

# List of absolute paths to libraries that should be copied to the output directory.
set(macbear_3d_plugin_bundled_libraries
  ""
  PARENT_SCOPE
)
