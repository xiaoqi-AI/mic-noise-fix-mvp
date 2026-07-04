# Mic Noise Fix MVP

这是一个 Windows 麦克风底噪修复可行性验证项目。

## 真实场景

主播在更新 Windows 系统后，麦克风底噪突然变严重。用户尝试过常规系统设置、设备选择、音量调整等办法后，最后通过更新或恢复“高清晰音频管理器/音频控制台”相关链路解决了问题。

这个 MVP 的目标不是承诺一键修复所有麦克风问题，而是先验证一个更具体的假设：

> Windows 更新后，音频驱动或 OEM 音频控制链路不完整，导致麦克风 Boost、增强、降噪、插孔策略等配置入口丢失或失效。恢复对应音频管理器/控制台链路后，主播麦克风底噪问题可以被修复。

## MVP 验证标准

本阶段以本机为验证环境，重点看三件事：

1. 设备管理器中音频设备是否正常，无明显问题设备。
2. 高清晰音频管理器、Realtek Audio Console/Control，或本机 OEM 音频控制台是否存在并能打开。
3. 相关开机自启动项、后台服务或 UWP 控制台链路是否正常。

如果音频管理器能正常打开，并且底噪恢复到主播可接受状态，则判定该路径对真实场景有效。

## 本机初步发现

当前本机首轮检测显示：

- 系统：Windows 11 专业版，Build 26200。
- 机型：MECHREVO Yilong15Pro Series GM5HG0A。
- 音频链路不是典型 Realtek 链路，主要看到 Senary/High Definition Audio、NVIDIA/AMD 音频设备。
- 未发现旧版 Realtek HD Audio Manager 常见入口：`RtkNGUI64.exe`、`RAVCpl64.exe`。
- 发现 `Audio Console`，AppID 指向 Senary 音频控制台。
- 发现 `Nahimic service` 正常运行。

因此本机 MVP 需要支持“Realtek/OEM 音频控制链路”检测，而不是只检测 Realtek。

## 当前范围

只读检测：

- Windows 版本、厂商、机型。
- 音频设备和驱动状态。
- 设备管理器问题设备。
- Realtek/Senary/Nahimic/Waves/Dolby/DTS 等音频控制台和服务。
- 旧版 Realtek HD Audio Manager 文件入口。
- 开机自启动相关项。

可选人工验证：

- 打开检测到的音频控制台。
- 用户在控制台中确认麦克风 Boost、增强、降噪等设置。
- 调整后重新进行麦克风底噪验收。

不做：

- 不自动删除驱动。
- 不强装通用 Realtek 驱动。
- 不分发第三方 Realtek 整合包。
- 不把旧版 HD Audio Manager 当作 Windows 11 25H2 的唯一正确目标。

## 使用方式

只读采集音频链路报告：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\collect-audio-chain.ps1
```

验证是否存在可打开的音频管理器/控制台：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate-audio-manager.ps1
```

打开检测到的音频管理器/控制台：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate-audio-manager.ps1 -OpenManager
```

报告默认生成在 `reports/`，不会提交到 GitHub。

## 下一步

1. 用本机跑通只读检测和管理器打开验证。
2. 若本机音频控制台能打开，记录底噪修复前后的配置变化。
3. 补充 Boost 归零和系统增强关闭的自动化 POC。
4. 按 Realtek、Senary、Nahimic、Waves 等链路建立白名单。
5. 再决定是否做一键修复。

