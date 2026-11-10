# 酷狗多行歌词

一个原生 macOS 悬浮歌词 App，读取酷狗音乐当前歌曲和播放进度，显示三行或五行同步歌词，支持 KRC 词组内逐字点亮和波浪动画。当前行高亮，其余行降低透明度。

## 环境与验证范围

- macOS 14 或更高版本；当前在 macOS 15.0.1 上开发。
- 已针对酷狗音乐 20.3.8（Build 3898）的辅助功能结构和 macOS KRC 缓存格式实现。
- 酷狗升级后，如果播放栏结构或缓存格式变化，需要更新对应适配器。

## 构建与启动

需要 Swift 6 命令行工具，不需要完整 Xcode，也没有第三方依赖。

```bash
./Scripts/build-app.sh
open KugouLyricsOverlay.app
```

首次启动时，在“系统设置 → 隐私与安全性 → 辅助功能”中启用“酷狗多行歌词”。程序只读获取酷狗歌曲名、歌手和播放时间，不控制酷狗、不读取键盘、不修改酷狗文件，也不需要完全磁盘访问权限。

## 使用

1. 启动酷狗并播放歌曲，保持酷狗后台运行。
2. 酷狗主窗口可以最小化或关闭；辅助功能信息不可用时，App 会尝试通过 MediaRemote 获取酷狗后台播放状态。
3. 启动本 App。悬浮窗会出现在所有普通窗口上方，不显示 Dock 图标。
4. 拖动悬浮窗移动位置；右键悬浮窗或点击菜单栏音乐图标打开菜单：
   - 切换三行／五行；
   - 调整透明度；
   - 调整歌词颜色；
   - 重新获取歌词；
   - 手动导入 UTF-8 编码的 `.lrc` 文件；
   - 退出 App。

行数、透明度、歌词颜色和窗口位置会保存在 `UserDefaults` 中，下次启动恢复。

## 歌词来源

按以下顺序读取：

1. 当前歌曲的手动导入结果；
2. 当前会话已缓存的解析结果；
3. 酷狗本地 KRC/LRC 缓存：
   `~/Library/Containers/com.kugou.mac.Music/Data/Library/Application Support/com.kugou.mac.Music/Caches/kgLyric`
4. LRCLIB 在线同步歌词。

本地和在线结果都会校验歌名、歌手及可用时长。手动导入仅保存在当前 App 会话中。没有有效同步歌词时，可使用右键菜单导入 LRC。

## 测试

当前 Command Line Tools 不包含 XCTest 或 Swift Testing，因此测试使用 Swift Package 的可执行测试入口，并以退出码报告失败：

```bash
swift run KugouLyricsCoreTests
swift build --product KugouLyricsOverlay
```

测试覆盖 LRC/KRC 解析、歌曲匹配、歌词定位、三／五行窗口、播放与暂停、进度跳转、本地优先、在线匹配、手动导入，以及 MediaRemote 进度换算、同曲匹配和 AX 回退。

## 注意事项

- AX 提供歌曲身份和时长；MediaRemote 在同曲匹配时提供时间戳进度，接口不可用、超时或数据异常时自动回退 AX。AX 无法读取时，也会采用来源 PID 已确认为酷狗的 MediaRemote 完整播放信息。
- 本地插值仅用于平滑刷新，暂停和拖动进度后会重新校准；无有效播放信息时进入等待状态，不沿用旧歌进度。
- MediaRemote 是 macOS 私有框架，不属于 App Store 公开 API。
- 重新构建并使用临时签名后，macOS 可能使旧辅助功能授权失效。若如此，请在辅助功能设置中移除并重新添加正式 App。
- 不支持翻译合并、播放控制、歌词编辑和其他播放器。
