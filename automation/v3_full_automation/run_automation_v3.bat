@echo off
chcp 65001 > nul
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║  Google Trends + Rewards 自動化 v3                               ║
echo ╠══════════════════════════════════════════════════════════════════╣
echo ║  此批次檔會執行完整的自動化流程：                                ║
echo ║  1. 從 9 個地區抓取 Google Trends（每地區 25 個關鍵字）          ║
echo ║  2. 統計重複次數，選擇重複最多的前 5 個關鍵字                    ║
echo ║  3. 對選中的關鍵字進行 Bing 搜尋                                 ║
echo ║  4. 抓取 Microsoft Rewards 點數                                  ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.

REM 檢查 Python 是否安裝
python --version >nul 2>&1
if errorlevel 1 (
    echo [錯誤] 找不到 Python！請先安裝 Python 3.x
    echo 下載網址: https://www.python.org/downloads/
    pause
    exit /b 1
)

REM 檢查腳本是否存在
if not exist "google_trends_rewards_v6.py" (
    echo [錯誤] 找不到主程式！
    echo 請將您的 google_trends_rewards_v6.py 放到此目錄
    echo 或參考 SETUP_INSTRUCTIONS.md
    pause
    exit /b 1
)

REM 執行主程式
echo [資訊] 正在啟動自動化程式...
echo.
python google_trends_rewards_v6.py

REM 檢查執行結果
if errorlevel 1 (
    echo.
    echo [錯誤] 程式執行失敗！
    echo 請查看上方的錯誤訊息
) else (
    echo.
    echo [成功] 程式執行完成！
)

echo.
pause
