#!/bin/bash

# 定義要忽略的路徑（正則表達式）
# dcdg 比對的是 package URI (例如 package:macbear_3d/src/...)，而非檔案系統路徑 (lib/src/...)
EXCLUDE="package:macbear_3d/src/(shaders|2d|builder|example|shaders_gen)/.*|.*\.g\.dart"

# 暫存備份檔案，避免 dcdg 分析時因 FFI 註解（如 @Int32、@Uint32、@Array）與 @visibleForTesting 在舊版 analyzer 中崩潰
VULKAN_FILE="lib/src/util/platform/platform_info_vulkan.dart"
CHANNEL_FILE="lib/src/video_bridge/m3_video_bridge_method_channel.dart"

VULKAN_BAK="${VULKAN_FILE}.bak"
CHANNEL_BAK="${CHANNEL_FILE}.bak"

# 確保在指令碼結束或中斷時，回復原始檔案
cleanup() {
  if [ -f "$VULKAN_BAK" ]; then
    mv "$VULKAN_BAK" "$VULKAN_FILE"
  fi
  if [ -f "$CHANNEL_BAK" ]; then
    mv "$CHANNEL_BAK" "$CHANNEL_FILE"
  fi
}
trap cleanup EXIT INT TERM

# 備份檔案
cp "$VULKAN_FILE" "$VULKAN_BAK"
cp "$CHANNEL_FILE" "$CHANNEL_BAK"

# 註解掉會造成舊版 analyzer 崩潰的欄位 Annotation
sed -i '' -E 's/^[[:space:]]*@(Int32\(\)|Uint32\(\)|Array\([0-9]+\))/\/\/ &/' "$VULKAN_FILE"
sed -i '' -E 's/^[[:space:]]*@visibleForTesting/\/\/ &/' "$CHANNEL_FILE"

echo "正在產生 Macbear 3D 類別圖..."

dart pub global run dcdg \
  --output=uml/macbear_3d.puml \
  --exclude="$EXCLUDE" \
  --search-path=lib/src

echo "產生完成！檔案儲存於 uml/macbear_3d.puml"