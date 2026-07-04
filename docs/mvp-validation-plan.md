# MVP 可行性验证方案

## 目标

验证 Windows 更新后麦克风底噪变严重时，恢复或打开 OEM 音频管理器/控制台链路是否能解决问题。

## 项目判断

本 MVP 以“链路诊断”作为第一阶段，不直接做驱动强修复。原因：

- Windows 11 现代音频链路可能是 Realtek UAD/DCH，也可能是 Senary、Conexant、Nahimic、Waves、Dolby、DTS 等 OEM 组合。
- 旧版高清晰音频管理器不一定存在，也不一定适合 25H2。
- 底噪真正相关的设置通常是 Boost、增强、降噪、AEC、AGC、插孔策略，而不一定是某个旧 UI 本身。

## 验证分层

### A. 设备管理器验证

通过系统接口检查：

- 是否存在音频设备。
- 是否存在问题设备。
- 音频驱动是否来自 Microsoft、Realtek、AMD、NVIDIA、Senary、OEM 厂商。
- 是否存在基础驱动回退到 Microsoft `hdaudio.inf` 的情况。

### B. 管理器/控制台验证

检查：

- 旧版 Realtek HD Audio Manager：`RtkNGUI64.exe`、`RAVCpl64.exe`。
- Realtek Audio Console/Control。
- Senary Audio Console。
- Nahimic Companion。
- Waves、Dolby、DTS 等 OEM 控制台。

### C. 自启动/后台链路验证

检查：

- `HKLM/HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 中的音频项。
- StartupApproved 中的音频项。
- Realtek、Senary、Nahimic、Waves、Dolby、DTS 相关服务。

注意：UWP 控制台不一定有传统开机自启动项，现代链路可能依赖服务或驱动组件。

### D. 人工打开验证

脚本检测到管理器后，使用 `-OpenManager` 参数打开候选控制台。用户确认：

- 管理器是否能打开。
- 是否能看到麦克风录音设置。
- 是否能调整 Boost、增强、降噪、AEC、AGC 等项。

### E. 底噪验收

验收标准不只看 UI 是否存在，还要看真实主播体验：

- 底噪是否明显下降。
- 直播/录音软件中输入电平是否稳定。
- 不说话时是否仍有持续电流声。
- 重新开机后设置是否保留。

## 当前本机风险

当前本机首轮结果显示不是典型 Realtek，而是 Senary/High Definition Audio + Nahimic 链路。验证标准需要从“高清晰音频管理器”扩展为“当前机器对应的 OEM 音频控制台能正常打开”。

这不否定真实场景，只说明 MVP 需要兼容不同 OEM 链路。

