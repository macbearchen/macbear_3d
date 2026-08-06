# Terrain Tile LOD Seam Stitching — Implementation Spec

## 目標

解決地形 tile 系統中,相鄰 tile LOD 等級不同時產生的接縫縫隙(crack)問題。針對 LOD1~LOD3(非最高精度層級),採用 **Inner + Edge + Corner** 拆分方案,將單一 tile 的 index buffer 生成邏輯拆解為可組合的模板單元,涵蓋所有鄰居 LOD 組合情況。LOD0(最高精度)不執行此邏輯,見「責任歸屬的實務影響」章節。

## 前提與約束

- **硬性規則**:相鄰 tile 的 LOD 等級差距最多 1 級(不允許跳級)。此規則是本方案所有拓樸推導的數學基礎,若日後移除此限制,corner 變體數量需重新推導。
- **責任歸屬規則(重要)**:縫合責任固定由**低精度側**承擔。高精度 tile(如 32×32 segments)永遠維持標準均勻網格,不因鄰居精度而改變自身 index buffer;需要調整拓樸、插入對齊頂點的一律是**低精度側**(如 16×16 segments)。這與部分文獻中「高精度側跳點收斂」的做法相反,採此方向的理由是讓高精度 tile(通常也是最靠近攝影機、最常被使用的層級)保持最簡單、可預測的均勻網格,複雜度集中吸收在使用頻率較低的粗糙層級。
- Tile 內部使用固定 segment 數(例:32×32 segments,33×33 vertices)。
- 使用 CPU-side index offset 搭配共享 IBO 的策略(`glDrawElementsBaseVertex` 在 WebGL 規範層級不可用,不可依賴)。
- 本方案已確認適用於全部 4 級 LOD(32×32 / 16×16 / 8×8 / 4×4),詳見「LOD 層級與 Segment 數規劃」章節。

## 架構總覽

每個 tile 的 index buffer 由以下 5 種基礎模板組合而成:

| 模板 | 數量 | 用途 |
|---|---|---|
| Inner | 1 | Tile 中心核心區域,固定不變,不受鄰居 LOD 影響 |
| Edge - match | 1 | 本側邊界與鄰居同精度時的標準連接 |
| Edge - stitch | 1 | 本側邊界比鄰居低一級精度時,在自身邊界插入額外頂點以對齊鄰居的高精度邊界 |
| Corner - single-stitch | 1 | 該角落兩條邊中恰有一條 stitch |
| Corner - double-stitch | 1 | 該角落兩條邊皆為 stitch |

Corner 若兩條邊皆為 match,無需特殊模板,直接沿用 inner/edge 交界處的標準拓樸即可。

透過 90°/180°/270° 旋轉與鏡射,上述 5 份模板可套用到 4 個方向(N/E/S/W)與 4 個角落(NE/NW/SE/SW),覆蓋全部 2⁴ = 16 種鄰居 LOD 組合,不需要為每個方向/角落各自準備獨立資料。

## 座標系統與分區定義

假設 tile 為 N×N segments((N+1)×(N+1) vertices),vertex index 範圍為 `[0, N] × [0, N]`,border strip 寬度固定為 **1 個 segment**。以下分區依**三角形歸屬**劃分,而非僅依頂點位置劃分 —— 三個區域彼此不重疊,每一個三角形只屬於其中一個區域,即使區域邊界會共用「頂點位置」,也絕不會共用「三角形」:

- **Inner 區域**:三角形完全落在 `[1, N-1] × [1, N-1]` 範圍內的核心網格。
- **Corner 區域**:四個角落固定的 2×2 頂點區塊(例如 NW 角為 `{0,1} × {0,1}`),**獨立擁有**該區塊內的三角形三角化。Corner 的範圍**不外溢**到與其相鄰的 edge 段落。
- **Edge 區域**:四條邊各自扣除頭尾各一個角落區塊後,剩餘的一段。例如 N 側(頂端一整條)的角落區塊為 NW(佔 `x ∈ [0,1]`)與 NE(佔 `x ∈ [N-1,N]`),則 Edge-N 只負責中間 `x ∈ [1, N-1]` 這一段的三角化(共 N−2 個 segment 寬),兩端各留給 NW / NE corner 區域處理,**不得跨入角落的 2×2 範圍**。

因此 Edge 模板的三角化長度並非「整條邊」,而是「整條邊扣掉兩端各 1 個 segment 寬的角落區塊」之後的中間段。旋轉套用到 4 個方向時,此扣除規則同樣適用。

Inner segment 數 = N − 2。此值必須 ≥ 2 才能保證 inner 區域是有效面積的網格(見已知限制)。

## 各模板生成規則

### 1. Inner 模板

標準 grid 三角化,tessellation 方向建議統一(例如固定切法,如 `(i,j)-(i+1,j)-(i,j+1)` / `(i+1,j)-(i+1,j+1)-(i,j+1)`),避免與 edge 交界處產生法線不連續。

### 2. Edge - Match 模板

該側邊界頂點密度與 inner 銜接處一致,逐一頂點正常連接,無跳點。

### 3. Edge - Stitch 模板

本 tile 該側為**低精度**(N segments),鄰居為高一級精度(等效 2N segments)。做法:

- 低精度側原本邊界頂點序列為 `v0, v1, v2, ..., vN`,對應鄰居高精度側的邊界頂點序列為 `v0, v0.5, v1, v1.5, ..., vN`(鄰居在每兩個低精度頂點之間多一個中點)
- 在低精度側的邊界三角化中,針對每一段 `vi → vi+1`,額外插入對齊鄰居中點位置的頂點 `vi+0.5`,並用兩個三角形(而非原本一個)填補該段,讓邊界頂點密度與鄰居一致
- **三角化方式必須採用對稱分裂,不可用單點發散(fan)方式**:插入 `vi+0.5` 後,應以 `vi+0.5` 為分裂點,分別連向 `vi`、`vi+1`,以及 inner 側對應的內部頂點,形成兩個長寬比相近的三角形;不可把 `vi+0.5` 與 `vi`、`vi+1` 都硬連到同一個既有角點或內部頂點上形成扇形發散。原因是 edge 是接縫最容易被玩家視線注意到的狹長帶狀區域,單點發散會在此處產生細長型三角形(sliver triangle),法線插值誤差被放大,即使幾何縫隙已消除,仍可能在 LOD 邊界看到不自然的明暗細線。
- `vi+0.5` 的高度取樣:直接沿用鄰居高精度側該中點位置的實際高度(對齊鄰居的真實資料),而非用 `vi` 與 `vi+1` 線性內插 —— 若用內插,遇到地形起伏較大處仍可能與鄰居產生微小高度差縫隙
- 插入 `vi+0.5` 後與低精度側 inner 區域的連接處,需額外一圈三角形將這些新頂點與 inner 網格正確縫合(而非只改動最外圈,inner 與此新邊界之間也需要重新三角化銜接),此處銜接同樣遵循對稱分裂原則

> 這代表低精度 tile 的邊界處,實際頂點數與三角形數會比其原生 N segments 情況下更多(邊界那一圈局部提升到鄰居的精度)。需確認 index buffer 容量與 draw call 的頂點上限規劃是否已涵蓋這個局部增量。

### 4. Corner - Single-Stitch 模板

該角落相鄰兩條邊,其中一條 match、一條 stitch。三角化需在角落頂點處做非對稱處理,讓 stitch 側的扇形收斂與 match 側的標準連接在角落頂點平滑交會,不產生 T-junction。

**同樣禁止從單一角點大量扇形發散**:角落頂點(corner vertex)最多只連出 2 條線(對應該角落 2×2 區塊的兩個外側邊)。stitch 側新插入的對齊頂點(`vi+0.5`)**不應**直接連回角落頂點形成第 3、4 條發散線,而應在區塊內部額外插入一個獨立的分裂點,由該分裂點去銜接對齊頂點與 match 側的邊界,將複雜度局部吸收在這個內部三角形中,而不是集中到角落頂點上。理由與 Edge-Stitch 相同:角落是三個模板交會處,更容易出現多條線擠在同一點的情況,若不加限制,產生的細長三角形(sliver)會比 edge 中段更明顯。

需準備此模板的鏡射版本(因為「哪一側是 stitch」有兩種可能:左側 stitch / 右側 stitch),可用單一模板配合鏡射變換取得。

### 5. Corner - Double-Stitch 模板

該角落相鄰兩條邊皆為 stitch(代表本 tile 在此角落的兩個方向鄰居都比自己高一級精度)。兩側各自插入的對齊頂點,在角落處需交會處理,避免產生重複頂點或退化三角形。由於限制在 1 級差,此組合在拓樸上必為可解狀態,不會出現無法三角化的病態情況。

**角落頂點連線數限制同樣適用**:即使兩側都需要插入對齊頂點,角落頂點仍只連出 2 條線。兩側各自的對齊頂點改為連向區塊內部的獨立分裂點(而非都連回角落頂點),分裂點再各自連向兩側的對齊頂點與 inner 區域,形成類似「風箏」而非「扇形」的三角化分布,確保三角形長寬比不會因為雙側同時 stitch 而更加惡化。

## 组合決策表

對每個 tile,依照四個方向的鄰居 LOD 比較結果(自身 vs 鄰居,只會是「同級」或「自身高一級」兩種狀態,因 1 級差限制),決定：

```
for each direction in [N, E, S, W]:
    edge_state[direction] = STITCH if self_lod > neighbor_lod else MATCH
    # self_lod > neighbor_lod 表示自身精度較低(segment 數較少)，需插點對齊鄰居
    # self_lod < neighbor_lod（自身較高精度）一律 MATCH，不做任何調整

for each corner in [NE, NW, SE, SW]:
    edge_a, edge_b = 該 corner 相鄰的兩個 edge_state
    if edge_a == MATCH and edge_b == MATCH:
        corner_template[corner] = NONE  # 沿用標準交界，無需特殊模板
    elif edge_a == STITCH and edge_b == STITCH:
        corner_template[corner] = DOUBLE_STITCH
    else:
        corner_template[corner] = SINGLE_STITCH  # 需標記哪一側是 stitch，供鏡射方向判斷
```

最終 tile 的完整 index list = Inner + 4×(對應 edge 模板,套用旋轉) + 4×(對應 corner 模板或標準交界,套用旋轉/鏡射),透過 CPU-side vertex index offset 串接成單一 index buffer,維持單一 draw call。

## 責任歸屬的實務影響

- **32×32(最高精度,LOD0)tile 永遠不需要執行本文件描述的 stitching 邏輯**,其 index buffer 固定為標準均勻網格,無論鄰居是否為較低精度。
- **LOD0 不需要 Inner/Edge/Corner 拆分**:由於 LOD0 永遠不做 stitch,「往內縮一圈作為 border strip、剩餘核心當 inner」這個概念對 LOD0 沒有意義。LOD0 的 index buffer 應是**單一整塊均勻網格模板**,一次生成、不分區塊,不套用本文件其餘章節描述的模板組合邏輯。
- 只有 **LOD1~LOD3**(16×16、8×8、4×4)才需要 Inner/Edge/Corner 拆分,因為它們才需要判斷「自己是否比某方向鄰居精度低」,並在對應邊界插入對齊頂點。
- 因此「架構總覽」與「座標系統與分區定義」章節描述的 5 模板架構,實作範圍僅限 LOD1~LOD3;LOD0 走獨立、更簡單的單一均勻網格生成路徑。這對效能也有利,因為 LOD0 通常數量多、是最常見的常駐渲染負擔,可省去分區判斷開銷。

## LOD 層級與 Segment 數規劃(已確定)

| LOD | Segment 數 (N) | Vertices per side (N+1) | Inner segment 數 (N−2) |
|---|---|---|---|
| LOD 0 | 32×32 | 33 | 30 |
| LOD 1 | 16×16 | 17 | 14 |
| LOD 2 | 8×8 | 9 | 6 |
| LOD 3(最低,地板) | 4×4 | 5 | 2 |

- 共 4 級 LOD,最低精度為 **N = 4**,對應 Inner segment 數 = 2,恰好滿足「Inner segment 數 ≥ 2」的拓樸約束下限,不會再往下觸及 2×2 / 1×1 的病態退化情況。
- 因此**不需要**為過低 segment 數的 tile 額外設計「寫死固定網格」或「合併多個 tile 為邏輯 tile」的例外分支(先前「已知限制」章節中列出的兩種因應方案,目前可視為不必實作)。
- LOD 0(32×32)依「責任歸屬規則」永遠不執行 stitch;LOD 1~3 皆需依鄰居 LOD 判斷是否插入對齊頂點。

## 已知限制

- **Inner segment 數(N−2)須 ≥ 2**。此約束僅適用於 LOD1~LOD3(需拆分 Inner/Edge/Corner 的層級)。已確認的 LOD 規劃(32→16→8→4)中最低層級 N=4 恰好等於此下限,不會違反此約束,因此本方案的拓樸假設在目前規劃下全程有效,不需要額外的邊界情況處理(先前考慮過的「寫死固定網格」或「合併多個 tile 為邏輯 tile」等因應方案,目前可視為不必實作)。
- 本方案假設鄰居 LOD 差距恆為 0 或 1 級。若此規則被打破(例如允許差 2 級以上),corner 變體數量與 edge stitch 的跳點規則需要重新推導,現有 5 模板架構不再完整覆蓋所有組合。

## 待確認事項(需與地形系統其餘部分對齊)

- Edge stitch 的跳點規則是否统一為「每隔一個頂點跳過」,或需依 heightmap 取樣策略調整(例如是否要在跳過的頂點位置做高度平均,避免視覺上的高度落差)。
- 現有 1024×1024 total vertices / 32×32 tile grid / 33×33 vertices per tile 的座標系統,tile 邊界共用頂點目前是複製(duplicate)還是共享索引 —— 本方案的 border strip 定義需要與此對齊,避免與既有「seam vertex duplication」技術債衝突或重複處理。
- ~~Tile segment 數下限門檻的具體數值~~ **已確定**:N=4(4×4 segments),對應 4 級 LOD 規劃,見「LOD 層級與 Segment 數規劃」章節。
