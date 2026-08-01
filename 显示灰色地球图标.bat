@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title Windows 11 显示无 Internet 图标

fltmc >nul 2>&1
if errorlevel 1 (
    echo [错误] 请右键此脚本，选择“以管理员身份运行”。
    echo.
    pause
    exit /b 1
)

set "INTERNET_KEY=HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
set "POLICY_KEY=HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator"
set "BACKUP_ROOT=%~dp0backups"
set "LATEST_FILE=%BACKUP_ROOT%\latest.txt"

if not exist "%BACKUP_ROOT%" mkdir "%BACKUP_ROOT%"
if errorlevel 1 (
    echo [错误] 无法创建备份目录：%BACKUP_ROOT%
    echo 请把脚本放到当前用户有写入权限的文件夹后重试。
    pause
    exit /b 1
)

if not exist "%LATEST_FILE%" goto CREATE_BACKUP

set /p "BACKUP_NAME="<"%LATEST_FILE%"
if not defined BACKUP_NAME goto INVALID_BACKUP_POINTER
if not exist "%BACKUP_ROOT%\%BACKUP_NAME%\Internet.reg" goto INVALID_BACKUP_POINTER
goto APPLY_SETTINGS

:INVALID_BACKUP_POINTER
echo [错误] backups\latest.txt 指向的备份无效。
echo 为避免覆盖原始配置，脚本没有修改注册表。请检查或移走损坏的 latest.txt。
pause
exit /b 1

:CREATE_BACKUP
for /f %%I in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "BACKUP_NAME=%%I"
if not defined BACKUP_NAME (
    echo [错误] 无法生成备份时间戳，脚本没有修改注册表。
    pause
    exit /b 1
)

set "BACKUP_DIR=%BACKUP_ROOT%\%BACKUP_NAME%"
mkdir "%BACKUP_DIR%"
if errorlevel 1 (
    echo [错误] 无法创建备份目录：%BACKUP_DIR%
    pause
    exit /b 1
)

echo 正在备份 NCSI 注册表设置...
reg.exe export "%INTERNET_KEY%" "%BACKUP_DIR%\Internet.reg" /y >nul
if errorlevel 1 (
    echo [错误] Internet 注册表项备份失败，脚本没有修改注册表。
    pause
    exit /b 1
)

reg.exe query "%POLICY_KEY%" >nul 2>&1
if errorlevel 1 (
    >"%BACKUP_DIR%\policy-key-absent.flag" echo 此文件表示修改前策略键不存在。
) else (
    reg.exe export "%POLICY_KEY%" "%BACKUP_DIR%\Policy.reg" /y >nul
    if errorlevel 1 (
        echo [错误] Policy 注册表项备份失败，脚本没有修改注册表。
        pause
        exit /b 1
    )
)

>"%LATEST_FILE%" echo %BACKUP_NAME%
if errorlevel 1 (
    echo [错误] 无法写入备份指针，脚本没有修改注册表。
    pause
    exit /b 1
)

:APPLY_SETTINGS
echo 正在关闭 Windows NCSI 联网状态探测...
reg.exe add "%INTERNET_KEY%" /v EnableActiveProbing /t REG_DWORD /d 0 /f >nul
if errorlevel 1 goto APPLY_FAILED

reg.exe add "%POLICY_KEY%" /v NoActiveProbe /t REG_DWORD /d 1 /f >nul
if errorlevel 1 goto APPLY_FAILED

reg.exe add "%POLICY_KEY%" /v DisablePassivePolling /t REG_DWORD /d 1 /f >nul
if errorlevel 1 goto APPLY_FAILED

echo.
echo [完成] 注册表修改完成，原配置已备份到：
echo %BACKUP_ROOT%\%BACKUP_NAME%
echo.
echo 请正常重启 Windows。重启后连接 Wi-Fi，网络仍可实际使用，
echo 但任务栏会显示“无 Internet”状态；具体图标样式取决于 Windows 11 版本。
echo.
pause
exit /b 0

:APPLY_FAILED
echo.
echo [错误] 注册表修改未全部完成。
echo 请立即运行“恢复正常联网图标.bat”回滚，然后重启电脑。
echo.
pause
exit /b 1
