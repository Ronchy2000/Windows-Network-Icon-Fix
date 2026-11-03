# Windows 10/11：让联网 Wi-Fi 显示“无 Internet”图标

**[点击这里进入下载页面：故意显示灰色地球图标版 v2.0.0](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/fake-offline-icon-v2.0.0)**

不熟悉 GitHub 的用户：打开上面的链接，在页面下方的 **Assets（附件）** 中点击 **`Windows-Fake-Offline-Icon-v2.0.0.zip`** 下载。下载后右键 ZIP，选择“全部解压缩”，文件夹里有“显示灰色地球图标”和“恢复正常联网图标”两个 BAT。无需下载源码或安装开发工具。

> 本分支专门实现“实际可以上网，但任务栏故意显示灰色小地球/无 Internet”的需求。若你是要**修复**错误的灰色地球图标，请返回 [`main` 分支](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/tree/main)。

适用场景：运行 Windows10 / Windows 11 的电脑。该功能依赖 Windows 自带的 NCSI（网络连接状态指示器），与电脑品牌和无线网卡型号无关。

## 先看结论

- 运行 [`显示灰色地球图标.bat`](./显示灰色地球图标.bat)，设置离线图标模式，然后重启 Windows。Wi-Fi 传输不被禁用，具体图标是否变化仍取决于系统版本、缓存和策略。
- 运行 [`恢复正常联网图标.bat`](./恢复正常联网图标.bat)，恢复修改前的探测配置，然后重启 Windows。
- 第一个脚本会在同目录自动创建 `backups` 文件夹并备份注册表；第二个脚本会根据备份恢复本工具涉及的三项值，保留其他配置。
- 两个脚本都必须右键选择“以管理员身份运行”。
- 新版窗口显示 **2.0.0**。每个 BAT 都是独立文件，使用 Windows 自带的 PowerShell 5.1；不需要另外下载 `.ps1`。

> [!IMPORTANT]
> 这只是改变 Windows 对网络状态的判断，并不会真的禁止联网、隐藏流量或提升隐私。不同 Windows 11 版本、主题和任务栏样式可能显示为灰色地球、地球叠加禁止符号，或其他“无 Internet”样式，无法保证像素级一致。

## 使用教程

### 一、切换为“表面未联网”

1. **[点击进入 Release 下载页面](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/fake-offline-icon-v2.0.0)**，展开 **Assets（附件）**，点击 **`Windows-Fake-Offline-Icon-v2.0.0.zip`**。不要选择 `Source code`。右键下载好的 ZIP，选择“全部解压缩”，将两个 BAT 保留在同一个可写文件夹中，不要直接在压缩包内运行。
2. 右键 [`显示灰色地球图标.bat`](./显示灰色地球图标.bat)，选择“以管理员身份运行”。
3. 看到“三项注册表值已修改并校验”后，正常重启电脑。
4. 重启后连接 Wi-Fi，观察任务栏。写入成功不等于已确认图标变化；若仍显示联网，请按下文收集日志。

脚本可以重复运行。只要上一次修改尚未恢复，它就会复用第一次生成的原始备份，不会用已经修改过的注册表覆盖备份。

### 二、恢复正常联网图标

1. 不要移动或删除脚本旁边的 `backups` 文件夹。
2. 右键 [`恢复正常联网图标.bat`](./恢复正常联网图标.bat)，选择“以管理员身份运行”。
3. 脚本会恢复原始备份中的三项值及类型，删除原本不存在的值，并保留历史备份文件。两项策略值删除失败也会报错，不再误报成功。
4. 正常重启电脑。

仅当不存在 `latest.txt` 时，恢复脚本采用回退方式：重新启用 NCSI 主动探测，并删除本工具涉及的两项策略值；它不会重写探测网址等其他 NCSI 配置。指针或自动恢复所需的备份损坏、缺失时会明确停止，不会悄悄覆盖成默认配置。回退无法还原已丢失的原始策略。

## 窗口闪退或重启后没有变化

旧版 BAT 在括号代码块中直接展开目录路径。如果路径含有 `(`、`)` 或 `&` 等 cmd 特殊字符，可能触发解析错误，窗口来不及执行 `pause`。新版使用 ASCII 启动器，通过环境变量传递路径，再以 UTF-8 读取内嵌 PowerShell，避免把下载路径拼进脚本代码。

新版同时修正了恢复脚本忽略删除失败、备份损坏时直接回退等问题。启用和恢复都会读取校验；中途失败会尝试恢复本次操作前的三项值，并保留原始备份指针以便重试。

1. 确认使用本分支 [Release 页面](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/fake-offline-icon-v2.0.0)提供的 **2.0.0** 下载包，不要混用旧脚本或 `main` 分支的修复工具。
2. 脚本成功或失败都会保留窗口，并在 `%TEMP%\Windows-Network-Icon-Fix` 写入 `diagnostic-*.log`。以窗口中显示的完整路径为准，失败时保留日志和 `backups`。
3. 若仍闪退，在管理员命令提示符中执行以下命令，替换为实际路径，保留双引号。`/d` 禁用 cmd AutoRun，`/k` 保留窗口：

   ```bat
   cmd.exe /d /k ""C:\完整路径\显示灰色地球图标.bat""
   ```

4. 若根本没有新日志，检查 BAT 文件内容/扩展名、TEMP 权限，以及安全软件或组织策略是否阻止 cmd/PowerShell 启动。若已校验成功但图标没变化，请反馈日志、Windows 版本和下文的网络状态。

退出码 `0` 表示本次注册表操作已经校验，`1` 表示执行失败；不把注册表成功当作图标已经恢复或变灰。两个脚本均不自动重启或禁用网卡，也不会自动重启电脑。

## 注册表备份说明

首次运行切换脚本时，会生成类似目录：

```text
backups/
├── latest.txt
└── 20261104-010000-0123456789abcdef0123456789abcdef/
    ├── Internet.reg
    ├── Policy.reg              # 原策略键存在时才有
    ├── policy-key-absent.flag   # 原策略键不存在时才有
    └── state.json              # 三项值的原始数据、类型及是否存在
```

- `Internet.reg`：备份 `HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet`。
- `Policy.reg`：如果 NCSI 策略键原本存在，则完整备份该键。
- `policy-key-absent.flag`：表示策略键原本不存在。
- `state.json`：新版自动恢复使用的精确快照，仅恢复本工具修改的三项值，避免覆盖后来改动的其他配置。原先不存在的值会删除；若策略键原先不存在，恢复后可能留下空键，不影响策略状态。
- `latest.txt`：记录当前待恢复的备份目录。恢复成功后会删除这个指针，但时间戳备份仍保留。

旧版仅有 `.reg` 和标记文件的备份也能使用：恢复脚本读取其中的三项 DWORD 值或缺失状态，不会整体导入其他配置；若旧备份类型异常或不完整，会停止并提示保留文件手动处理。

建议恢复正常后再移动或清理历史备份。备份含本机系统配置，不建议上传到公开仓库、网盘或聊天群。

## 工作原理

Windows 11 通过 NCSI 的主动探测和被动探测判断连接是否具备 Internet 能力。脚本修改三项值：

| 注册表位置 | 值 | 修改后数据 | 用途 |
| --- | --- | ---: | --- |
| `HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet` | `EnableActiveProbing` | `0` | 关闭本地主动探测 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator` | `NoActiveProbe` | `1` | 通过策略关闭主动探测 |
| 同上 | `DisablePassivePolling` | `1` | 关闭被动探测，避免实际流量把图标重新判为联网 |

IP、DNS、路由和 Wi-Fi 连接本身都没有被禁用。这些设置会改变 NCSI 的探测行为，但不同 Windows 版本可能使用不同的联网信号，任务栏不保证一定显示灰色地球。

## 可能的副作用

NCSI 状态不只供任务栏使用。Microsoft Store、Outlook、Teams、Windows Update、VPN 客户端和部分第三方软件可能根据它判断“离线”，即使浏览器仍可上网。出现这些情况时，请运行恢复脚本并重启。

此外还需注意：

- 公司域策略或设备管理软件可能覆盖这些注册表值。
- Windows 大版本更新可能重置设置，需要重新运行脚本。
- 此方案不适合需要 Microsoft Store、系统更新或企业网络组件始终正确识别联网状态的电脑。
- 更改后若图标没有立即变化，必须重启；仅重启资源管理器通常不够。

## 检查当前状态

以管理员身份打开 PowerShell，执行：

```powershell
Get-NetConnectionProfile |
    Format-Table Name, InterfaceAlias, IPv4Connectivity, IPv6Connectivity
```

启用本功能后，连接仍存在，但 `IPv4Connectivity`/`IPv6Connectivity` 通常不会显示为 `Internet`。恢复并重启后，系统重新判断连接状态；若探测地址被 DNS、代理或防火墙拦截，仍可能显示无 Internet。

也可以检查本工具涉及的值：

```powershell
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet' `
    -Name EnableActiveProbing

Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator' `
    -Name NoActiveProbe, DisablePassivePolling -ErrorAction SilentlyContinue
```

## 自动检查

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-NetworkIconFix.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-OfflineIconMode.ps1
```

GitHub Actions 使用 Windows PowerShell 5.1，覆盖启用、重复运行、原值恢复、旧备份兼容、损坏备份、删除/写入/校验失败和回滚，并用含中文、空格、括号、`&`、`!` 的路径检查真实 cmd 启动器。测试不修改实际 NCSI 配置。macOS/Linux 的 PowerShell 7 可运行模拟测试，Windows 专有项目会跳过。任务栏图标效果仍需 Windows 实机确认。

本分支还同步维护 `main` 的通用修复脚本 `modifyRegistryAndRestart.bat`；离线图标模式启用期间，请使用本分支的专用恢复脚本恢复策略。

## 官方资料

- [Microsoft：Network Connection Status Indicator (NCSI) troubleshooting guidance](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/troubleshoot-ncsi-guidance)
- [Microsoft：NCSI overview](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-overview)
- [Microsoft：通过注册表关闭 NCSI 主动/被动探测及相关风险](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/internet-explorer-edge-open-connect-corporate-public-network)

> [!WARNING]
> Microsoft 不建议在一般故障排查中关闭 NCSI，因为系统组件和应用可能依赖它。本分支是针对“明确需要故意显示离线状态”的特殊用途；不再需要时请及时恢复。
