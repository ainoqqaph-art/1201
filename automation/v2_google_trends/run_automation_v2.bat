@echo off
REM Google Trends Automation v2.0 - Windows Batch Script
REM 此批次檔可直接執行 Python 腳本，適合用於 Windows Task Scheduler

REM 設定編碼為 UTF-8 以支援中文
chcp 65001 > nul

REM 切換到腳本所在目錄
cd /d "%~dp0"

echo ==========================================
echo Google Trends 自動化工具 v2.0
echo ==========================================
echo.

REM 檢查 Python 是否已安裝
python --version > nul 2>&1
if %errorlevel% neq 0 (
    echo [錯誤] 未找到 Python，請先安裝 Python 3.7 或更高版本
    echo 下載位址: https://www.python.org/downloads/
    pause
    exit /b 1
)

echo [資訊] Python 版本:
python --version
echo.

REM 檢查必要套件是否已安裝
echo [資訊] 檢查 Python 套件...
python -c "import selenium, pyodbc" > nul 2>&1
if %errorlevel% neq 0 (
    echo [警告] 必要套件未安裝，正在安裝...
    pip install -r requirements.txt
    if %errorlevel% neq 0 (
        echo [錯誤] 套件安裝失敗
        echo 請手動執行: pip install -r requirements.txt
        echo 並查看詳細錯誤訊息
        pause
        exit /b 1
    )
    echo [成功] 套件安裝完成
    echo.
)

REM 執行 Python 腳本
echo [資訊] 正在執行自動化腳本...
echo.
python google_trends_automation.py %*

REM 檢查執行結果
if %errorlevel% equ 0 (
    echo.
    echo ==========================================
    echo [成功] 腳本執行完成
    echo ==========================================
) else (
    echo.
    echo ==========================================
    echo [錯誤] 腳本執行失敗，錯誤代碼: %errorlevel%
    echo 請查看日誌檔案: google_trends_automation.log
    echo ==========================================
)

echo.
echo 按任意鍵關閉視窗...
pause > nul
