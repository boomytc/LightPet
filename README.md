# LightPet

LightPet 是一个兼容 Codex 的桌面宠物包的本地运行时。它的边界被刻意收窄：解析已有的宠物文件，验证固定的精灵表（spritesheet）契约，并将宠物呈现为原生的 macOS 桌面悬浮层。

超出范围：

- 生成、修复或编辑宠物美术资源。
- 新宠物的提示词编排。
- 将生成的资源打包为 Codex 宠物文件夹。
- 与其他应用或软件状态的动态集成。

使用 `hatch-pet` 技能或其他资源管线来创建宠物文件，然后将 LightPet 指向生成的文件夹。

## 运行

Web 预览：

```bash
python3 -m http.server 18091
```

打开：

```text
http://127.0.0.1:18091/
```

原生 macOS 桌面宠物：

```bash
swift run LightPetDesktop --scale 1
```

鼠标控制：

```text
悬停在可见精灵上  waiting（等待）
单击                failed（踉跄后退一步，然后恢复）
长按                waving（被抓住的姿态）
向左拖拽            running-left（拉住左手或左侧衣服）
向右拖拽            running-right（拉住右手或右侧衣服）
向上拖拽            jumping（被提起来的姿态）
向下拖拽            review（趴在地上，像被压住）
右键点击            尺寸、宠物文件夹、重置位置和退出菜单
```

宠物查找：

```text
--pet path/to/pet.json  精确的宠物清单路径
--pet-id pet-id         未提供 --pet 时优先尝试的 Codex 宠物键
```

未提供 `--pet` 时，桌面包装器读取与 Codex 相同的宠物目录：`${CODEX_HOME:-$HOME/.codex}/pets`。它会按顺序尝试 `--pet-id`、上一次成功选择的 Codex 宠物、该目录下排序后的首个可发现宠物。若某个记录的宠物文件夹已被删除，会自动落到首个可发现宠物。

如果 `${CODEX_HOME:-$HOME/.codex}/pets` 不存在，LightPet 会在启动时自动创建它。如果目录存在但没有任何有效宠物，或者目录路径被普通文件占用，桌面启动会弹窗提示需要放入宠物文件夹或修正目录。

如果上一次选择或 `--pet-id` 指向的宠物包存在但加载失败，非 `--pet` 精确路径启动会继续尝试下一个可发现的 Codex 宠物；只有所有候选都不可加载时才弹窗。

右键 `Pet` 菜单会轻量列出 `${CODEX_HOME:-$HOME/.codex}/pets/*/pet.json` 下发现的候选包。菜单打开时只读取清单并确认精灵表文件存在，避免在右键路径里同步解码每个 WebP；选择某个宠物时才会执行完整的精灵表尺寸、已用帧数以及未用单元格透明度验证。菜单还包含 `Choose Pet Folder...`，允许你选择任何包含以下精确配对的文件夹：

```text
pet.json
spritesheet.webp
```

要让宠物在每次启动时都出现在菜单中，请将文件夹放在 `${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/` 下。安装了 Codex 的机器会复用同一份宠物；没有 Codex 的机器也可以使用同一个目录约定，不需要再维护 LightPet 专属副本。

从 Codex 宠物目录成功启动或右键切换后，LightPet 会记住这个 `pet-id` 作为下次默认选择。`Choose Pet Folder...` 仅在当前运行中加载所选文件夹；它不会复制、安装、修改宠物文件，也不会把 Codex 宠物目录外的文件夹写成默认宠物。

尺寸冒烟测试：

```bash
swift run LightPetDesktop --show-dock --resize-smoke-test
```

这会打开原生面板，依次切换 `0.5x`、`0.75x`、`1x`、`1.25x` 和 `1.5x`，验证实际窗口尺寸，然后退出。

本地 `.app` 打包：

```bash
scripts/package_app.sh
```

这会生成 `dist/LightPet.app`，使用 ad-hoc 签名，适合自己或少量朋友本机使用。`.app` 不内置宠物资源，仍读取 `${CODEX_HOME:-$HOME/.codex}/pets`。如果通过聊天工具或浏览器传给朋友，macOS 可能加上 quarantine 标记；这种非公证包需要右键打开一次，或由使用者自行移除 quarantine。

## 渲染内容

- 从 `pet.json` 加载本地 Codex 宠物清单。
- 相对于清单 URL 解析 `spritesheetPath`。
- 将 `1536x1872` 的图集渲染为 `8x9` 单元格。
- 使用 `192x208` 的单元格和 Codex 行/帧时长表。
- 播放与自定义 Codex 宠物相同的命名状态。

`LightPetDesktop` 为这些文件添加了一个本地原生 macOS 包装器。它使用透明、无边框、浮动的 AppKit 面板，并直接用 Core Graphics 渲染相同的固定图集。透明的精灵像素不会触发宠物交互，且拖动会被限制在可见屏幕区域内。

## 文件契约

```text
${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/
├── pet.json
└── spritesheet.webp
```

`pet.json`：

```json
{
  "id": "conan",
  "displayName": "Conan",
  "description": "A lively pixel-art small desktop detective pet for Codex.",
  "spritesheetPath": "spritesheet.webp",
  "rendering": "pixelated"
}
```

对于右键文件夹选择，文件夹必须包含 `pet.json`、`spritesheet.webp`，且 `pet.json` 必须设置 `"spritesheetPath": "spritesheet.webp"`。

`rendering` 是可选字段：`pixelated` 用于像素风，`smooth` 用于软萌 3D、手绘、扁平插画等非像素风。省略时默认为 `pixelated`。

## 精灵表契约

`spritesheet.webp` 必须恰好为 `1536x1872` 像素：

```text
网格：8 列 x 9 行
单元格：192x208 像素
```

每一行是一个动画状态。已用单元格必须包含可见的宠物像素；该行帧数之后的未用单元格必须完全透明。

状态名保留 Codex 兼容契约，但在 LightPet 中建议把它们当作鼠标动作槽位来绘制：

| 行 | 状态 | 帧数 | 该行应展示的内容 |
| --- | --- | ---: | --- |
| 0 | `idle`（闲置） | 6 | 平静的休息循环，微妙的呼吸或眨眼。 |
| 1 | `running-right`（向右拖拽） | 8 | 向右拖拽时，被拉住右手、右侧衣服或身体右侧。 |
| 2 | `running-left`（向左拖拽） | 8 | 向左拖拽时，被拉住左手、左侧衣服或身体左侧。 |
| 3 | `waving`（长按抓住） | 4 | 鼠标长按时被抓住的姿态，可以有轻微挣扎。 |
| 4 | `jumping`（向上拖拽） | 5 | 向上拖拽时被提起来，身体离地或向上拉伸。 |
| 5 | `failed`（单击反应） | 8 | 单击后踉跄往后走一步，然后恢复。 |
| 6 | `waiting`（等待） | 6 | 专注的悬停状态，看起来已准备好。 |
| 7 | `running`（备用拖拽） | 6 | 中性的被拖拽或挣扎循环；当前鼠标逻辑不主动触发，但仍需有效帧。 |
| 8 | `review`（向下拖拽） | 6 | 向下拖拽时趴在地上，像被压住或被按住。 |

LightPet 支持非像素风格。运行时只要求透明 spritesheet 契约；风格可以是像素、手绘、扁平插画、软萌 3D 玩具风等。非像素风建议在 `pet.json` 中设置 `"rendering": "smooth"`，像素风可设置 `"rendering": "pixelated"` 或省略该字段。

有参考图时，优先使用这个提示词模板：

```text
Create a LightPet-compatible desktop pet package.

Package metadata:
- id: {id}
- displayName: {displayName}
- rendering: {rendering}

Reference image:
- Use the attached reference image as the visual source of truth.
- Infer one short pet description from the reference image for pet.json.
- Preserve the reference character's identity, proportions, silhouette, face, colors, clothing/accessories, material feel, and overall art style.
- If the reference is a smooth 3D toy-like mascot, keep that soft rounded 3D look instead of converting it to pixel art.
- Adapt the reference into consistent animation rows for mouse-only desktop pet interactions.

Output contract:
- Create a folder named {id}.
- The folder must contain exactly this runtime contract:
  - pet.json
  - spritesheet.webp
- pet.json must contain:
  {
    "id": "{id}",
    "displayName": "{displayName}",
    "description": "<one short sentence inferred from the reference image>",
    "spritesheetPath": "spritesheet.webp",
    "rendering": "{rendering}"
  }

spritesheet.webp requirements:
- Format: transparent-capable WebP.
- Exact size: 1536x1872 pixels.
- Grid: 8 columns x 9 rows.
- Cell size: 192x208 pixels.
- Each used cell must contain visible pet pixels.
- Unused cells after each row's frame count must be fully transparent.
- Keep the same pet identity, silhouette, palette, outline style, and proportions across all rows.
- Use the reference style consistently. For smooth 3D references, keep soft rounded forms, clean lighting, readable silhouettes, and transparent background.
- Do not include text, UI, speech bubbles, frame numbers, guide marks, shadows, detached motion lines, loose sparkles, or decorative effects separate from the pet body.
- Any effect must be small, hard-edged, style-consistent, mouse-action relevant, and attached to the pet silhouette.

Animation rows:
0. idle, 6 frames: calm resting loop with subtle breathing or blinking.
1. running-right, 8 frames: drag-right pose; the pet is pulled by the right hand, right sleeve, or right side of the body.
2. running-left, 8 frames: drag-left pose; the pet is pulled by the left hand, left sleeve, or left side of the body.
3. waving, 4 frames: long-press grabbed pose; the pet looks grabbed and may lightly struggle.
4. jumping, 5 frames: drag-up pose; the pet is lifted upward or stretched upward by the grab.
5. failed, 8 frames: click reaction; the pet staggers one step backward, then recovers.
6. waiting, 6 frames: attentive hover state, looking ready for interaction.
7. running, 6 frames: spare neutral drag or struggle loop; keep valid frames even if not triggered directly.
8. review, 6 frames: drag-down pose; the pet lies low or prone, as if pressed down by the cursor.
```

没有参考图时，使用这个提示词模板：

```text
Create a LightPet-compatible desktop pet package from text only.

Package metadata:
- id: {id}
- displayName: {displayName}
- description: {description}
- rendering: {rendering}

Character and style:
- Design a new desktop pet based on this description: {description}
- Art style: {style}
- If {style} is smooth 3D, make the pet look like a soft rounded toy mascot with clean lighting, simple materials, readable silhouette, and transparent background.
- If {style} is pixel art, use compact readable chibi proportions, crisp silhouette, limited palette, and transparent background.
- Keep the same identity, proportions, colors, clothing/accessories, and material feel across every row.

Output contract:
- Create a folder named {id}.
- The folder must contain exactly this runtime contract:
  - pet.json
  - spritesheet.webp
- pet.json must contain:
  {
    "id": "{id}",
    "displayName": "{displayName}",
    "description": "{description}",
    "spritesheetPath": "spritesheet.webp",
    "rendering": "{rendering}"
  }

spritesheet.webp requirements:
- Format: transparent-capable WebP.
- Exact size: 1536x1872 pixels.
- Grid: 8 columns x 9 rows.
- Cell size: 192x208 pixels.
- Each used cell must contain visible pet pixels.
- Unused cells after each row's frame count must be fully transparent.
- Do not include text, UI, speech bubbles, frame numbers, guide marks, shadows, detached motion lines, loose sparkles, or decorative effects separate from the pet body.
- Any effect must be small, hard-edged, style-consistent, mouse-action relevant, and attached to the pet silhouette.

Animation rows:
0. idle, 6 frames: calm resting loop with subtle breathing or blinking.
1. running-right, 8 frames: drag-right pose; the pet is pulled by the right hand, right sleeve, or right side of the body.
2. running-left, 8 frames: drag-left pose; the pet is pulled by the left hand, left sleeve, or left side of the body.
3. waving, 4 frames: long-press grabbed pose; the pet looks grabbed and may lightly struggle.
4. jumping, 5 frames: drag-up pose; the pet is lifted upward or stretched upward by the grab.
5. failed, 8 frames: click reaction; the pet staggers one step backward, then recovers.
6. waiting, 6 frames: attentive hover state, looking ready for interaction.
7. running, 6 frames: spare neutral drag or struggle loop; keep valid frames even if not triggered directly.
8. review, 6 frames: drag-down pose; the pet lies low or prone, as if pressed down by the cursor.
```
