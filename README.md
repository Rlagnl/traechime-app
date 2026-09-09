# TraeChime

TraeChime 是一款 macOS 菜单栏常驻的 **AI Agent 状态提醒工具**：通过 Trae 系应用的 Hooks 机制，把 AI Agent 的任务状态（执行中 / 已完成 / 等待人工确认 / 执行异常）实时映射到菜单栏图标与提示音上，让你即使切到其他窗口也能第一时间感知任务进展。

完全本地运行：事件由 Trae 侧的 Hook 命令推送，TraeChime 只在本机回环地址（`127.0.0.1`）上监听，数据不出本机。

## 功能特性

- **菜单栏实时状态**：Logo + 状态文字（空闲 / 任务中 / 已完成 / 待确认 / 有异常）
- **动画提醒**：「需要注意」时菜单栏右上角出现彩色呼吸点（绿=完成 / 橙=待确认 / 红=异常）
- **提示音提醒**：仅在有任务需要关注时播放，三种状态可独立选择音效，避免打扰
- **下拉面板**：查看每个 Agent 的任务标题、状态与耗时，可「跳转」回对应应用或「清除」记录
- **智能去打扰**：切回 Trae 应用时，自动清除该来源「已完成」的记录，无需手动处理
- **一键接入**：自动把 Hook 配置写入 `~/.trae-cn/hooks.json`，并保留你已有的配置
- **可配置**：提示音、监听端口、鉴权令牌、TraeCode Bundle ID、开机自启

## 环境要求

- macOS 13.0（Ventura）及以上
- 可接入的 AI IDE：TraeCode（需支持 Hooks 的版本）
- 自行生成安装包需安装 **Xcode Command Line Tools**（含 `swift`、`codesign`、`hdiutil`、`sips`、`iconutil`）

## 如何生成 DMG 安装包

项目根目录提供一键打包脚本，依次完成「release 编译 → 组装 .app → 压制成 dmg」：

```bash
./scripts/make_dmg.sh
```

脚本流程说明：

1. `swift build -c release` 编译两个可执行目标（主程序与 Hook 桥接程序）
2. 调用 [scripts/make_app.sh](scripts/make_app.sh) 组装 `dist/TraeChime.app`：拷贝二进制与资源、写入 `Info.plist`（含 `LSUIElement`）、对 app 做 ad-hoc 临时签名
3. 用 `hdiutil` 制作 UDZO 压缩镜像 `dist/TraeChime-<版本>.dmg`（卷名 `TraeChime`，内含 `TraeChime.app` 与「应用程序」快捷方式）

如果只想生成 .app 而不打 dmg，可单独执行：

```bash
./scripts/make_app.sh
```

**产物路径**

- `dist/TraeChime.app`
- `dist/TraeChime-<版本>.dmg`（`<版本>` 取自 `VERSION` 文件）

**注意事项**

- 产物为 **ad-hoc 签名、未公证（notarization）** 的版本，仅适合本地与内部分发。如需对外发布，请改用你的 Developer ID 签名并完成公证。
- 脚本可重复执行：每次都会先清空 `dist/` 下旧的 app / dmg 再生成。

### 自动发布（GitHub Release）

项目内置了基于 **Git tag + GitHub Actions + GitHub Release** 的自动化打包发布流程：

1. **版本号唯一来源**：`VERSION` 文件（当前 `1.0.0`）。发布前先更新它并提交；
2. **打 tag**：`git tag v$(cat VERSION)` 并推送（`git push origin <tag>`）；
3. **自动构建**：推送 `v*` 开头的 tag 会触发 [.github/workflows/release.yml](.github/workflows/release.yml)，在 `macos-latest` 上编译、组装 app、压制 DMG、生成 SHA-256 校验值；
4. **自动发布**：CI 校验 tag 与 `VERSION` 一致后，用 `gh release create` 创建 GitHub Release 并上传 DMG 与 `checksums.txt`。

手动触发：在仓库「Actions → Release TraeChime → Run workflow」可手动跑一次打包（仅上传 artifact，不创建 Release），用于验证流程。

> 当前产物为 ad-hoc 签名、未公证版本，仅限本地/内部分发。对外公开发布需接入 Developer ID 签名与公证（后续在脚本中补充）。

## 安装

1. 打开 `dist/TraeChime-<版本>.dmg`
2. 将 `TraeChime.app` 拖入「应用程序」文件夹
3. 首次打开时，由于是 ad-hoc 签名，Gatekeeper 可能提示「无法验证开发者」。请**右键 → 打开**放行一次；若仍被拦截，可在终端执行：

```bash
# 移除下载隔离标记后再次打开
xattr -dr com.apple.quarantine /Applications/TraeChime.app
open /Applications/TraeChime.app
```

4. TraeChime 是菜单栏应用（`LSUIElement`），启动后**没有 Dock 图标**，只会出现在屏幕顶部菜单栏。

## 如何使用

### 第一步：接入 Trae

首次启动会自动弹出引导窗口，点击「**一键接入**」即可。如果错过了，之后可随时通过「菜单栏图标 → 面板 → 设置 → Trae 接入 → 一键接入」完成。

一键接入会把应用内置的 `traechime-hook` 桥接程序注册到 Trae 的全局 Hook 配置文件 `~/.trae-cn/hooks.json`（不会覆盖你已有的配置）。随后还需要两步：

1. **重启 Trae**，让 Hook 配置生效；
2. 在 Trae 的「**设置 → Hooks**」中打开**全局 Hook 开关**。

> 注意：接入时写入的是 app 内嵌桥接程序的**绝对路径**。若之后移动了 `TraeChime.app` 的位置，需要重新点一次「一键接入」。

### 第二步：发起任务，观察状态变化

在 Trae 里让 Agent 开始干活，菜单栏图标会实时变化。状态含义如下：

| 菜单栏显示 | 含义 | 呼吸点颜色 | 触发事件示例 |
| --- | --- | --- | --- |
| 空闲 | 当前无运行中的任务 | 无 | 无待处理记录 |
| 任务中 | Agent 正在执行 | 无（轻微摆动） | 提交 Prompt 后 / 确认后恢复执行 |
| 已完成 | 任务完成，等待你查看 | 绿 | Agent 空闲、停止 |
| 待确认 | 需要人工确认/审阅 | 橙 | 权限确认、文档审阅 |
| 有异常 | 任务执行失败 | 红 | 执行异常 |

**提示音规则**：只在状态**升级**为「已完成 / 待确认 / 有异常」时播放一次；同一状态超过 2 秒仍存在才会再次提醒，避免连续轰炸。

### 面板操作

点击菜单栏图标弹出状态面板，面板内容：

- **任务卡片**：每张卡片显示任务标题、状态与已耗时，底部有「跳转」（切换到对应的 Trae 应用）和「清除」（移除这条记录）按钮；
- **底部操作区**：`全部清除` / `设置` / `退出`。

**小技巧**：当你从其他应用切回 Trae 时，该来源「已完成」的记录会自动清除，无需手动逐个处理。

### 设置项说明

通过「菜单栏图标 → 面板 → 设置」打开设置窗口：

| 分组 | 设置项 | 说明 |
| --- | --- | --- |
| Trae 接入 | 接入状态 / 一键接入 | 显示是否已接入，可重复执行 |
| 提示音 | 开启提示音 | 总开关 |
| 提示音 | 完成 / 待确认 / 异常音效 | 分别选择系统音效并试听 |
| 事件服务 | 监听端口 | 默认 `17387`，修改后立即重启服务 |
| 事件服务 | 令牌（可选） | 留空则不校验；设置后请求需带 `X-TraeChime-Token` |
| 来源应用 | TraeCode Bundle ID | 供面板「跳转」按钮定位应用 |
| 通用 | 开机自启 | 登录时自动启动（需 app 位于稳定路径） |

**什么情况下需要改端口**：默认端口 `17387` 被其他程序占用时，或你在 Trae Hook 环境变量里通过 `TRAECHIME_PORT` 自定义了端口时，需保持两边一致。

### 事件协议（进阶）

TraeChime 在本机回环地址上提供一个极简 HTTP 服务，供 Trae Hook 或第三方脚本推送事件。

```
POST http://127.0.0.1:<port>/v1/events
Content-Type: application/json
X-TraeChime-Token: <可选，与设置中的令牌一致>
```

请求体字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `source` | string | 来源标识（如 `traecode`） |
| `agent_id` | string | 同一 Agent 会话内保持不变的 ID |
| `task_title` | string | 用于面板展示的任务标题 |
| `event` | string | `started` / `completed` / `confirm_required` / `failed` / `resumed` |
| `timestamp` | string? | 可选，ISO8601，缺省以接收时间为准 |

curl 示例：

```bash
curl -s -X POST http://127.0.0.1:17387/v1/events \
  -H "Content-Type: application/json" \
  -d '{"source":"traecode","agent_id":"demo","task_title":"写登录接口","event":"started"}'
```

内置 `traechime-hook` 完成的 Hook 事件映射如下，供自定义 Hook 参考：

| Trae Hook 事件 | 映射到 TraeChime 事件 |
| --- | --- |
| `UserPromptSubmit` | `started`（标题取用户 Prompt 前 40 字） |
| `Notification`（`idle_prompt`） | `completed` |
| `Notification`（`permission_prompt` / `document_review`） | `confirm_required` |
| `PreToolUse` / `PostToolUse` | `resumed`（从待确认恢复执行） |
| `Stop` | `completed`（兜底） |

### 已知限制

受限于 TraeCode 当前的 Hook 机制，以下两个场景暂时无法被准确感知，菜单栏状态可能停留在旧状态：

1. **主动停止**：手动停止一个正在执行的任务时，TraeCode 不会触发任何 Hook 事件（`Stop` 事件只在正常结束的生命周期中触发，手动停止不触发）。因此菜单栏会一直停留在「任务中」，无法自动感知到任务已被停止。

2. **待确认 → 任务中**：当「待确认」事件被处理后 Agent 恢复执行时，TraeCode 没有提供对应的通知信号（`PreToolUse` / `PostToolUse` 无法覆盖纯人工确认后恢复的场景），因此状态无法可靠地从「待确认」回到「任务中」。

> 这两个场景属于 TraeCode Hook 机制的信号盲区，待 TraeCode 后续完善 Hook 机制（例如补充 `SessionStop` 等生命周期事件）后，TraeChime 会跟进补全对应的事件映射。

### 卸载

1. 从 `~/.trae-cn/hooks.json` 中删除指向 `traechime-hook` 的 Hook 条目（或删除整个文件，如无其他用途）；
2. 将 `TraeChime.app` 移到废纸篓；
3. 如需彻底关闭开机自启，可在「系统设置 → 通用 → 登录项」中移除 TraeChime。

## 本地开发与联调

```bash
swift build            # 调试构建
swift run TraeChime    # 直接以开发模式运行
```

端到端联调脚本 [scripts/smoke_test.sh](scripts/smoke_test.sh) 会向本机事件服务依次推送 `started` / `completed` / `confirm_required` / `failed` 及异常请求，验证状态机与响应码：

```bash
# 默认端口 17387；若设置了令牌可传入
PORT=17387 TOKEN=xxx ./scripts/smoke_test.sh
```

Hook 桥接程序支持的环境变量（用于自定义 Hook 时）：

- `TRAECHIME_PORT`：事件服务端口，默认 `17387`
- `TRAECHIME_TOKEN`：鉴权令牌，默认空
- `TRAECHIME_SOURCE`：事件来源，默认 `traecode`

## 目录结构

```
Package.swift                    # SwiftPM 清单（两个可执行目标）
VERSION                          # 版本号唯一来源（CI 打 tag 前校验）
.github/workflows/release.yml    # GitHub Actions 自动打包发布
scripts/
  make_app.sh                    # 编译并组装 TraeChime.app
  make_dmg.sh                    # 由 .app 生成 TraeChime-<版本>.dmg
  gen_icns.sh                    # 由 Logo PNG 生成 AppIcon.icns
  smoke_test.sh                  # 端到端事件联调
Sources/
  TraeChime/                     # 主应用（菜单栏 UI + 本地事件服务）
  TraeChimeHook/                 # Hook 桥接程序（Trae 侧命令行入口）
```

## License

本项目采用 [PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0)。

- 任何个人与组织均可将其用于**非商业目的**（研究、学习、兴趣项目、公益等），自由复制、分发与修改；
- **二次开发、修改衍生作品及任何商业用途，必须事先获得作者的书面授权**。

Copyright © Gimi Kim · 商业授权与合作请联系 <250989770@qq.com>。

完整条款见 [LICENSE](LICENSE)。
