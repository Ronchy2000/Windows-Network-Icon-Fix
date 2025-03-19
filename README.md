[🇨🇳 中文文档](#chinese) | [🇺🇸 English](#english)

<a id="chinese"><a>
# Windows 10/11 网络图标修复工具

![Windows](https://img.shields.io/badge/Windows-10/11-blue) ![状态](https://img.shields.io/badge/状态-可用-brightgreen) ![类型](https://img.shields.io/badge/类型-注册表修复-orange) ![许可](https://img.shields.io/badge/许可-MIT-green)

## 问题概述
本仓库提供了一个解决方案，用于修复Windows 10系统中网络图标错误显示为"未连接"（灰色小地球）的问题，即使实际上可以正常访问互联网。**此问题主要在中国大陆地区出现。**

## 快速使用
> **注意**：此脚本会在执行过程中重启网络适配器，请确保执行前没有重要的网络传输任务正在进行。

直接从[**Release**](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases)页面下载批处理文件：
1. **以管理员身份**运行`modifyRegistryAndRestart.bat`
2. 在"网络和Internet设置"中重启"Windows网络适配器" （如果不会的话，关闭计算机重启即可）

## 工作原理

### 问题成因
从Windows 10 1607版本开始，系统通过访问`http://www.msftconnecttest.com/connecttest.txt`来判断网络连接状态。正常情况下，访问该URL会返回文本"Microsoft Connect Test"，系统据此显示正常的网络连接图标。

近期，由于中国大陆的网络运营商(ISP)对某些国外IP地址实施了限制，导致此连接测试失败，系统误判为网络未连接。

### 解决方案
Windows 10 1607之前版本使用的URL是`http://www.msftconnecttest.com/ncsi.txt`，该URL目前仍然有效且未被ISP屏蔽。本工具通过修改注册表，将系统配置恢复为使用这个旧版URL。

## 技术细节

注册表修改内容：
- 修改检测URL为`http://www.msftconnecttest.com/ncsi.txt`
- `EnableActiveProbing`字段：
  - 值为1：开启网络探测
  - 值为0：关闭网络探测

## 常见问题

### 此问题对系统有什么影响？
- 网络图标显示异常（灰色小地球）
- Microsoft Store和部分微软应用可能无法正常使用
- 系统可能提示"无Internet访问权限"

### 使用此工具有风险吗？
> 备份与恢复:
>打开文件 -> 网图标注册表(备份).png -> 修改注册表 -> 重启网络适配器

本工具仅修改Windows网络连接检测的URL配置，不会影响系统安全性或稳定性。如有顾虑，可以手动备份注册表后再使用。


### 为什么我的系统突然出现这个问题？
系统更新后可能会重置网络连接检测的设置。即使禁用了Windows Update，系统在某些情况下仍可能自动更新组件。

## 参考资料
- [Windows 10网络图标显示问题解决方案][ref1]
- [Windows网络连接检测机制分析][ref2]

[release-link]: https://github.com/yourusername/repo-name/releases
[ref1]: https://blog.csdn.net/Ronchy_2000/article/details/142069148
[ref2]: https://blog.csdn.net/qq_45830323/article/details/129681354

---
[🇨🇳 中文文档](#chinese) | [🇺🇸 English](#english)

<a id="english"><a>
# Windows 10 Network Icon Fix Tool

![Windows](https://img.shields.io/badge/Windows-10/11-blue) ![状态](https://img.shields.io/badge/状态-可用-brightgreen) ![类型](https://img.shields.io/badge/类型-注册表修复-orange) ![许可](https://img.shields.io/badge/许可-MIT-green)

## Problem Overview
This repository provides a solution for fixing the Windows 10 issue where the network icon incorrectly shows as "disconnected" (gray globe icon) even though you can successfully access the Internet. **This problem primarily occurs in mainland China.**

## Quick Usage
> **Note**: This script will restart your network adapter during execution. Please ensure no important network transfers are in progress before running it.

Download the batch file directly from the [**Release**](https://github.com/Ronchy2000/Windows-Network-Icon-Fix/releases) page:
1. Run `modifyRegistryAndRestart.bat` with administrator privileges
2. Restart the "Windows network adapter" in "Network & Internet settings" (If you don't know how to do this, simply restart your computer)

## How It Works

### Cause of the Problem
Since Windows 10 version 1607, the system determines network status by accessing `http://www.msftconnecttest.com/connecttest.txt`. Under normal circumstances, accessing this URL returns the text "Microsoft Connect Test", and the system displays the normal network connection icon accordingly.

Recently, due to restrictions implemented by mainland China's Internet Service Providers (ISPs) on certain foreign IP addresses, this connection test fails, causing the system to incorrectly identify the network as disconnected.

### Solution
Windows 10 versions prior to 1607 used the URL `http://www.msftconnecttest.com/ncsi.txt`, which is still effective and not blocked by ISPs. This tool modifies the registry to restore the system configuration to use this older URL.

## Technical Details

Registry modifications:
- Changes the detection URL to `http://www.msftconnecttest.com/ncsi.txt`
- `EnableActiveProbing` field:
  - Value 1: Enable network probing
  - Value 0: Disable network probing

## Frequently Asked Questions

### How does this issue affect my system?
- Abnormal network icon display (gray globe)
- Microsoft Store and some Microsoft applications may not function properly
- System may indicate "No Internet access"

### Is there any risk in using this tool?
> Backup and Recovery:
> Open file -> Network Icon Registry (Backup).png -> Modify registry -> Restart network adapter

This tool only modifies the URL configuration for Windows network connection detection and will not affect system security or stability. If concerned, you can manually backup the registry before using it.

### Why did this problem suddenly appear on my system?
System updates may reset network connection detection settings. Even if Windows Update is disabled, the system may still automatically update components under certain circumstances.

## References
- [Windows 10 Network Icon Display Problem Solution][ref1]
- [Windows Network Connection Detection Mechanism Analysis][ref2]

[release-link]: https://github.com/yourusername/repo-name/releases
[ref1]: https://blog.csdn.net/Ronchy_2000/article/details/142069148
[ref2]: https://blog.csdn.net/qq_45830323/article/details/129681354

