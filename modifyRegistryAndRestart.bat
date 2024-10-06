@echo off
chcp 65001 >nul

:: 检查是否以管理员权限运行
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 请以管理员权限运行此脚本。
    pause >nul
    exit /b
)

echo Windows Registry Editor Version 5.00 > temp.reg
echo. >> temp.reg
echo [HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet] >> temp.reg
echo "ActiveWebProbeContent"="Microsoft NCSI" >> temp.reg
echo "ActiveWebProbeContentV6"="Microsoft NCSI" >> temp.reg
echo "ActiveWebProbeHost"="www.msftncsi.com" >> temp.reg
echo "ActiveWebProbeHostV6"="ipv6.msftncsi.com" >> temp.reg
echo "ActiveWebProbePath"="ncsi.txt" >> temp.reg
echo "ActiveWebProbePathV6"="ncsi.txt" >> temp.reg
echo "EnableActiveProbing"=dword:00000001 >> temp.reg

reg import temp.reg
del temp.reg

netsh interface set interface name="以太网" admin=disable
if %errorlevel% neq 0 (
    echo 您需要手动禁用网卡并重启网卡。
    pause >nul
    exit /b
)

netsh interface set interface name="以太网" admin=enable

echo 完成！按任意键退出
pause >nul
