@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title Windows 11 恢复正常联网图标

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
set "RESTORE_OK=1"

if not exist "%LATEST_FILE%" goto RESTORE_DEFAULTS

set /p "BACKUP_NAME="<"%LATEST_FILE%"
if not defined BACKUP_NAME goto RESTORE_DEFAULTS
set "BACKUP_DIR=%BACKUP_ROOT%\%BACKUP_NAME%"
if not exist "%BACKUP_DIR%\Internet.reg" goto RESTORE_DEFAULTS

echo 正在从备份恢复 NCSI 注册表设置...
reg.exe import "%BACKUP_DIR%\Internet.reg" >nul
if errorlevel 1 set "RESTORE_OK=0"

rem 先删除本工具写入的策略值，再恢复修改前可能存在的原值。
reg.exe delete "%POLICY_KEY%" /v NoActiveProbe /f >nul 2>&1
reg.exe delete "%POLICY_KEY%" /v DisablePassivePolling /f >nul 2>&1

if exist "%BACKUP_DIR%\Policy.reg" (
    reg.exe import "%BACKUP_DIR%\Policy.reg" >nul
    if errorlevel 1 set "RESTORE_OK=0"
)

if "%RESTORE_OK%"=="0" goto RESTORE_FAILED

del /q "%LATEST_FILE%" >nul 2>&1
echo.
echo [完成] 已恢复修改前的注册表配置。
echo 历史备份仍保留在：%BACKUP_DIR%
goto RESTART_NOTICE

:RESTORE_DEFAULTS
echo [提示] 未找到可用备份，将采用安全回退方式恢复正常探测。
echo 此操作只重新启用主动探测，并删除本工具添加的两个策略值。

reg.exe add "%INTERNET_KEY%" /v EnableActiveProbing /t REG_DWORD /d 1 /f >nul
if errorlevel 1 set "RESTORE_OK=0"
reg.exe delete "%POLICY_KEY%" /v NoActiveProbe /f >nul 2>&1
reg.exe delete "%POLICY_KEY%" /v DisablePassivePolling /f >nul 2>&1

if "%RESTORE_OK%"=="0" goto RESTORE_FAILED

echo.
echo [完成] 已按 Windows 标准方式重新启用 NCSI 联网探测。
goto RESTART_NOTICE

:RESTORE_FAILED
echo.
echo [错误] 注册表恢复未全部完成。
echo 请保留 backups 文件夹，并联系管理员手动导入其中的 .reg 备份。
echo.
pause
exit /b 1

:RESTART_NOTICE
echo 请正常重启 Windows，使任务栏恢复显示真实的联网状态。
echo.
pause
exit /b 0
