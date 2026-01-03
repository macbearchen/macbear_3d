#!/bin/bash

# 定義要忽略的路徑（正則表達式）
# dcdg 比對的是 package URI (例如 package:macbear_3d/src/...)，而非檔案系統路徑 (lib/src/...)
EXCLUDE="package:macbear_3d/src/(shaders|2d|builder|example|shaders_gen)/.*|.*\.g\.dart"

echo "正在產生 Macbear 3D 類別圖..."

dart pub global run dcdg \
  --output=uml/macbear_3d.puml \
  --exclude="$EXCLUDE" \
  --search-path=lib/src

echo "產生完成！檔案儲存於 uml/macbear_3d.puml"