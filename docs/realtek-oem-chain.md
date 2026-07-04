# Realtek/OEM 音频链路说明

## 背景

在 Windows 11 现代系统中，“高清晰音频管理器”不一定再以旧版 Realtek HD Audio Manager 形式存在。很多机器已经改为：

- Realtek UAD/DCH Driver
- OEM Extension INF
- Audio Processing Object
- Realtek Universal Service
- Realtek Audio Console/Control
- Nahimic、Waves、Dolby、DTS 等 OEM 音效组件

因此本项目把目标定义为“恢复对应 OEM 音频控制链路”，而不是强制恢复旧版 Realtek HD Audio Manager。

## 链路检测项

### 驱动层

- MEDIA 类 PnP 设备。
- `Win32_PnPSignedDriver` 中的音频驱动。
- 设备是否回退到 Microsoft `hdaudio.inf`。
- 是否存在问题设备。

### 服务层

- `RtkAudioUniversalService`
- `NahimicService`
- Waves 相关服务
- Dolby/DTS 相关服务
- OEM 音频服务

### 应用层

- Realtek Audio Console/Control
- Senary Audio Console
- Nahimic Companion
- Waves MaxxAudio
- Dolby Access / DTS Sound Unbound
- 旧版 Realtek HD Audio Manager

### 自启动层

传统 HDA 管理器可能有 Run 自启动项；现代 UWP/HSA 控制台可能没有传统自启动，而是依赖后台服务、驱动组件或应用包。

## 可行性边界

可做：

- 检测链路是否完整。
- 检测管理器是否存在。
- 打开管理器让用户确认。
- 后续加入 Boost 归零、关闭系统增强的自动化。

谨慎做：

- 安装 OEM 官方驱动包。
- 通过 Store 或 winget 安装 Realtek Audio Control。
- 启动或重启音频相关服务。

不建议做：

- 强装通用 Realtek 驱动。
- 自动删除未知驱动。
- 分发第三方 Realtek 整合包。
- 对未知 OEM 私有音效写注册表。

