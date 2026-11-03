[🇨🇳 中文文档](#chinese) | [🇺🇸 English](#english)

**[点击这里进入下载页面：灰色地球图标修复版 v2.0.0](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/v2.0.0)**

不熟悉 GitHub 的用户：打开上面的链接，在页面下方的 **Assets（附件）** 中点击 **`Windows-Network-Icon-Fix-v2.0.0.zip`** 下载。下载后右键 ZIP，选择“全部解压缩”，再按下方步骤运行。无需下载源码或安装开发工具。

> 如果你需要**实际可以上网，但故意显示灰色地球/无 Internet 图标**，请使用 [`fake-offline-icon` 专用分支](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/tree/fake-offline-icon)。
>
> For working Internet with an intentional “No Internet” icon, use the [`fake-offline-icon` branch](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/tree/fake-offline-icon).

<a id="chinese"></a>
# Windows 10/11 网络图标修复工具

适用于**实际可以上网，但任务栏显示灰色地球或“无 Internet 访问权限”**的情况。工具检查 Windows 网络连接状态指示器（NCSI）的 HTTP 探测地址，并修复相关注册表配置。它不能修复所有网络故障，也不会把“注册表写入成功”当成“图标已经恢复”。

## 使用方法

1. **[点击进入 Release 下载页面](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/v2.0.0)**，展开 **Assets（附件）**，点击 **`Windows-Network-Icon-Fix-v2.0.0.zip`**。不要选择 `Source code`，那是提供给开发者的源码包。
2. 右键下载好的 ZIP，选择“全部解压缩”。打开解压后的文件夹，右键 `modifyRegistryAndRestart.bat`，选择 **以管理员身份运行**，允许 UAC 提示。窗口顶部应显示 **2.0.0**。不要直接在压缩包内运行。
3. 查看执行结果。提示“注册表修改并校验成功”后，重启电脑或手动重新连接网络，再观察图标。

仍然只需一个 BAT，不需要另外下载 PowerShell 脚本；使用 Windows 10/11 自带的 Windows PowerShell 5.1。**新版不再自动禁用网卡**，Wi-Fi、英文名称和改名后的网卡均无需修改脚本。

上面的链接对应 `main` 分支的 **v2.0.0 修复版**，包含新版脚本和使用说明。旧的 `bat` Release 是历史版本，请使用本页链接下载。

## 新版会做什么

- 检查当前进程是否有管理员权限，不再通过 `net session` 判断，避免 Server 服务停用时误判。
- 显示并记录相关服务、网络连接状态、当前探测配置以及 `NoActiveProbe` 组策略。
- 优先验证 `http://www.msftncsi.com/ncsi.txt` 是否返回完全匹配的 `Microsoft NCSI`；失败时尝试 `http://www.msftconnecttest.com/connecttest.txt`，预期内容为 `Microsoft Connect Test`。拒绝重定向和认证页等异常内容。
- 只在候选地址通过检查后修改配置。两个地址都失败，或策略 `NoActiveProbe=1` 禁用主动探测时，明确说明原因并停止。
- 修改前导出实际注册表备份，备份失败就停止。写入后逐项核对值和类型；写入或校验失败时尝试恢复原值，包括删除本次新增的值。
- 成功、失败都会保留窗口。日志在启动 PowerShell 之前创建，即使 PowerShell 启动失败，也能留下错误信息。

探测使用当前用户的网络环境，系统服务可能使用不同的代理或 IPv6 路径。因此，地址在脚本中可达仍不保证 NCSI 最终判断为在线。公司策略、DNS、代理/VPN、防火墙、网页认证、服务异常和系统缓存都可能影响图标；不能仅凭地区推断具体原因。

## “闪一下就没了”怎么排查

旧脚本存在以下问题：在当前工作目录写固定名称 `temp.reg`，没有检查创建和导入是否成功；管理员检查依赖 Server 服务；网卡名称写死为“以太网”，且未检查重新启用是否成功。前两项可能导致注册表根本没有修改，网卡名称问题则会让后续步骤失败。

不过，旧源码的正常结束和已处理的错误分支都有 `pause`，**仅凭“一闪而过”不能确定唯一原因**。如果新版仍然闪退：

1. 在开始菜单搜索 **命令提示符**，以管理员身份打开，在窗口中执行下面的命令。将路径替换成实际文件路径，保留双引号。这会禁用 cmd 的 AutoRun，并在退出后保留窗口：

   ```bat
   cmd.exe /d /k ""C:\完整路径\modifyRegistryAndRestart.bat""
   ```

2. 打开 `%TEMP%\Windows-Network-Icon-Fix`，查找本次的 `diagnostic-*.log`。也可以按 `Win+R` 输入该目录。窗口会显示日志完整路径；如果用户切换了管理员账户运行，应以该窗口显示的路径为准。
3. 反馈日志和窗口中的报错。如果没有新日志，说明尚未成功运行到日志初始化处，应检查下载文件内容、`.bat` 文件关联、TEMP 写权限，以及安全软件或组织策略是否拦截了 cmd/PowerShell。无需先反复重启电脑。

退出码：`0` 表示注册表写入并校验成功，`1` 表示执行失败，`2` 表示被策略或探测结果阻止。**`0` 不表示已经确认任务栏图标恢复。**

## 注册表与恢复

修改位置：

```text
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet
```

修改七个值：`ActiveWebProbeHost`、`ActiveWebProbeHostV6`、`ActiveWebProbePath`、`ActiveWebProbePathV6`、`ActiveWebProbeContent`、`ActiveWebProbeContentV6` 和 DWORD 类型的 `EnableActiveProbing=1`。Host、Path、Content 按本次通过检查的地址成组写入。工具不覆盖组织的 `NoActiveProbe` 策略。

每次修改前的备份为日志目录中的 `NCSI-backup-日期时间-唯一编号.reg`，具体路径会记录在日志中。需要恢复时，在管理员终端执行：

```bat
reg.exe import "C:\日志中显示的完整路径\NCSI-backup-....reg"
```

然后重启电脑或重新连接网络。`.reg` 导入是合并操作，能恢复备份中已有的值；原先不存在、修复时新增的值不会由手动导入自动删除。执行中失败触发的自动回滚会处理这些新增值。备份和日志位于临时目录，请在清理临时文件前另行保存。

仓库中的 PNG 只是配置示例，**不是用户电脑的原始备份**。`网络连接.txt` 是旧版地址的手工配置片段，已修正域名多出的 `I`，不是完整 `.reg` 文件；优先使用带检测和备份的脚本。

## 验证

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-NetworkIconFix.ps1
```

测试覆盖权限不足、组策略、探测失败/内容不符、备用地址、备份失败、部分写入失败、读取校验失败和回滚。GitHub Actions 使用 Windows PowerShell 5.1，额外检查真实 cmd 启动器（含中文、空格和特殊字符路径）及 `reg.exe` 的备份成功/失败路径。测试不修改实际 NCSI 配置；备份测试仅使用独立的临时 HKCU 项。macOS/Linux 可用 PowerShell 7 运行模拟测试，Windows 专有检查会跳过。这些检查不能代替 Windows 实机观察任务栏图标。

## 参考资料

- [Windows 10 网络图标显示问题解决方案](https://blog.csdn.net/Ronchy_2000/article/details/142069148)
- [Windows 网络连接检测机制分析](https://blog.csdn.net/qq_45830323/article/details/129681354)

---

<a id="english"></a>
# Windows 10/11 Network Icon Fix

For computers that **can access the Internet while Windows shows a gray globe or “No Internet”**. The tool checks NCSI HTTP probes and repairs their registry configuration. A successful registry update does not confirm that the taskbar icon has recovered.

## Usage

1. **[Click here to open the v2.0.0 download page](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/v2.0.0)**. Under **Assets**, download **`Windows-Network-Icon-Fix-v2.0.0.zip`**. Choose this ready-to-use package instead of `Source code`.
2. Right-click the ZIP and choose **Extract All**. In the extracted folder, right-click `modifyRegistryAndRestart.bat`, choose **Run as administrator**, and approve UAC. The header should show **2.0.0**. Extract the files before running them.
3. Once the script reports a verified registry update, restart Windows or reconnect the network manually and check the icon.

This is a single BAT using built-in Windows PowerShell 5.1. **It no longer disables network adapters automatically**, and works without assuming an adapter named “以太网”. The linked v2.0.0 release packages the updated `main` branch script and instructions. The older `bat` release is retained for history.

## Behavior

The script checks actual elevation, reports service/connection status and the `NoActiveProbe` policy, then tries these probes in order:

| HTTP URL | Required response body |
| --- | --- |
| `http://www.msftncsi.com/ncsi.txt` | `Microsoft NCSI` |
| `http://www.msftconnecttest.com/connecttest.txt` | `Microsoft Connect Test` |

Redirects and unexpected content are rejected. If neither probe passes, or `NoActiveProbe=1` disables active probing, the script stops without changing the registry. Otherwise, it exports a backup before writing, verifies all seven values and their types, and attempts rollback on write/verification failure. It leaves the window open and saves a persistent log, including PowerShell startup errors.

Probes run in the current user's network environment. Windows services may use different proxy or IPv6 paths. DNS, VPN/proxy settings, captive portals, firewalls, policies, service problems and cached network state can still prevent the icon from recovering.

## If the window immediately closes

The old script used a fixed `temp.reg` in the working directory, ignored registry import failures, relied on `net session` for elevation checks, and assumed a specific adapter name. Its normal and handled error paths already included `pause`, so a flashing window alone does not establish the cause.

Open **Command Prompt as administrator** and run this command with the actual file path. It disables cmd AutoRun and keeps the console open:

```bat
cmd.exe /d /k ""C:\full path\modifyRegistryAndRestart.bat""
```

Find the latest `diagnostic-*.log` in `%TEMP%\Windows-Network-Icon-Fix` and include it with the reported error. Use the log path displayed by the script if it runs under a different administrator account. If there is no new log, check the downloaded file, BAT association, TEMP permissions, and whether security software or organization policy prevented cmd/PowerShell from starting.

Exit codes: `0` = registry update verified, `1` = execution failure, `2` = blocked by policy or probe results. Code `0` does not confirm taskbar recovery.

## Backup and restore

The script updates the six `ActiveWebProbe*` string values and DWORD `EnableActiveProbing=1` under:

```text
HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet
```

It does not override organization policy. Each run that changes settings first creates a unique `NCSI-backup-*.reg` in the log directory. To restore, run this in an administrator terminal using the exact path from the log, then reconnect or restart:

```bat
reg.exe import "C:\full path\NCSI-backup-....reg"
```

Manual `.reg` import merges existing backup values; it does not remove values that were absent before the repair. Automatic rollback during a failed repair also removes newly created values. Copy backups elsewhere before clearing temporary files. The repository PNG is an example, not a backup of your computer, and `网络连接.txt` is only a manual configuration fragment.

## Validation

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-NetworkIconFix.ps1`. The test suite simulates elevation, policy, HTTP responses, backup failures, partial writes, readback failures and rollback. Windows CI additionally exercises the actual BAT launcher with complex paths and `reg.exe` export using a temporary HKCU key. It does not modify live NCSI settings. PowerShell 7 on macOS/Linux runs the simulations and skips Windows-only checks. Testing actual icon recovery still requires Windows.
