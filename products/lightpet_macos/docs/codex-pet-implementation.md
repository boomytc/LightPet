# Codex 宠物实现笔记

## 项目边界

LightPet 只是现有 Codex 兼容宠物包的播放器和桌面展示包装器。它负责：

- 读取 `pet.json`。
- 加载和验证 `spritesheet.webp`。
- 将鼠标动作映射到现有的动画行。
- 在桌面右键菜单中显示尺寸和宠物包选择。

它不负责：

- 生成宠物美术资源。
- 修复损坏的行或透明背景。
- 图像生成的提示词规划。
- 打包生成的文件。
- 将动画状态与外部应用或软件事件集成。

使用 `hatch-pet` 技能或其他资源管线来创建符合以下契约的包。

## 运行时契约

LightPet 读取 Codex 和 `hatch-pet` 技能使用的相同宠物目录：

```text
${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/
├── pet.json
└── spritesheet.webp
```

清单被刻意保持精简：

```json
{
  "id": "pet-id",
  "displayName": "Pet Name",
  "description": "One short sentence.",
  "spritesheetPath": "spritesheet.webp",
  "rendering": "pixelated"
}
```

应用通过文件夹名称发现宠物，读取命名为 `pet.json` 的清单，然后加载相邻的 `spritesheet.webp`。所有加载入口都要求包内包含 `pet.json` 和 `spritesheet.webp`，并且要求 `pet.json` 设置 `"spritesheetPath": "spritesheet.webp"`。

`rendering` 是可选的。像素艺术使用 `pixelated`，非像素风格（如平滑 3D 吉祥物艺术、手绘精灵或平面插画）使用 `smooth`。省略时默认为 `pixelated`。

## 图集几何

动画表面是一个固定的精灵图集：

```text
atlas: 1536x1872
grid:  8 columns x 9 rows
cell:  192x208
```

播放器不需要清单中的逐帧矩形。一个状态映射到固定的图集行，帧索引映射到固定的列。一行中最后已用列之后的未用单元格必须保持完全透明。

`spritesheet.webp` 应该只包含宠物本身，背景透明。每个已用帧必须保持相同的宠物识别度、轮廓、调色板、轮廓样式和比例。避免文字、UI、对话气泡、阴影、引导框、帧编号、分离的运动线、松散闪光或与宠物身体分离的装饰效果。

## 动画表

机器可读的动画契约位于 `docs/pet-animation-contract.json`。下面的表格是面向阅读的说明；修改状态行、帧数或时长时，先更新 JSON，再运行 `python3 scripts/validate_animation_contract.py` 确认 Swift 运行时一致。

| 行 | 状态 | 帧数 | 时长 |
| --- | --- | ---: | --- |
| 0 | idle | 6 | 280, 110, 110, 140, 140, 320 ms |
| 1 | running-right | 8 | 每帧 120 ms，最后一帧 220 ms |
| 2 | running-left | 8 | 每帧 120 ms，最后一帧 220 ms |
| 3 | waving | 4 | 每帧 140 ms，最后一帧 280 ms |
| 4 | jumping | 5 | 每帧 140 ms，最后一帧 280 ms |
| 5 | failed | 8 | 每帧 140 ms，最后一帧 240 ms |
| 6 | waiting | 6 | 每帧 150 ms，最后一帧 260 ms |
| 7 | running | 6 | 每帧 120 ms，最后一帧 220 ms |
| 8 | review | 6 | 每帧 150 ms，最后一帧 280 ms |

`hatch-pet` 或其他生成器的提示词指导：

行名称保持 Codex 兼容，但 LightPet 将它们视为鼠标动作槽位。对于纯鼠标桌面宠物，围绕直接操作而非外部应用状态来设计视觉效果。

| 状态 | 视觉意图 |
| --- | --- |
| `idle` | 平静的休息循环，带有微妙的呼吸、眨眼或小幅姿势变化。 |
| `running-right` | 向右拖动姿势：宠物被右手、右袖或身体右侧拉动。 |
| `running-left` | 向左拖动姿势：宠物被左手、左袖或身体左侧拉动。 |
| `waving` | 长按姿势：宠物看起来被抓住，可能会轻微挣扎；没有波浪标记或浮动符号。 |
| `jumping` | 向上拖动姿势：宠物被向上提起或被抓取向上拉伸。 |
| `failed` | 点击反应：宠物向后踉跄一步，然后恢复。 |
| `waiting` | 专注的悬停状态，看起来准备好交互。 |
| `running` | 备用的中性拖动或挣扎循环；即使当前鼠标逻辑不会直接触发它，也要保持有效帧。 |
| `review` | 向下拖动姿势：宠物趴低或俯卧，仿佛被光标按下。 |

LightPet 支持非像素风格。运行时只需要透明的精灵表契约；视觉风格可以是像素艺术、手绘、平面插画、平滑 3D 玩具式吉祥物艺术或其他紧凑易读的风格。对于非像素艺术，在 `pet.json` 中设置 `"rendering": "smooth"`；对于像素艺术，设置 `"rendering": "pixelated"` 或省略该字段。

With reference image:

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

Without reference image:

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

## 播放逻辑

最小的 Web 运行时是：

1. 获取 `pet.json`。
2. 确认清单文件名是 `pet.json`，并且 `spritesheetPath` 是固定值 `spritesheet.webp`。
3. 对于活动状态，读取 `row`、`frames` 和 `durations`。
4. 使用相邻的 `spritesheet.webp` 作为 CSS 背景渲染一个 `192x208` 视口。
5. 按状态时长表推进帧索引。

CSS 背景计算如下：

```text
background-size: 1536px 1872px
background-position-x: -frameIndex * 192px
background-position-y: -rowIndex * 208px
```

缩放时，将每个图集和单元格尺寸乘以相同的缩放因子。

## 桌面包装器逻辑

`Sources/LightPetDesktop/Core`、`UI` 和 `App` 中的原生桌面包装器保持相同的宠物包契约。它只改变宿主表面：

1. 解码 `pet.json`。
2. 使用 `NSImage` 解码 `spritesheet.webp`。
3. 验证解码后的 `CGImage` 恰好为 `1536x1872`。
4. 预切片并验证所有已用帧，同时检查未用单元格是否透明。
5. 打开一个透明、无边框的 `NSPanel`。
6. 将活动的缓存 `192x208` 帧绘制到面板中。
7. 使用与 Web 预览相同的时长表，通过 `Timer` 推进帧。

窗口设置：

```text
style: borderless, non-activating panel
background: transparent
level: floating
spaces: can join all spaces, fullscreen auxiliary
```

鼠标行为：

```text
悬停在可见精灵上  waiting（等待）
点击                 failed（失败）
长按                 waving（挥手）
向左/向右拖动        移动面板并选择 running-left/running-right（向左/向右奔跑）
向上/向下拖动        移动面板并选择 jumping/review（跳跃/审视）
鼠标松开             根据指针位置返回 waiting（等待）或 idle（闲置）
右键点击             显示尺寸、宠物、重置位置和退出菜单
```

右键菜单有意不列出动画状态。状态由桌面宠物的鼠标交互模型选择。

额外的桌面行为：

- 宠物选择仅从 `${CODEX_HOME:-$HOME/.codex}/pets/*/pet.json` 中发现。
- 如果 Codex 宠物目录不存在，启动时会创建它及其中间目录。
- 如果 Codex 宠物路径存在但不是目录，启动时会显示致命警告。
- 不带 `--pet` 的启动查找会依次尝试显式的 `--pet-id`、最后成功选择的 Codex 宠物、第一个可发现的 Codex 宠物。
- 如果记住的或请求的 Codex 宠物不再存在，启动时会回退到第一个可发现的 Codex 宠物，而不是立即失败。
- 如果回退后没有有效的宠物存在，启动时会显示致命警告，指示用户添加包含 `pet.json` 和 `spritesheet.webp` 的文件夹。
- 如果非 `--pet` 候选存在但在加载时未能通过完整的精灵表验证，启动时会在显示致命警告之前尝试下一个可发现的 Codex 宠物。
- 对于 `${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/` 包的成功启动和右键菜单切换会记住该 `pet-id` 以供下次启动使用。
- 右键菜单保持发现轻量：它读取 `pet.json` 并确认 `spritesheet.webp` 存在，而完整的精灵表验证仅在宠物被选择或启动时运行。
- 右键 `Pet` 子菜单包含 `Choose Pet Folder...`；只有当目录包含 `pet.json` 和 `spritesheet.webp` 时才会加载所选目录。
- `Choose Pet Folder...` 是临时运行时加载。它不会复制、安装、修改宠物文件，也不会为 Codex 宠物目录之外的文件夹持久化默认值。
- 要让宠物在每次启动时都出现在菜单中，请将其文件夹放在 `${CODEX_HOME:-$HOME/.codex}/pets/<pet-id>/` 下。
- 可以从右键菜单更改窗口大小。
- 命中测试采样当前帧的 alpha 贴图，因此透明的精灵像素不会启动宠物交互。
- 拖动被限制在可见屏幕的并集内，以保持宠物可触及。

这是桌面宠物的实际最小实现。更高级的行为应该作为显式的鼠标或桌面环境触发器添加到相同的状态控制器边界之上。软件集成事件目前有意超出范围。

## 外部资源创建

宠物生成保留在此仓库之外。诸如 `hatch-pet` 技能之类的生成器应该生成最终文件夹：

```text
<pet-id>/
├── pet.json
└── spritesheet.webp
```

为了让包在这里工作，生成的精灵表必须已经是透明的、尺寸正确的、行对齐的、视觉一致的，并且没有非透明的未用单元格。LightPet 验证这些运行时要求但不修复它们。

## 当前工作空间复现

此工作空间在以下文件中实现了本地运行时：

```text
preview/web/index.html
preview/web/styles.css
preview/web/app.js
Package.swift
Sources/LightPetDesktop/Core/PetRuntime.swift
Sources/LightPetDesktop/UI/PetAnimationView.swift
Sources/LightPetDesktop/UI/WindowGeometry.swift
Sources/LightPetDesktop/App/AppDelegate.swift
Sources/LightPetDesktop/App/main.swift
```

原生桌面包装器从以下位置发现默认宠物：

```text
${CODEX_HOME:-$HOME/.codex}/pets/
```

浏览器预览仍然是一个清单路径预览工具；它可以加载本地 Web 服务器能够提供的任何宠物包 URL。

这证明了只要保留图集和清单契约，Codex 宠物格式就可以在 Codex 应用之外复现。
