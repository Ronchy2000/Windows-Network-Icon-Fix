[🇨🇳 中文文档](#chinese) | [🇺🇸 English](#english)

<a id="chinese"></a>
# Windows 10/11 网络图标修复工具

用于解决电脑可以正常上网，但任务栏仍显示灰色地球或“无 Internet 访问权限”的问题。本工具通过调整 Windows 的联网检测配置，帮助系统正确识别网络状态。

**[点击这里下载 v2.0.0 修复版](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/v2.0.0)**

> 如果你希望**能上网，但故意显示灰色地球图标**，请下载[离线图标模式](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/fake-offline-icon-v2.0.0)。

## 下载与使用

1. 点击上方下载链接，在页面下方的 **Assets（附件）** 中下载 **`Windows-Network-Icon-Fix-v2.0.0.zip`**。
2. 右键 ZIP，选择 **“全部解压缩”**，打开解压后的文件夹。
3. 右键 `modifyRegistryAndRestart.bat`，选择 **“以管理员身份运行”**，允许系统提示。
4. 等待提示完成后，重启电脑或手动重新连接网络，再查看任务栏图标。

请下载指定的 ZIP，`Source code` 是源码包。运行前先解压文件。

## 功能特性

- **适配 Windows 10/11**：支持 Wi-Fi 和以太网，无需根据网卡名称修改脚本。
- **无需安装**：解压后即可运行，使用 Windows 自带组件。
- **自动选择检测地址**：检查微软的联网检测服务，使用当前网络可访问的地址。
- **自动备份与校验**：修改前保存原配置，修改后核对结果，执行失败时尝试回滚。
- **保留网络连接**：执行过程中保持网卡启用，由用户在完成后重新连接或重启电脑。

## 工作原理

Windows 使用 NCSI（网络连接状态指示器）判断网络是否具备 Internet 访问能力。其中，主动探测会访问指定网址，并检查返回的内容。当检测地址无法访问、响应被改写或探测配置异常时，即使浏览器可以上网，系统也可能显示“无 Internet”。

本工具会检查以下两个微软检测地址，优先使用第一个，必要时尝试第二个，再将可用地址及对应的预期内容写入联网检测配置，并启用主动探测。

| 检测地址 | 预期内容 |
| --- | --- |
| `http://www.msftncsi.com/ncsi.txt` | `Microsoft NCSI` |
| `http://www.msftconnecttest.com/connecttest.txt` | `Microsoft Connect Test` |

工具只调整联网检测配置。组织策略、代理和网络环境仍可能影响系统判断；本工具适用于实际能上网、但图标显示异常的情况。

## 备份与恢复

每次修改前都会生成 `.reg` 备份，保存位置会显示在运行窗口中。建议将备份另存一份，以便日后使用。

如需恢复备份中的设置，双击该 `.reg` 文件，按 Windows 提示允许导入，然后重启电脑。

## 参考资料

- [Windows 10 网络图标显示问题解决方案](https://blog.csdn.net/Ronchy_2000/article/details/142069148)
- [Microsoft：NCSI 工作原理](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-overview)

---

<a id="english"></a>
# Windows 10/11 Network Icon Fix

For computers that can browse the Internet while Windows shows a gray globe or “No Internet”. This tool adjusts Windows connectivity detection settings to help the system recognize the connection correctly.

**[Click here to download v2.0.0](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/v2.0.0)**

> To keep Internet access while intentionally showing an offline icon, download the [offline icon mode](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/fake-offline-icon-v2.0.0).

## Download and use

1. Open the download link above and find **Assets**. Download **`Windows-Network-Icon-Fix-v2.0.0.zip`**.
2. Right-click the ZIP, choose **Extract All**, and open the extracted folder.
3. Right-click `modifyRegistryAndRestart.bat`, choose **Run as administrator**, and allow the Windows prompt.
4. Wait for completion, then restart Windows or reconnect the network and check the taskbar icon.

Choose the named ZIP; `Source code` contains the repository sources. Extract the files before running them.

## Features

- **Windows 10/11 support:** works with Wi-Fi and Ethernet without changing adapter names in the script.
- **No installation:** uses built-in Windows components.
- **Automatic probe selection:** checks Microsoft connectivity endpoints and selects a reachable one.
- **Backup and verification:** saves the original configuration, verifies changes, and attempts rollback if an operation fails.
- **Keeps adapters enabled:** reconnect or restart when you are ready after the script finishes.

## How it works

Windows uses NCSI (Network Connection Status Indicator) to determine Internet connectivity. Its active probe requests a specific URL and checks the response. An unreachable endpoint, an altered response, or incorrect probe settings can cause a “No Internet” status while browsing still works.

The tool first checks `http://www.msftncsi.com/ncsi.txt` for `Microsoft NCSI`. If needed, it tries `http://www.msftconnecttest.com/connecttest.txt` for `Microsoft Connect Test`. It updates the probe configuration with the reachable endpoint and its expected content, and enables active probing.

Organization policies, proxies, and network conditions can still affect Windows connectivity detection. This tool is intended for a working Internet connection with an incorrect network icon.

## Backup and restore

Before making changes, the tool creates a `.reg` backup and displays its location. Keep a separate copy for later use.

To restore the settings in the backup, double-click the `.reg` file, allow Windows to import it, and restart your computer.

## Further reading

- [Microsoft: NCSI overview](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-overview)
