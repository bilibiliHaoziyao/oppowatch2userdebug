@echo off
rem ============================================================================
rem  OPPO Watch 2 (OW20W1) 一键永久 Root —— Windows 双击入口
rem
rem  © 慕寒 2026 保留部分权利（保留署名权与部分权利，仅供自有设备安全研究）
rem
rem  双击本文件，它会调用 auto_root.sh 依次完成：
rem    [0] 展示安全事项并要求 y/N 确认
rem    [1] 检查 adb 与设备连接
rem    [2] 预置全部物资（载体 App / v7 刷写目标 / 守卫三件套 / magiskpolicy）
rem    [3] 后台启动磨机（完整利用链，GATEONLY=0）
rem    [4] 每 30 秒打印实时状态与手表日志，并高亮报告
rem        命中 uid0 / 刷写开始 / 刷写完成
rem
rem  注意：本 .bat 必须保存为 UTF-8 编码，并由首行 chcp 65001 切换代码页；
rem        所有中文提示由本文件与 auto_root.sh 输出。
rem
rem  退出码：0=uid0 达成   2=本轮未命中   3=环境或预置错误
rem          4=设备不可用  5=安全确认选 n 130=Ctrl+C
rem ============================================================================
chcp 65001 >nul 2>&1
title OPPO Watch 2 一键永久 Root
cd /d "%~dp0"
setlocal

set "BASH="
if exist "C:\Program Files\Git\bin\bash.exe" set "BASH=C:\Program Files\Git\bin\bash.exe"
if not defined BASH if exist "C:\Program Files (x86)\Git\bin\bash.exe" set "BASH=C:\Program Files (x86)\Git\bin\bash.exe"
if not defined BASH if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not defined BASH if exist "C:\Program Files\Git\usr\bin\bash.exe" set "BASH=C:\Program Files\Git\usr\bin\bash.exe"
if not defined BASH for /f "delims=" %%i in ('where bash 2^>nul') do if not defined BASH set "BASH=%%i"

echo.
echo ============================================================
echo   OPPO Watch 2 (OW20W1) 一键永久 Root
echo ------------------------------------------------------------
echo   脚本会先展示安全事项（需输入 y 确认），再检查 adb 与设备，
echo   然后开始磨机（平均约 35-45 分钟命中一次）。
echo   运行期间请不要关闭本窗口、不要拔线。
echo ============================================================
echo.

if not defined BASH goto nobash
if not exist "auto_root.sh" goto noscript
if not exist "rc17_hunt_v2.sh" goto nohunt

"%BASH%" auto_root.sh %*
set RC=%ERRORLEVEL%

echo.
echo ------------------------------------------------------------
if "%RC%"=="0" goto ok
if "%RC%"=="2" goto nohit
if "%RC%"=="3" goto enverr
if "%RC%"=="4" goto nodev
if "%RC%"=="5" goto declined
if "%RC%"=="130" goto interrupted
echo   [结束] 脚本退出码 = %RC%（非预期）。日志：auto_root_hunt.log
goto end

:ok
echo   [完成] uid0 已达成 —— 永久 root（v7）已刷入并生效。
echo   命中证据在本文件夹，完整日志：auto_root_hunt.log
goto end

:nohit
echo   [未命中] 本轮未出现利用窗口。所有预置都保留在表上，
echo   再次双击本文件即可继续磨（平均 35-45 分钟命中一次）。
goto end

:enverr
echo   [环境错误] adb 缺失或预置失败 —— 请看上方带叉号的提示行。
echo   请把整个压缩包完整解压后再运行（不要单独复制某几个文件）。
goto end

:nodev
echo   [无设备] adb 没有发现手表 —— 请检查数据线 / 调试授权 / 驱动。
echo   脚本已重试约 3 分钟后才放弃。
goto end

:declined
echo   [已取消] 你在安全确认处回答了 N，未做任何更改。
goto end

:interrupted
echo   [已中断] Ctrl+C —— 后台磨机已停止。进度都保留在表上，
echo   再次双击本文件即可续磨。
goto end

:nobash
echo   [错误] 未找到 Git Bash（bash.exe）。
echo   解决：安装 Git for Windows（https://git-scm.com/download/win），
echo        或把它的 bin 目录加入 PATH，然后重新运行本文件。
goto end

:noscript
echo   [错误] 本 .bat 同目录下缺少 auto_root.sh。
goto end

:nohunt
echo   [错误] 本 .bat 同目录下缺少 rc17_hunt_v2.sh。
goto end

:end
echo ------------------------------------------------------------
echo   （本窗口特意保留，方便你阅读结果。）
echo.
pause
exit /b %RC%
