# Windows 10/11 离线图标模式

让 Windows 在网络连接保持可用的同时，将任务栏显示为灰色地球或“无 Internet”状态。适合希望调整系统联网状态显示的用户。

**[点击这里下载 v2.0.0 离线图标版](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/fake-offline-icon-v2.0.0)**

> 如果你是要**修复错误的灰色地球图标**，请下载[正常联网图标修复版](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases/tag/v2.0.0)。

## 下载与使用

### 启用离线图标模式

1. 点击上方下载链接，在页面下方的 **Assets（附件）** 中下载 **`Windows-Fake-Offline-Icon-v2.0.0.zip`**。
2. 右键 ZIP，选择 **“全部解压缩”**，打开解压后的文件夹，将两个 BAT 保留在一起。
3. 右键 `显示灰色地球图标.bat`，选择 **“以管理员身份运行”**，允许系统提示。
4. 等待提示完成后，重启 Windows，再观察任务栏图标。

请下载指定的 ZIP，`Source code` 是源码包。运行前先解压文件，并将文件夹放在可以保存文件的位置。

### 恢复正常联网图标

1. 在原文件夹中，右键 `恢复正常联网图标.bat`，选择 **“以管理员身份运行”**。
2. 等待提示完成后，重启 Windows，系统将重新判断网络状态。

首次启用时，工具会在脚本旁创建 `backups` 文件夹，保存原始配置。请将它与两个脚本一起保留，以便恢复时使用。重复启用会继续使用原始备份。

## 功能特性

- **适配 Windows 10/11**：支持 Wi-Fi 和以太网，与电脑品牌和网卡名称无关。
- **启用与恢复配套**：下载包同时提供切换模式和恢复配置的脚本。
- **自动保存原始配置**：恢复时还原本工具修改的设置，保留其他网络配置。
- **自动校验与回滚**：核对修改结果，执行失败时尝试恢复到操作前的状态。
- **保留网络连接**：保持网卡启用，完成后由用户自行重启电脑。

## 工作原理

Windows 使用 NCSI（网络连接状态指示器）判断网络是否具备 Internet 访问能力。它会通过主动请求检测地址，以及被动观察网络活动，向任务栏和应用提供联网状态。

本工具关闭 NCSI 的主动探测和被动探测，使系统更倾向于显示“无 Internet”状态。IP、DNS、路由和 Wi-Fi 连接继续保留，因此普通网络传输仍可进行。

恢复脚本会使用备份还原原始配置，让 Windows 恢复正常的联网状态检测。

## 使用须知

- Microsoft Store、Outlook、Teams、Windows Update 等软件可能依据系统状态判断为离线。需要这些软件正常识别网络时，请运行恢复脚本。
- 图标样式和显示效果取决于 Windows 版本、主题、缓存及组织策略，部分设备可能仍显示联网状态。
- Windows 更新或组织策略可能重置设置；恢复后的联网判断也取决于当前网络环境。

## 参考资料

- [Microsoft：NCSI 工作原理](https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-overview)
- [Microsoft：NCSI 主动与被动探测设置](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/internet-explorer-edge-open-connect-corporate-public-network)
