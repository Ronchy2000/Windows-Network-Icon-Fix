# Windows 11：让联网 Wi-Fi 显示“无 Internet”图标

> 本分支专门实现“实际可以上网，但任务栏故意显示灰色小地球/无 Internet”的需求。若你是要**修复**错误的灰色地球图标，请返回 [`main` 分支](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/tree/main)。

适用场景：运行 Windows10 / Windows 11 的电脑。该功能依赖 Windows 自带的 NCSI（网络连接状态指示器），与电脑品牌和无线网卡型号无关。

## 先看结论

- 运行 [`显示灰色地球图标.bat`](./显示灰色地球图标.bat)，重启 Windows 后，Wi-Fi 仍能正常传输数据，但系统会把连接标记为“无 Internet”。
- 运行 [`恢复正常联网图标.bat`](./恢复正常联网图标.bat)，重启 Windows 后恢复系统正常联网判断。
- 第一个脚本会在同目录自动创建 `backups` 文件夹并备份注册表；第二个脚本会优先使用最近一次备份精确恢复。
- 两个脚本都必须右键选择“以管理员身份运行”。

> [!IMPORTANT]
> 这只是改变 Windows 对网络状态的判断，并不会真的禁止联网、隐藏流量或提升隐私。不同 Windows 11 版本、主题和任务栏样式可能显示为灰色地球、地球叠加禁止符号，或其他“无 Internet”样式，无法保证像素级一致。

## 使用教程

### 一、切换为“表面未联网”

1. 下载本分支全部文件，或至少把两个 `.bat` 文件放在同一个可写文件夹中。
2. 右键 [`显示灰色地球图标.bat`](./显示灰色地球图标.bat)，选择“以管理员身份运行”。
3. 看到“注册表修改完成”后，正常重启电脑。
4. 重启后连接 Wi-Fi。浏览器等普通联网程序仍可访问网络，任务栏应显示“无 Internet”状态。

脚本可以重复运行。只要上一次修改尚未恢复，它就会复用第一次生成的原始备份，不会用已经修改过的注册表覆盖备份。

### 二、恢复正常联网图标

1. 不要移动或删除脚本旁边的 `backups` 文件夹。
2. 右键 [`恢复正常联网图标.bat`](./恢复正常联网图标.bat)，选择“以管理员身份运行”。
3. 脚本会恢复最近一次修改前的注册表值，并保留历史备份文件。
4. 正常重启电脑。

若备份文件确实丢失，恢复脚本会采用安全回退：重新启用 NCSI 主动探测，并删除本工具添加的两项策略值；它不会重写探测网址等其他 NCSI 配置。

## 注册表备份说明

首次运行切换脚本时，会生成类似目录：

```text
backups/
├── latest.txt
└── 20260801-153000/
    ├── Internet.reg
    ├── Policy.reg              # 原策略键存在时才有
    └── policy-key-absent.flag  # 原策略键不存在时才有
```

- `Internet.reg`：备份 `HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet`。
- `Policy.reg`：如果 NCSI 策略键原本存在，则完整备份该键。
- `policy-key-absent.flag`：表示策略键原本不存在。
- `latest.txt`：记录当前待恢复的备份目录。恢复成功后会删除这个指针，但时间戳备份仍保留。

建议恢复正常后再移动或清理历史备份。备份含本机系统配置，不建议上传到公开仓库、网盘或聊天群。

## 工作原理

Windows 11 通过 NCSI 的主动探测和被动探测判断连接是否具备 Internet 能力。脚本修改三项值：

| 注册表位置 | 值 | 修改后数据 | 用途 |
| --- | --- | ---: | --- |
| `HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet` | `EnableActiveProbing` | `0` | 关闭本地主动探测 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator` | `NoActiveProbe` | `1` | 通过策略关闭主动探测 |
| 同上 | `DisablePassivePolling` | `1` | 关闭被动探测，避免实际流量把图标重新判为联网 |

因此，IP、DNS、路由和 Wi-Fi 连接本身都没有被禁用；NCSI 只是无法确认“Internet 可用”，任务栏便显示本地连接/无 Internet 状态。

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

启用本功能后，连接仍存在，但 `IPv4Connectivity`/`IPv6Connectivity` 通常不会显示为 `Internet`。恢复并重启后，应重新显示 `Internet`。

也可以检查本工具涉及的值：

```powershell
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet' `
    -Name EnableActiveProbing

Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator' `
    -Name NoActiveProbe, DisablePassivePolling -ErrorAction SilentlyContinue
```

## 官方资料

- [Microsoft：Network Connection Status Indicator (NCSI) troubleshooting guidance](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/troubleshoot-ncsi-guidance)
- [Microsoft：NCSI overview](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-overview)
- [Microsoft：通过注册表关闭 NCSI 主动/被动探测及相关风险](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/internet-explorer-edge-open-connect-corporate-public-network)

> [!WARNING]
> Microsoft 不建议在一般故障排查中关闭 NCSI，因为系统组件和应用可能依赖它。本分支是针对“明确需要故意显示离线状态”的特殊用途；不再需要时请及时恢复。
